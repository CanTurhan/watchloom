import 'dart:async';
import 'community_models.dart';

/// Device time selects an initial proposal, never permission to submit. Rules
/// compare both proposals against request.time. The second proposal is useful
/// for a device clock on the wrong side of a rolling 24-hour window boundary.
abstract final class CommunitySubmission {
  /// Used only AFTER a definitive rules denial, never to authorize or prevent
  /// a write. Server rules remain authoritative even with a wrong device clock.
  static CommunityFailure deniedFailure({
    required DateTime lastAt,
    required DateTime windowAt,
    required int count,
    required DateTime now,
    required Duration cooldown,
    required int maximum,
  }) {
    final sinceLast = now.difference(lastAt);
    final sinceWindow = now.difference(windowAt);
    if ((!sinceLast.isNegative && sinceLast < cooldown) ||
        (!sinceWindow.isNegative &&
            sinceWindow < const Duration(days: 1) &&
            count >= maximum)) {
      return CommunityFailure.rateLimited;
    }
    return CommunityFailure.permissionDenied;
  }

  /// The document already exists. A failed wake-up must never look like a failed
  /// submission: the server queue retries processing this same document.
  static Future<String> requestModeration({
    required String commentId,
    required Uri? endpoint,
    CommunityModerationRequest? request,
  }) async {
    if (endpoint != null && request != null) {
      unawaited(_wake(commentId, endpoint, request));
    }
    return commentId;
  }

  static Future<void> _wake(
    String id,
    Uri endpoint,
    CommunityModerationRequest request,
  ) async {
    try {
      await request(id, endpoint).timeout(const Duration(seconds: 15));
    } catch (_) {
      // The server's scheduled queue owns delivery. Never retry a saved write,
      // hold the composer open, or treat a failed wake-up as publication.
    }
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
