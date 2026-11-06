import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_policy.dart';
import 'package:watchloom/features/community/domain/community_repository.dart';
import 'package:watchloom/features/community/domain/community_vote.dart';

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
  Map<String, int> votes = {};
  final List<(String, int)> voteRequests = [];
  final List<CommunityCommentSort> sortRequests = [];
  Future<void>? voteGate;
  Object? voteFailure;

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
    CommunityCommentSort sort = CommunityCommentSort.best,
  }) async {
    sortRequests.add(sort);
    final result = List.of(approved)
      ..sort((a, b) {
        if (sort == CommunityCommentSort.best && a.score != b.score) {
          return b.score.compareTo(a.score);
        }
        return (b.createdAt ?? DateTime(0)).compareTo(
          a.createdAt ?? DateTime(0),
        );
      });
    return result.take(limit).toList();
  }

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

  @override
  Future<Map<String, int>> votesForComments(Iterable<String> ids) async => {
    for (final id in ids)
      if (votes.containsKey(id)) id: votes[id]!,
  };
  @override
  Future<void> setVote({required String commentId, required int value}) async {
    voteRequests.add((commentId, value));
    if (voteGate != null) await voteGate;
    if (voteFailure != null) throw voteFailure!;
    final index = approved.indexWhere((comment) => comment.id == commentId);
    if (index < 0) {
      throw const CommunityException(CommunityFailure.invalidContent);
    }
    final comment = approved[index];
    final totals = CommunityVoteTotals(
      upVotes: comment.upVotes,
      downVotes: comment.downVotes,
    ).change(previous: votes[commentId] ?? 0, next: value);
    approved[index] = comment.withVotes(
      upVotes: totals.upVotes,
      downVotes: totals.downVotes,
      score: totals.score,
    );
    if (value == 0) {
      votes.remove(commentId);
    } else {
      votes[commentId] = value;
    }
  }
}
