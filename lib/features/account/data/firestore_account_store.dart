import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchloom/core/database/watchloom_database.dart';

class AccountDeletionPending implements Exception {
  const AccountDeletionPending();
}

/// Spark-compatible account lifecycle. Every operation is also enforced by
/// Firestore rules; a client-writable document never grants Premium.
class FirestoreAccountStore {
  FirestoreAccountStore(this.firestore, this.uid)
    : user = firestore.collection('users').doc(uid),
      marker = firestore.collection('deletionMarkers').doc(uid);
  final FirebaseFirestore firestore;
  final String uid;
  final DocumentReference<Map<String, dynamic>> user;
  final DocumentReference<Map<String, dynamic>> marker;

  Future<void> bootstrap() => firestore.runTransaction((tx) async {
    final deleted = await tx.get(marker);
    final existing = await tx.get(user);
    if (deleted.exists || existing.data()?['status'] == 'deleting') {
      throw const AccountDeletionPending();
    }
    if (!existing.exists) {
      tx.set(user, {
        'schema': 1,
        'status': 'active',
        'revision': 0,
        'activeBackupId': null,
        'previousBackupId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  });

  /// Lock all devices before removing any snapshot. A failed/offline operation
  /// leaves Auth intact and can be resumed after fresh reauthentication.
  Future<String> eraseCloudData() async {
    final nonce = await firestore.runTransaction<String>((tx) async {
      final deleted = await tx.get(marker);
      final existing = await tx.get(user);
      String proof;
      if (deleted.exists) {
        proof = deleted.data()!['nonce'] as String;
      } else {
        final random = Random.secure();
        proof = base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
        tx.set(marker, {
          'startedAt': FieldValue.serverTimestamp(),
          'nonce': proof,
        });
      }
      if (existing.exists) {
        tx.update(user, {
          'status': 'deleting',
          'deletionRequestedAt': FieldValue.serverTimestamp(),
        });
      }
      return proof;
    });
    while (true) {
      final backups = await user
          .collection('backups')
          .limit(20)
          .get(const GetOptions(source: Source.server));
      if (backups.docs.isEmpty) break;
      for (final backup in backups.docs) {
        await deleteSnapshot(firestore, backup.reference);
      }
    }
    await _eraseCommunityData();
    // Refresh the replay-protection window immediately before Auth deletion,
    // including retries where a previous attempt already removed the root.
    await firestore.runTransaction((tx) async {
      final existing = await tx.get(user);
      tx.update(marker, {'purgedAt': FieldValue.serverTimestamp()});
      if (existing.exists) tx.delete(user);
    });
    return nonce;
  }

  /// The replay lock above prevents posts/reports/profile changes from racing
  /// this purge. Other authors' replies remain independent; no deleted author's
  /// text/name is retained in a parent tombstone or a report snapshot.
  Future<void> _eraseCommunityData() async {
    await _deletePages(
      firestore
          .collection('communityComments')
          .where('authorUid', isEqualTo: uid)
          .limit(50),
    );
    while (true) {
      final refs = await user
          .collection('communityReportRefs')
          .limit(50)
          .get(const GetOptions(source: Source.server));
      if (refs.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final ref in refs.docs) {
        batch.delete(firestore.collection('communityReports').doc(ref.id));
        batch.delete(ref.reference);
      }
      await batch.commit();
    }
    await _deletePages(
      firestore
          .collection('communityBlocks')
          .doc(uid)
          .collection('authors')
          .limit(50),
    );
    final profile = firestore.collection('communityProfiles').doc(uid);
    await firestore.runTransaction((tx) async {
      final existing = await tx.get(profile);
      if (!existing.exists) return;
      final handle = existing.data()!['handle'] as String;
      tx.delete(firestore.collection('communityHandles').doc(handle));
      tx.delete(profile);
    });
  }

  Future<void> _deletePages(Query<Map<String, dynamic>> query) async {
    while (true) {
      final page = await query.get(const GetOptions(source: Source.server));
      if (page.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static Future<void> deleteSnapshot(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> snapshot,
  ) async {
    // Small pages avoid reading many 400 KiB payloads into memory at once.
    while (true) {
      final page = await snapshot
          .collection('chunks')
          .limit(20)
          .get(const GetOptions(source: Source.server));
      if (page.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await snapshot.delete();
  }
}

/// Deleted Firebase ID tokens may remain valid for about an hour. A minimal
/// marker blocks stale tokens from recreating the erased account. The random
/// proof only authorizes completion/cleanup of that marker, never user data.
/// It is not a Firebase/OAuth token and contains no email or profile content.
class DeletionRecoveryStore {
  DeletionRecoveryStore(this.firestore, this.preferences);
  final FirebaseFirestore firestore;
  final SharedPreferences preferences;
  static const _key = 'watchloom_deletion_cleanup_v1';
  Future<void> _tail = Future.value();
  bool _retrying = false;

  Map<String, dynamic> _records() {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(preferences.getString(_key) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _mutate(void Function(Map<String, dynamic>) change) {
    final result = _tail.then((_) async {
      final data = _records();
      change(data);
      if (!await preferences.setString(_key, jsonEncode(data))) {
        throw StateError('deletion-recovery-not-saved');
      }
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> prepare(String uid, String proof) => _mutate((data) {
    data[uid] = {
      'proof': proof,
      'deleted': false,
      'confirmed': false,
      'cacheCleared': false,
    };
  });
  Future<void> deleted(String uid) => _mutate((data) {
    final record = data[uid] as Map<String, dynamic>?;
    if (record != null) {
      record['deleted'] = true;
      record['completedAt'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    }
  });

  Future<void> cacheCleared(String uid) => _mutate((data) {
    if (data[uid] is Map) data[uid]['cacheCleared'] = true;
  });

  Future<void> retry() async {
    if (_retrying) return;
    _retrying = true;
    try {
      await _tail;
      for (final entry in _records().entries) {
        if (entry.key.isEmpty ||
            entry.key.contains('/') ||
            entry.value is! Map) {
          continue;
        }
        final record = Map<String, dynamic>.from(entry.value as Map);
        if (record['deleted'] != true) continue;
        if (record['proof'] is! String ||
            (record['proof'] as String).length != 44 ||
            record['completedAt'] is! int) {
          continue;
        }
        if (record['cacheCleared'] != true) {
          try {
            await WatchloomDatabase(userId: entry.key).erase();
            await cacheCleared(entry.key);
          } catch (_) {
            continue;
          }
        }
        final marker = firestore.collection('deletionMarkers').doc(entry.key);
        final age =
            DateTime.now().toUtc().millisecondsSinceEpoch -
            (record['completedAt'] as int? ?? 0);
        if (age >= const Duration(hours: 2).inMilliseconds) {
          try {
            // Rules allow only an expired, completed marker with no owner root.
            await marker.delete().timeout(const Duration(seconds: 10));
            await _mutate((data) => data.remove(entry.key));
            continue;
          } catch (_) {
            /* Keep the durable retry record. */
          }
        }
        if (record['confirmed'] != true) {
          try {
            await marker
                .update({
                  'authDeletedAt': FieldValue.serverTimestamp(),
                  'completionProof': record['proof'],
                })
                .timeout(const Duration(seconds: 10));
            await _mutate((data) {
              if (data[entry.key] is Map) data[entry.key]['confirmed'] = true;
            });
          } catch (_) {
            /* Auth and all private content are already deleted. */
          }
        }
      }
    } finally {
      _retrying = false;
    }
  }
}
