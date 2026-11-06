import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/community/data/community_vote_transaction.dart';
import 'package:watchloom/features/community/domain/community_models.dart';

const _id = 'abcdefghijklmnopqrst';
const _profile = 'communityProfiles/owner';
const _comment = 'communityComments/$_id';
const _vote = 'users/owner/communityVotes/$_id';

void main() {
  _Firestore fixture({
    int old = 0,
    String status = 'approved',
    bool missing = false,
  }) => _Firestore({
    _profile: {
      'acceptedPolicyVersion': communityPolicyVersion,
      'voteCount': old == 0 ? 0 : 1,
    },
    if (!missing)
      _comment: {
        'authorUid': 'other',
        'status': status,
        'upVotes': old == 1 ? 1 : 0,
        'downVotes': old == -1 ? 1 : 0,
        'score': old,
      },
    if (old != 0) _vote: {'commentId': _id, 'value': old},
  });

  for (final old in [-1, 0, 1]) {
    for (final value in [-1, 0, 1]) {
      test(
        'atomic vote $old to $value preserves counters and voteCount',
        () async {
          final db = fixture(old: old);
          await CommunityVoteTransaction.apply(
            firestore: db,
            uid: 'owner',
            commentId: _id,
            value: value,
          );
          expect(db.data[_comment]!['upVotes'], value == 1 ? 1 : 0);
          expect(db.data[_comment]!['downVotes'], value == -1 ? 1 : 0);
          expect(db.data[_comment]!['score'], value);
          expect(db.data[_profile]!['voteCount'], value == 0 ? 0 : 1);
          if (value == 0) {
            expect(db.data[_vote], isNull);
          } else {
            expect(db.data[_vote]!['value'], value);
          }
          expect(
            db.lastReads,
            value == 0 ? [_profile, _vote] : [_profile, _comment, _vote],
          );
          expect(db.lastWrites.length, old == value ? 0 : 3);
        },
      );
    }
  }
  test('repeated desired vote is idempotent', () async {
    final db = fixture();
    await CommunityVoteTransaction.apply(
      firestore: db,
      uid: 'owner',
      commentId: _id,
      value: 1,
    );
    await CommunityVoteTransaction.apply(
      firestore: db,
      uid: 'owner',
      commentId: _id,
      value: 1,
    );
    expect(db.data[_comment]!['upVotes'], 1);
    expect(db.data[_profile]!['voteCount'], 1);
    expect(db.lastWrites, isEmpty);
  });
  for (final missing in [false, true]) {
    test(
      'erasing withdraws vote from ${missing ? 'deleted' : 'rejected'} comment',
      () async {
        final db = fixture(old: 1, status: 'rejected', missing: missing);
        await CommunityVoteTransaction.apply(
          firestore: db,
          uid: 'owner',
          commentId: _id,
          value: 0,
          erasing: true,
        );
        expect(db.data[_vote], isNull);
        expect(db.data[_profile]!['voteCount'], 0);
        expect(db.lastWrites.length, missing ? 2 : 3);
        if (!missing) expect(db.data[_comment]!['score'], 0);
      },
    );
  }
  test(
    'new self vote, rejected target and old consent fail without any writes',
    () async {
      for (final problem in ['self', 'rejected', 'consent']) {
        final db = fixture();
        if (problem == 'self') db.data[_comment]!['authorUid'] = 'owner';
        if (problem == 'rejected') db.data[_comment]!['status'] = 'rejected';
        if (problem == 'consent') {
          db.data[_profile]!['acceptedPolicyVersion'] = '2026-11-05';
        }
        await expectLater(
          CommunityVoteTransaction.apply(
            firestore: db,
            uid: 'owner',
            commentId: _id,
            value: 1,
          ),
          throwsA(anyOf(isA<CommunityException>(), isA<FirebaseException>())),
        );
        expect(db.lastWrites, isEmpty);
        expect(db.data[_vote], isNull);
      }
    },
  );
  test(
    'invalid IDs, erasing new votes and inconsistent counters are rejected',
    () async {
      final db = fixture(old: 1)..data[_comment]!['upVotes'] = 0;
      await expectLater(
        CommunityVoteTransaction.apply(
          firestore: db,
          uid: 'owner',
          commentId: _id,
          value: 0,
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(db.data[_vote]!['value'], 1);
      expect(db.data[_profile]!['voteCount'], 1);
      expect(db.attempts, 2);
      await expectLater(
        CommunityVoteTransaction.apply(
          firestore: db,
          uid: 'owner',
          commentId: '../bad',
          value: 1,
        ),
        throwsA(isA<CommunityException>()),
      );
      await expectLater(
        CommunityVoteTransaction.apply(
          firestore: db,
          uid: 'owner',
          commentId: _id,
          value: 1,
          erasing: true,
        ),
        throwsA(isA<CommunityException>()),
      );
    },
  );
  for (final code in ['not-found', 'permission-denied']) {
    test(
      'missing target $code safely retries without reading or updating its body',
      () async {
        final db = fixture(old: -1, missing: true)..missingWriteCode = code;
        await CommunityVoteTransaction.apply(
          firestore: db,
          uid: 'owner',
          commentId: _id,
          value: 0,
          erasing: true,
        );
        expect(db.attempts, 2);
        expect(db.lastReads, [_profile, _vote]);
        expect(db.data[_vote], isNull);
        expect(db.data[_profile]!['voteCount'], 0);
      },
    );
  }
  test(
    'permission fallback cannot remove a vote while skipping an existing target counter',
    () async {
      final db = fixture(old: 1)..failures = ['permission-denied'];
      await expectLater(
        CommunityVoteTransaction.apply(
          firestore: db,
          uid: 'owner',
          commentId: _id,
          value: 0,
          erasing: true,
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(db.attempts, 2);
      expect(db.data[_vote]!['value'], 1);
      expect(db.data[_profile]!['voteCount'], 1);
      expect(db.data[_comment]!['upVotes'], 1);
    },
  );
  test(
    'unknown commit/network error propagates without a fallback or false completion',
    () async {
      final db = fixture(old: 1)..failures = ['unavailable'];
      await expectLater(
        CommunityVoteTransaction.apply(
          firestore: db,
          uid: 'owner',
          commentId: _id,
          value: 0,
          erasing: true,
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(db.attempts, 1);
      expect(db.data[_vote]!['value'], 1);
      expect(db.data[_profile]!['voteCount'], 1);
    },
  );
}

/// Transaction double verifies all reads precede writes and commits atomically.
/// The real security rules are exercised separately in Firebase emulators.
class _Firestore implements FirebaseFirestore {
  _Firestore(this.data);
  final Map<String, Map<String, dynamic>> data;
  List<String> lastReads = [], lastWrites = [];
  int attempts = 0;
  String missingWriteCode = 'not-found';
  List<String> failures = [];
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _Reference(path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    attempts++;
    final tx = _Transaction(data, missingWriteCode);
    lastReads = tx.reads;
    lastWrites = tx.paths;
    final result = await handler(tx);
    if (failures.isNotEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: failures.removeAt(0),
      );
    }
    final original = {
      for (final entry in data.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
    };
    try {
      for (final write in tx.writes) {
        write();
      }
      final old = original[_vote]?['value'] ?? 0,
          next = data[_vote]?['value'] ?? 0;
      if (old != next && original.containsKey(_comment)) {
        final before = original[_comment]!, after = data[_comment]!;
        if (after['upVotes'] !=
                before['upVotes'] + (next == 1 ? 1 : 0) - (old == 1 ? 1 : 0) ||
            after['downVotes'] !=
                before['downVotes'] +
                    (next == -1 ? 1 : 0) -
                    (old == -1 ? 1 : 0) ||
            (after['upVotes'] as int) < 0 ||
            (after['downVotes'] as int) < 0 ||
            after['score'] != after['upVotes'] - after['downVotes']) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        }
      }
    } catch (_) {
      data
        ..clear()
        ..addAll(original);
      rethrow;
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Only a transaction contract double; production uses SDK-created references.
// ignore: subtype_of_sealed_class
class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.path);
  @override
  final String path;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Only a transaction contract double; real authorization runs in emulators.
// ignore: subtype_of_sealed_class
class _Snapshot<T> implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  T? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.data, this.missingWriteCode);
  final Map<String, Map<String, dynamic>> data;
  final String missingWriteCode;
  final List<String> reads = [], paths = [];
  final List<void Function()> writes = [];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    expect(
      writes,
      isEmpty,
      reason: 'Firestore transactions read every target before writes',
    );
    reads.add(ref.path);
    if (ref.path == _comment &&
        data[ref.path] != null &&
        data[ref.path]!['status'] != 'approved') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return _Snapshot<T>(data[ref.path] as T?);
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> value) {
    paths.add(ref.path);
    writes.add(() {
      final target = data[ref.path];
      if (target == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: missingWriteCode,
        );
      }
      for (final entry in value.entries) {
        final transform = [-1, 0, 1]
            .where((delta) => entry.value == FieldValue.increment(delta))
            .firstOrNull;
        target[entry.key] = transform == null
            ? entry.value
            : (target[entry.key] as int? ?? 0) + transform;
      }
    });
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    paths.add(ref.path);
    writes.add(() => data.remove(ref.path));
    return this;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T value, [SetOptions? options]) {
    paths.add(ref.path);
    writes.add(() => data[ref.path] = Map<String, dynamic>.from(value as Map));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
