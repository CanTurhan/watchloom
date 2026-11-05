import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:watchloom/features/account/data/firestore_account_store.dart';
import 'package:watchloom/features/account/data/library_backup.dart';

class CloudBackupHead {
  const CloudBackupHead(this.revision, this.id);
  final int revision;
  final String? id;
}

abstract interface class CloudBackupRepository {
  Future<void> bootstrap();
  Future<CloudBackupHead> head();
  Future<LibraryBackup> download(CloudBackupHead head);
  Future<int> upload(LibraryBackup backup, {required int expectedRevision});
}

class FirestoreBackupRepository implements CloudBackupRepository {
  FirestoreBackupRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _user = firestore.collection('users').doc(uid);
  final FirebaseFirestore _firestore;
  final DocumentReference<Map<String, dynamic>> _user;
  static const chunkSize = 400 * 1024;

  @override
  Future<void> bootstrap() =>
      FirestoreAccountStore(_firestore, _user.id).bootstrap();

  @override
  Future<CloudBackupHead> head() async {
    final data = (await _user.get(
      const GetOptions(source: Source.server),
    )).data();
    if (data?['status'] == 'deleting') throw const AccountDeletionPending();
    if (data == null) {
      final marker = await _firestore
          .collection('deletionMarkers')
          .doc(_user.id)
          .get(const GetOptions(source: Source.server));
      if (marker.exists) throw const AccountDeletionPending();
    }
    if (data == null || data['status'] != 'active') {
      throw StateError('account-unavailable');
    }
    return CloudBackupHead(
      data['revision'] as int,
      data['activeBackupId'] as String?,
    );
  }

  @override
  Future<LibraryBackup> download(CloudBackupHead head) async {
    final ref = _user.collection('backups').doc(head.id);
    final manifest = (await ref.get(
      const GetOptions(source: Source.server),
    )).data();
    if (manifest == null ||
        manifest['schema'] != 1 ||
        manifest['complete'] != true) {
      throw const FormatException('incomplete-backup');
    }
    final count = manifest['chunks'] as int;
    if (count < 1 || count > 164) throw const FormatException('invalid-chunks');
    final bytes = BytesBuilder(copy: false);
    for (var index = 0; index < count; index++) {
      final chunk = await ref
          .collection('chunks')
          .doc('$index')
          .get(const GetOptions(source: Source.server));
      final blob = chunk.data()?['payload'];
      if (blob is! Blob || blob.bytes.length > chunkSize) {
        throw const FormatException('invalid-chunk');
      }
      bytes.add(blob.bytes);
    }
    final payload = bytes.takeBytes();
    if (payload.length != manifest['bytes'] ||
        LibraryBackup.digest(payload) != manifest['sha256']) {
      throw const FormatException('backup-integrity');
    }
    return LibraryBackup.decode(payload);
  }

  @override
  Future<int> upload(
    LibraryBackup backup, {
    required int expectedRevision,
  }) async {
    final bytes = backup.encode();
    final count = (bytes.length / chunkSize).ceil();
    if (count > 164) throw const FormatException('backup-too-large');
    final ref = _user.collection('backups').doc(const Uuid().v4());
    await ref.set({
      'schema': 1,
      'complete': false,
      'chunks': count,
      'bytes': bytes.length,
      'sha256': LibraryBackup.digest(bytes),
      'createdAt': FieldValue.serverTimestamp(),
    });
    var batch = _firestore.batch();
    for (var index = 0; index < count; index++) {
      final end = (index + 1) * chunkSize;
      batch.set(ref.collection('chunks').doc('$index'), {
        'payload': Blob(
          Uint8List.sublistView(
            bytes,
            index * chunkSize,
            end > bytes.length ? bytes.length : end,
          ),
        ),
      });
      // Stay comfortably below Firestore's 10 MiB per-request limit.
      if ((index + 1) % 8 == 0 || index == count - 1) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }
    await ref.update({'complete': true});
    // Publish the pointer only after every immutable chunk has been committed.
    final revision = await _firestore.runTransaction<int>((transaction) async {
      final current = (await transaction.get(_user)).data();
      if (current?['status'] != 'active') {
        throw StateError('account-unavailable');
      }
      if (current?['revision'] != expectedRevision) {
        throw const BackupConflict();
      }
      transaction.update(_user, {
        'revision': expectedRevision + 1,
        'activeBackupId': ref.id,
        'previousBackupId': current?['activeBackupId'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return expectedRevision + 1;
    });
    // Spark-compatible retention. Rules protect the active/previous snapshots
    // independently of these client checks. Cleanup never invalidates a backup.
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      final old = await _user
          .collection('backups')
          .where('createdAt', isLessThan: cutoff)
          .orderBy('createdAt')
          .limit(10)
          .get(const GetOptions(source: Source.server));
      for (final candidate in old.docs) {
        final current = (await _user.get(
          const GetOptions(source: Source.server),
        )).data();
        if (candidate.id == current?['activeBackupId'] ||
            candidate.id == current?['previousBackupId']) {
          continue;
        }
        await FirestoreAccountStore.deleteSnapshot(
          _firestore,
          candidate.reference,
        );
      }
    } catch (_) {
      /* Retry next backup. */
    }
    return revision;
  }
}
