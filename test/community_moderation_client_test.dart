import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:watchloom/features/community/data/community_moderation_client.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_policy.dart';
import 'package:watchloom/features/community/domain/community_submission.dart';

void main() {
  const id = 'abcdefghijklmnopqrst';
  final endpoint = Uri.parse('https://watchloom.owner.workers.dev');
  test(
    'wake-up sends only comment ID to fixed path and never follows redirects',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://watchloom.owner.workers.dev/v1/moderate',
        );
        expect(request.headers['Authorization'], 'Bearer test-id-token');
        expect(jsonDecode(request.body), {'commentId': id});
        expect(request.followRedirects, isFalse);
        return http.Response('{}', 202);
      });
      await CommunityModerationClient(
        boundUid: 'owner',
        currentUid: () => 'owner',
        idToken: () async => 'test-id-token',
        client: client,
      ).request(id, endpoint);
    },
  );
  test(
    'host, credentials, port, query, fragment and unexpected path fail before token/network',
    () async {
      var tokens = 0, requests = 0;
      final client = CommunityModerationClient(
        boundUid: 'owner',
        currentUid: () => 'owner',
        idToken: () async {
          tokens++;
          return 'token';
        },
        client: MockClient((_) async {
          requests++;
          return http.Response('', 200);
        }),
      );
      for (final address in [
        'http://a.workers.dev',
        'https://workers.dev',
        'https://a.workers.dev.evil.com',
        'https://a.workers.dev@evil.com',
        'https://user:pass@a.workers.dev',
        'https://a.workers.dev:8443',
        'https://a.workers.dev?token=x',
        'https://a.workers.dev#x',
        'https://a.workers.dev/other',
        'https://-invalid.workers.dev',
      ]) {
        expect(
          CommunityPolicy.moderationEndpoint(address),
          isNull,
          reason: address,
        );
        await expectLater(
          client.request(id, Uri.parse(address)),
          throwsA(isA<CommunityException>()),
        );
      }
      expect(tokens, 0);
      expect(requests, 0);
    },
  );
  test(
    'UID changes while fetching a token prevent a stale-account request',
    () async {
      var uid = 'owner', requests = 0;
      final token = Completer<String?>();
      final client = CommunityModerationClient(
        boundUid: 'owner',
        currentUid: () => uid,
        idToken: () => token.future,
        client: MockClient((_) async {
          requests++;
          return http.Response('', 200);
        }),
      );
      final request = client.request(id, endpoint);
      uid = 'new-owner';
      token.complete('old-token');
      await expectLater(request, throwsA(isA<CommunityException>()));
      expect(requests, 0);
    },
  );
  test(
    'unavailable worker never turns an already-persisted comment into a failed submission',
    () async {
      var calls = 0;
      final result = await CommunitySubmission.requestModeration(
        commentId: id,
        endpoint: endpoint,
        request: (_, _) async {
          calls++;
          throw StateError('Unavailable');
        },
      );
      expect(result, id);
      expect(calls, 1);
      expect(
        await CommunitySubmission.requestModeration(
          commentId: id,
          endpoint: null,
        ),
        id,
      );
    },
  );
  test(
    'old policy consent is explicit and never silently upgraded by parsing',
    () {
      expect(
        const CommunityProfile(
          handle: 'fan',
          displayMode: CommunityDisplayMode.handle,
        ).acceptedTerms,
        isTrue,
      );
      expect(
        const CommunityProfile(
          handle: 'fan',
          displayMode: CommunityDisplayMode.handle,
          acceptedPolicyVersion: '2026-11-05',
        ).acceptedTerms,
        isFalse,
      );
      expect(
        const CommunityProfile(
          handle: 'fan',
          displayMode: CommunityDisplayMode.handle,
          acceptedPolicyVersion: null,
        ).acceptedTerms,
        isFalse,
      );
    },
  );
}
