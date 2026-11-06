/// Device time selects an initial proposal, never permission to submit. Rules
/// compare both proposals against request.time. The second proposal is useful
/// for a device clock on the wrong side of a rolling 24-hour window boundary.
abstract final class CommunitySubmission {
  /// The document already exists. A failed wake-up must never look like a failed
  /// submission: the server queue retries processing this same document.
  static Future<String> requestModeration({
    required String commentId,
    required Uri? endpoint,
    CommunityModerationRequest? request,
  }) async {
    if (endpoint != null && request != null) {
      try {
        await request(commentId, endpoint);
      } catch (_) {
        /* Still pending. */
      }
    }
    return commentId;
  }

  static bool resetWindow({
    required DateTime startedAt,
    required DateTime deviceNow,
    required bool alternate,
  }) {
    final suggested =
        deviceNow.difference(startedAt) >= const Duration(days: 1);
    return alternate ? !suggested : suggested;
  }

  /// Only a definitively denied atomic write is retried. Network/unknown commit
  /// errors propagate. The caller allocates its document ID before this call.
  static Future<T> attempt<T>({
    required Future<T> Function(bool alternate) submit,
    required bool Function(Object error) canRetry,
  }) async {
    try {
      return await submit(false);
    } catch (error) {
      if (!canRetry(error)) rethrow;
      return submit(true);
    }
  }
}

typedef CommunityModerationRequest =
    Future<void> Function(String commentId, Uri endpoint);
