import 'community_models.dart';

/// A fast, conservative composition aid. This is NOT a trust boundary:
/// Firestore creates pending comments; server moderation decides publication.
abstract final class CommunityPolicy {
  static const termsVersion = communityPolicyVersion;
  static const maxBodyLength = 1200;
  static Uri? moderationEndpoint(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !RegExp(
          r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+workers\.dev$',
        ).hasMatch(uri.host)) {
      return null;
    }
    return uri;
  }

  static final _handle = RegExp(r'^[a-z][a-z0-9_]{2,19}$');
  static final _nickname = RegExp(
    r'^[\p{L}\p{M}\p{N} _-]{3,24}$',
    unicode: true,
  );
  static final _body = RegExp(
    r'^[\p{L}\p{M}\p{N}\p{P}\p{S} \n]+$',
    unicode: true,
  );
  static final _contact = RegExp(
    r'(https?\s*:|www\s*\.|@)',
    caseSensitive: false,
  );
  static final _forbidden = RegExp(
    r'(^|[^a-z])(fuck|shit|bitch|nigger|nigga|cunt|orospu|siktir|sikik|amk|aq)([^a-z]|$)',
    caseSensitive: false,
  );

  static String normalizeHandle(String value) => value.trim().toLowerCase();
  static String? normalizeNickname(String? value) {
    final result = value?.trim().replaceAll(RegExp(r' +'), ' ');
    return result == null || result.isEmpty ? null : result;
  }

  static CommunityProfile identity({
    required String handle,
    String? nickname,
    required CommunityDisplayMode displayMode,
  }) {
    final normalized = normalizeHandle(handle);
    final nick = normalizeNickname(nickname);
    if (!_handle.hasMatch(normalized) ||
        (nick != null && !_nickname.hasMatch(nick)) ||
        (displayMode == CommunityDisplayMode.nickname && nick == null)) {
      throw const CommunityException(CommunityFailure.invalidIdentity);
    }
    if (isProhibited(normalized.replaceAll('_', ' ')) ||
        (nick != null && isProhibited(nick))) {
      throw const CommunityException(CommunityFailure.prohibitedText);
    }
    return CommunityProfile(
      handle: normalized,
      nickname: nick,
      displayMode: displayMode,
    );
  }

  static bool isProhibited(String text) {
    final folded = text
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't');
    return _contact.hasMatch(text) || _forbidden.hasMatch(folded);
  }

  static String body(String value) {
    final text = value.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty ||
        text.length > maxBodyLength ||
        !_body.hasMatch(text) ||
        isProhibited(text)) {
      throw const CommunityException(CommunityFailure.prohibitedText);
    }
    return text;
  }

  /// Only catalog-backed TVMaze series IDs are accepted in this release.
  static void content(String key, CommunityContentKind kind) {
    if (kind != CommunityContentKind.series ||
        !RegExp(r'^tvmaze:show:[1-9][0-9]{0,9}$').hasMatch(key)) {
      throw const CommunityException(CommunityFailure.invalidContent);
    }
  }
}
