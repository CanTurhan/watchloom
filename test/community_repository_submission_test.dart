import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/community/data/firestore_community_repository.dart';
import 'package:watchloom/features/community/domain/community_models.dart';

const _id = 'abcdefghijklmnopqrst';
const _path = 'communityComments/$_id';

void main() {
  test(
    'each write refreshes its session even after profile bootstrap is cached',
    () async {
      final db = _Store();
      var refreshes = 0;
      var revoked = false;
      final repository = FirestoreCommunityRepository(
        firestore: db,
        uid: 'owner',
        prepareSession: () async {
          refreshes++;
          if (revoked) {
            throw const CommunityException(
              CommunityFailure.verificationRequired,
            );
          }
        },
      );
      await repository.profile();
      await repository.post(
        contentKey: 'tvmaze:show:123',
        body: 'A thoughtful episode',
      );
      expect(refreshes, 2);
      revoked = true;
      await expectLater(
        repository.deleteComment(_id),
        throwsA(
          isA<CommunityException>().having(
            (e) => e.failure,
            'failure',
            CommunityFailure.verificationRequired,
          ),
        ),
      );
      expect(refreshes, 3);
      expect(db.docs[_path], isNotNull);
    },
  );

  test(
    'legacy owner edit sends current policy and pending revision, preserving votes',
    () async {
      final db = _Store();
      db.docs[_path] = {
        'authorUid': 'owner',
        'contentKey': 'tvmaze:show:123',
        'body': 'Original',
        'status': 'approved',
        'policyVersion': '2026-11-05',
        'upVotes': 3,
        'downVotes': 1,
        'score': 2,
      };
      final repository = FirestoreCommunityRepository(
        firestore: db,
        uid: 'owner',
      );
      await repository.editComment(
        comment: const CommunityComment(
          id: _id,
          contentKind: CommunityContentKind.series,
          contentKey: 'tvmaze:show:123',
          authorUid: 'owner',
          authorName: '@viewer',
          body: 'Original',
          status: CommunityCommentStatus.approved,
          createdAt: null,
        ),
        body: 'Revised thought',
        isSpoiler: false,
      );
      expect(db.docs[_path]!['policyVersion'], communityPolicyVersion);
      expect(db.docs[_path]!['status'], 'pending');
      expect(db.docs[_path]!['editRevision'], 1);
      expect(db.docs[_path]!['score'], 2);
    },
  );

  test(
    'definitive commit rejection explains cooldown without saving or waking moderation',
    () async {
      final db = _Store()..denyCommit = true;
      db.docs['communityProfiles/owner']!['lastPostAt'] = Timestamp.now();
      var wakes = 0;
      final repository = FirestoreCommunityRepository(
        firestore: db,
        uid: 'owner',
        moderationRequest: (_, _) async {
          wakes++;
        },
      );
      await expectLater(
        repository.post(
          contentKey: 'tvmaze:show:123',
          body: 'A thoughtful episode',
        ),
        throwsA(
          isA<CommunityException>().having(
            (e) => e.failure,
            'failure',
            CommunityFailure.rateLimited,
          ),
        ),
      );
      expect(db.postAttempts, 2);
      expect(db.docs[_path], isNull);
      expect(wakes, 0);
    },
  );

  test(
    'profile read denial stays an authorization error and never retries a commit',
    () async {
      final db = _Store()..denyProfileRead = true;
      final repository = FirestoreCommunityRepository(
        firestore: db,
        uid: 'owner',
      );
      await expectLater(
        repository.post(
          contentKey: 'tvmaze:show:123',
          body: 'A thoughtful episode',
        ),
        throwsA(
          isA<CommunityException>().having(
            (e) => e.failure,
            'failure',
            CommunityFailure.permissionDenied,
          ),
        ),
      );
      expect(db.postAttempts, 0);
      expect(db.docs[_path], isNull);
    },
  );
}

/// Tests repository transaction/session behavior. Authorization is checked in
/// the Auth/Firestore emulator suite, not inferred from this contract double.
class _Store implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{
    'users/owner': {'status': 'active'},
    'communityConfig/current': {
      'enabled': true,
      'moderationReady': true,
      'rulesVersion': 2,
      'moderationMode': 'automatic',
      'moderationEndpoint': 'https://watchloom-community.example.workers.dev',
    },
    'communityProfiles/owner': {
      'handle': 'viewer',
      'nickname': null,
      'displayMode': 'handle',
      'acceptedPolicyVersion': communityPolicyVersion,
      'lastPostAt': Timestamp(0, 0),
      'postWindowAt': Timestamp.now(),
      'postsInWindow': 0,
    },
  };
  bool denyCommit = false, denyProfileRead = false;
  int postAttempts = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final tx = _Tx(this);
    final result = await handler(tx);
    if (tx.writes.isNotEmpty) {
      postAttempts++;
      if (denyCommit) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }
      for (final write in tx.writes) {
        write();
      }
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// SDK references are replaced only in this transaction contract test.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Ref(store, '$path/${id ?? _id}');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Ref implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(store.docs[path]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Snapshot<T> implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tx implements Transaction {
  _Tx(this.store);
  final _Store store;
  final writes = <void Function()>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    expect(
      writes,
      isEmpty,
      reason: 'Every transaction read must precede writes',
    );
    if (store.denyProfileRead && ref.path == 'communityProfiles/owner') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return _Snapshot<T>(store.docs[ref.path] as T?);
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    writes.add(() => store.docs[ref.path]!.addAll(data));
    return this;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes.add(
      () => store.docs[ref.path] = Map<String, dynamic>.from(data as Map),
    );
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
