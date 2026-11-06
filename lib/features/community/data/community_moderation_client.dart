import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/community_models.dart';
import '../domain/community_policy.dart';

/// Sends an authenticated wake-up for an already persisted comment. It carries
/// no body, public name, provider credential or private moderation API key.
class CommunityModerationClient {
  CommunityModerationClient({
    required this.boundUid,
    required this.currentUid,
    required this.idToken,
    required this.client,
  });
  final String boundUid;
  final String? Function() currentUid;
  final Future<String?> Function() idToken;
  final http.Client client;

  Future<void> request(String commentId, Uri endpoint) async {
    if (CommunityPolicy.moderationEndpoint(endpoint.toString()) == null ||
        !RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(commentId)) {
      throw const CommunityException(CommunityFailure.invalidContent);
    }
    if (currentUid() != boundUid) {
      throw const CommunityException(CommunityFailure.verificationRequired);
    }
    final token = await idToken();
    if (currentUid() != boundUid || token == null || token.isEmpty) {
      throw const CommunityException(CommunityFailure.verificationRequired);
    }
    final request = http.Request('POST', endpoint.replace(path: '/v1/moderate'))
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({'commentId': commentId});
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 12));
    await response.stream.drain<void>().timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const CommunityException(CommunityFailure.unavailable);
    }
  }
}
