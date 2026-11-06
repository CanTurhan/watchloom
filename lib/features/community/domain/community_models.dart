enum CommunityContentKind { series, movie }

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
  });
  final bool enabled;
  final bool moderationReady;
  bool get canPost => enabled && moderationReady;
}

class CommunityProfile {
  const CommunityProfile({
    required this.handle,
    this.nickname,
    required this.displayMode,
  });
  final String handle;
  final String? nickname;
  final CommunityDisplayMode displayMode;
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
}
