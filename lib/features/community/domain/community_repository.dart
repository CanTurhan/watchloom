import 'community_models.dart';

abstract interface class CommunityRepository {
  Future<CommunityAvailability> availability();
  Future<CommunityProfile?> profile();
  Future<CommunityProfile> saveProfile({
    required String handle,
    String? nickname,
    required CommunityDisplayMode displayMode,
    bool acceptedTerms = false,
  });
  Future<List<CommunityComment>> comments({
    required String contentKey,
    CommunityContentKind contentKind = CommunityContentKind.series,
    int limit = 50,
  });
  Future<List<CommunityComment>> pendingComments({required String contentKey});
  Future<String> post({
    required String contentKey,
    CommunityContentKind contentKind = CommunityContentKind.series,
    required String body,
    String? parentId,
    bool isSpoiler = false,
  });
  Future<void> deleteComment(String id);
  Future<void> report({
    required String commentId,
    required CommunityReportReason reason,
  });
  Future<void> blockUser(String authorUid);
  Future<void> unblockUser(String authorUid);
  Future<Set<String>> blockedUsers();
}
