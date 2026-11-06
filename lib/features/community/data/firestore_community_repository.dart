import 'package:cloud_firestore/cloud_firestore.dart';
import '../../account/data/firestore_account_store.dart';
import '../domain/community_models.dart';
import '../domain/community_policy.dart';
import '../domain/community_repository.dart';
import '../domain/community_submission.dart';

class FirestoreCommunityRepository implements CommunityRepository {
  FirestoreCommunityRepository({required this.firestore, required this.uid});
  final FirebaseFirestore firestore;
  final String? uid;
  Future<void>? _bootstrap;
  static const _server = GetOptions(source: Source.server);
  CollectionReference<Map<String, dynamic>> get _comments =>
      firestore.collection('communityComments');
  DocumentReference<Map<String, dynamic>> _profile(String id) =>
      firestore.collection('communityProfiles').doc(id);
  String get _owner {
    if (uid == null) {
      throw const CommunityException(CommunityFailure.verificationRequired);
    }
    return uid!;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      throw CommunityException(
        error.code == 'permission-denied'
            ? CommunityFailure.permissionDenied
            : CommunityFailure.unavailable,
      );
    }
  }

  Future<void> _prepareOwner() async {
    final previous = _bootstrap;
    if (previous != null) return previous;
    final pending = FirestoreAccountStore(firestore, _owner).bootstrap();
    _bootstrap = pending;
    try {
      await pending;
    } catch (_) {
      if (identical(_bootstrap, pending)) _bootstrap = null;
      rethrow;
    }
  }

  @override
  Future<CommunityAvailability> availability() => _guard(() async {
    final data =
        (await firestore
                .collection('communityConfig')
                .doc('current')
                .get(_server))
            .data();
    return CommunityAvailability(
      enabled: data?['enabled'] == true,
      moderationReady:
          data?['moderationReady'] == true && data?['rulesVersion'] == 1,
    );
  });

  @override
  Future<CommunityProfile?> profile() => _guard(() async {
    await _prepareOwner();
    final data = (await _profile(_owner).get(_server)).data();
    return data == null ? null : _identity(data);
  });

  @override
  Future<CommunityProfile> saveProfile({
    required String handle,
    String? nickname,
    required CommunityDisplayMode displayMode,
    bool acceptedTerms = false,
  }) => _guard(() async {
    if (!acceptedTerms) {
      throw const CommunityException(CommunityFailure.termsRequired);
    }
    await _prepareOwner();
    final identity = CommunityPolicy.identity(
      handle: handle,
      nickname: nickname,
      displayMode: displayMode,
    );
    final owner = _owner;
    final ref = _profile(owner);
    final reservation = firestore
        .collection('communityHandles')
        .doc(identity.handle);
    await firestore.runTransaction((tx) async {
      final old = await tx.get(ref);
      if (old.exists) {
        if (old.data()!['handle'] != identity.handle) {
          throw const CommunityException(CommunityFailure.invalidIdentity);
        }
        tx.update(ref, {
          'nickname': identity.nickname,
          'displayMode': identity.displayMode.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'acceptedPolicyVersion': CommunityPolicy.termsVersion,
          'acceptedPolicyAt': FieldValue.serverTimestamp(),
        });
      } else {
        // A reservation owned by someone else is intentionally not readable.
        // Failed permission means unavailable; no UID is disclosed by a lookup.
        try {
          final taken = await tx.get(reservation);
          if (taken.exists) {
            throw const CommunityException(CommunityFailure.handleUnavailable);
          }
        } on FirebaseException catch (error) {
          if (error.code == 'permission-denied') {
            throw const CommunityException(CommunityFailure.handleUnavailable);
          }
          rethrow;
        }
        tx.set(ref, {
          'schema': 1,
          'handle': identity.handle,
          'nickname': identity.nickname,
          'displayMode': identity.displayMode.name,
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedPolicyVersion': CommunityPolicy.termsVersion,
          'acceptedPolicyAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastPostAt': Timestamp(0, 0),
          'lastPostId': null,
          'postWindowAt': Timestamp(0, 0),
          'postsInWindow': 0,
          'lastReportAt': Timestamp(0, 0),
          'lastReportId': null,
          'reportWindowAt': Timestamp(0, 0),
          'reportsInWindow': 0,
        });
        tx.set(reservation, {
          'uid': owner,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
    return identity;
  });

  @override
  Future<List<CommunityComment>> comments({
    required String contentKey,
    CommunityContentKind contentKind = CommunityContentKind.series,
    int limit = 50,
  }) => _guard(() async {
    CommunityPolicy.content(contentKey, contentKind);
    final page = await _comments
        .where('contentKey', isEqualTo: contentKey)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, 50))
        .get(_server);
    return page.docs.map(_comment).toList(growable: false);
  });

  @override
  Future<List<CommunityComment>> pendingComments({
    required String contentKey,
  }) => _guard(() async {
    await _prepareOwner();
    CommunityPolicy.content(contentKey, CommunityContentKind.series);
    final page = await _comments
        .where('authorUid', isEqualTo: _owner)
        .where('contentKey', isEqualTo: contentKey)
        .where('status', whereIn: ['pending', 'rejected'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get(_server);
    return page.docs.map(_comment).toList(growable: false);
  });

  @override
  Future<String> post({
    required String contentKey,
    CommunityContentKind contentKind = CommunityContentKind.series,
    required String body,
    String? parentId,
    bool isSpoiler = false,
  }) => _guard(() async {
    CommunityPolicy.content(contentKey, contentKind);
    final text = CommunityPolicy.body(body);
    if (!(await availability()).canPost) {
      throw const CommunityException(CommunityFailure.unavailable);
    }
    await _prepareOwner();
    final owner = _owner, profileRef = _profile(_owner), ref = _comments.doc();
    await CommunitySubmission.attempt(
      submit: (alternate) => firestore.runTransaction((tx) async {
        final identity = await tx.get(profileRef);
        if (!identity.exists) {
          throw const CommunityException(CommunityFailure.identityRequired);
        }
        final data = identity.data()!;
        if (parentId != null) {
          if (!RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(parentId)) {
            throw const CommunityException(CommunityFailure.invalidContent);
          }
          final parent = (await tx.get(_comments.doc(parentId))).data();
          if (parent == null ||
              parent['contentKey'] != contentKey ||
              parent['status'] != 'approved' ||
              parent['parentId'] != null) {
            throw const CommunityException(CommunityFailure.invalidContent);
          }
        }
        tx.set(ref, {
          'schema': 1,
          'contentKey': contentKey,
          'contentKind': contentKind.name,
          'authorUid': owner,
          'authorName': _identity(data).publicName,
          'body': text,
          'parentId': parentId,
          'isSpoiler': isSpoiler,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(profileRef, _counter(data, 'Post', ref.id, alternate));
      }),
      canRetry: _counterDenied,
    );
    return ref.id;
  });

  @override
  Future<void> deleteComment(String id) =>
      _guard(() => _comments.doc(id).delete());

  @override
  Future<void> report({
    required String commentId,
    required CommunityReportReason reason,
  }) => _guard(() async {
    await _prepareOwner();
    final owner = _owner;
    final ref = firestore.collection('communityReports').doc();
    final profileRef = _profile(owner);
    await CommunitySubmission.attempt(
      submit: (alternate) => firestore.runTransaction((tx) async {
        final identity = await tx.get(profileRef);
        if (!identity.exists) {
          throw const CommunityException(CommunityFailure.identityRequired);
        }
        tx.set(ref, {
          'commentId': commentId,
          'reporterUid': owner,
          'reason': reason.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          firestore
              .collection('users')
              .doc(owner)
              .collection('communityReportRefs')
              .doc(ref.id),
          {'reportId': ref.id, 'createdAt': FieldValue.serverTimestamp()},
        );
        tx.update(
          profileRef,
          _counter(identity.data()!, 'Report', ref.id, alternate),
        );
      }),
      canRetry: _counterDenied,
    );
  });

  @override
  Future<void> blockUser(String authorUid) => _guard(() async {
    await _prepareOwner();
    if (authorUid == _owner ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(authorUid)) {
      throw const CommunityException(CommunityFailure.invalidIdentity);
    }
    final ref = firestore
        .collection('communityBlocks')
        .doc(_owner)
        .collection('authors')
        .doc(authorUid);
    await firestore.runTransaction((tx) async {
      if (!(await tx.get(ref)).exists) {
        tx.set(ref, {
          'blockedUid': authorUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  });

  @override
  Future<void> unblockUser(String authorUid) => _guard(
    () => firestore
        .collection('communityBlocks')
        .doc(_owner)
        .collection('authors')
        .doc(authorUid)
        .delete(),
  );

  @override
  Future<Set<String>> blockedUsers() => _guard(() async {
    await _prepareOwner();
    final result = <String>{};
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = firestore
          .collection('communityBlocks')
          .doc(_owner)
          .collection('authors')
          .orderBy(FieldPath.documentId)
          .limit(100);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get(_server);
      result.addAll(page.docs.map((doc) => doc.id));
      if (page.docs.length < 100) break;
      cursor = page.docs.last;
    }
    return result;
  });

  static CommunityProfile _identity(Map<String, dynamic> data) =>
      CommunityProfile(
        handle: data['handle'] as String,
        nickname: data['nickname'] as String?,
        displayMode: CommunityDisplayMode.values.byName(
          data['displayMode'] as String,
        ),
      );

  static CommunityComment _comment(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return CommunityComment(
      id: doc.id,
      contentKey: data['contentKey'] as String,
      contentKind: CommunityContentKind.values.byName(
        data['contentKind'] as String,
      ),
      authorUid: data['authorUid'] as String,
      authorName: data['authorName'] as String,
      body: data['body'] as String,
      parentId: data['parentId'] as String?,
      status: CommunityCommentStatus.values.byName(data['status'] as String),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isSpoiler: data['isSpoiler'] == true,
      moderationReason: data['moderationReason'] as String?,
    );
  }

  static bool _counterDenied(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';

  static Map<String, dynamic> _counter(
    Map<String, dynamic> data,
    String kind,
    String id,
    bool alternate,
  ) {
    final prefix = kind == 'Post' ? 'post' : 'report';
    final plural = '${prefix}sInWindow', window = '${prefix}WindowAt';
    final oldWindow = data[window] as Timestamp;
    final reset = CommunitySubmission.resetWindow(
      startedAt: oldWindow.toDate(),
      deviceNow: DateTime.now().toUtc(),
      alternate: alternate,
    );
    final count = reset ? 1 : (data[plural] as int) + 1;
    return {
      'last${kind}At': FieldValue.serverTimestamp(),
      'last${kind}Id': id,
      window: reset ? FieldValue.serverTimestamp() : oldWindow,
      plural: count,
    };
  }
}
