import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_policy.dart';
import 'package:watchloom/features/community/domain/community_repository.dart';

class FakeCommunityRepository implements CommunityRepository {
  CommunityAvailability availabilityValue = const CommunityAvailability(
    enabled: true,
    moderationReady: true,
  );
  CommunityProfile? profileValue = const CommunityProfile(
    handle: 'viewer',
    displayMode: CommunityDisplayMode.handle,
  );
  List<CommunityComment> approved = [];
  List<CommunityComment> pending = [];
  Set<String> blocks = {};
  final List<(String, CommunityReportReason)> reports = [];
  bool acceptedTermsValue = false;
  Object? postFailure;
  Object? privateReadFailure;
  int posted = 0;

  @override
  Future<CommunityAvailability> availability() async => availabilityValue;
  @override
  Future<CommunityProfile?> profile() async {
    if (privateReadFailure != null) throw privateReadFailure!;
    return profileValue;
  }

  @override
  Future<CommunityProfile> saveProfile({
    required String handle,
    String? nickname,
    required CommunityDisplayMode displayMode,
    bool acceptedTerms = false,
  }) async {
    if (!acceptedTerms) {
      throw const CommunityException(CommunityFailure.termsRequired);
    }
    acceptedTermsValue = acceptedTerms;
    return profileValue = CommunityPolicy.identity(
      handle: handle,
      nickname: nickname,
      displayMode: displayMode,
    );
  }

  @override
  Future<List<CommunityComment>> comments({
    required String contentKey,
    CommunityContentKind contentKind = CommunityContentKind.series,
    int limit = 50,
  }) async => List.of(approved);
  @override
  Future<List<CommunityComment>> pendingComments({
    required String contentKey,
  }) async {
    if (privateReadFailure != null) throw privateReadFailure!;
    return List.of(pending);
  }

  @override
  Future<String> post({
    required String contentKey,
    CommunityContentKind contentKind = CommunityContentKind.series,
    required String body,
    String? parentId,
    bool isSpoiler = false,
  }) async {
    if (postFailure != null) throw postFailure!;
    final id = 'submitted${++posted}';
    pending.add(
      CommunityComment(
        id: id,
        contentKey: contentKey,
        contentKind: contentKind,
        authorUid: 'owner',
        authorName: profileValue!.publicName,
        body: body,
        parentId: parentId,
        status: CommunityCommentStatus.pending,
        createdAt: DateTime(2026, 11, 6),
        isSpoiler: isSpoiler,
      ),
    );
    return id;
  }

  @override
  Future<void> deleteComment(String id) async {
    approved.removeWhere((comment) => comment.id == id);
    pending.removeWhere((comment) => comment.id == id);
  }

  @override
  Future<void> report({
    required String commentId,
    required CommunityReportReason reason,
  }) async => reports.add((commentId, reason));
  @override
  Future<void> blockUser(String authorUid) async => blocks.add(authorUid);
  @override
  Future<void> unblockUser(String authorUid) async => blocks.remove(authorUid);
  @override
  Future<Set<String>> blockedUsers() async {
    if (privateReadFailure != null) throw privateReadFailure!;
    return Set.of(blocks);
  }
}
