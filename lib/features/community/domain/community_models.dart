const communityPolicyVersion = '2026-11-06-auto-v1';

enum CommunityContentKind { series, movie }

enum CommunityCommentSort { best, newest }

enum CommunityDisplayMode { handle, nickname }

enum CommunityCommentStatus { pending, approved, rejected }

enum CommunityReportReason { abuse, hate, sexual, spam, spoiler, other }

enum CommunityFailure {
  unavailable,
  verificationRequired,
  identityRequired,
  invalidIdentity,
  handleUnavailable,
  prohibitedText,
  invalidContent,
  rateLimited,
  permissionDenied,
  termsRequired,
}

class CommunityException implements Exception {
  const CommunityException(this.failure);
  final CommunityFailure failure;
  @override
  String toString() => 'CommunityException(${failure.name})';
}

class CommunityAvailability {
  const CommunityAvailability({
    required this.enabled,
    required this.moderationReady,
    this.moderationEndpoint,
  });
  final bool enabled;
  final bool moderationReady;
  final Uri? moderationEndpoint;
  bool get canPost => enabled && moderationReady;
}

class CommunityProfile {
  const CommunityProfile({
    required this.handle,
    this.nickname,
    required this.displayMode,
    this.acceptedPolicyVersion = communityPolicyVersion,
  });
  final String handle;
  final String? nickname;
  final CommunityDisplayMode displayMode;
  final String? acceptedPolicyVersion;
  bool get acceptedTerms => acceptedPolicyVersion == communityPolicyVersion;
  String get publicName =>
      displayMode == CommunityDisplayMode.nickname && nickname != null
      ? nickname!
      : '@$handle';
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.contentKey,
    required this.contentKind,
    required this.authorUid,
    required this.authorName,
    required this.body,
    this.parentId,
    required this.status,
    required this.createdAt,
    this.isSpoiler = false,
    this.moderationReason,
    this.upVotes = 0,
    this.downVotes = 0,
    this.score = 0,
  });
  final String id;
  final String contentKey;
  final CommunityContentKind contentKind;
  final String authorUid;
  final String authorName;
  final String body;
  final String? parentId;
  final CommunityCommentStatus status;
  final DateTime? createdAt;
  final bool isSpoiler;

  /// Only an enum-like moderator reason is stored, never a private report.
  final String? moderationReason;
  final int upVotes;
  final int downVotes;
  final int score;

  CommunityComment withVotes({
    required int upVotes,
    required int downVotes,
    required int score,
  }) => CommunityComment(
    id: id,
    contentKey: contentKey,
    contentKind: contentKind,
    authorUid: authorUid,
    authorName: authorName,
    body: body,
    parentId: parentId,
    status: status,
    createdAt: createdAt,
    isSpoiler: isSpoiler,
    moderationReason: moderationReason,
    upVotes: upVotes,
    downVotes: downVotes,
    score: score,
  );
}
