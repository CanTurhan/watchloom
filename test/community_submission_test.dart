import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/community/domain/community_submission.dart';
import 'package:watchloom/features/community/domain/community_models.dart';

void main() {
  test(
    'denied cooldown and daily caps are explained without granting a write',
    () {
      final now = DateTime.utc(2026, 11, 18, 12);
      CommunityFailure failure(
        DateTime last,
        DateTime window,
        int count, {
        DateTime? clock,
      }) => CommunitySubmission.deniedFailure(
        lastAt: last,
        windowAt: window,
        count: count,
        now: clock ?? now,
        cooldown: const Duration(seconds: 30),
        maximum: 20,
      );
      expect(
        failure(now.subtract(const Duration(seconds: 10)), now, 1),
        CommunityFailure.rateLimited,
      );
      expect(
        failure(now.subtract(const Duration(minutes: 1)), now, 20),
        CommunityFailure.rateLimited,
      );
      expect(
        failure(now.subtract(const Duration(seconds: 30)), now, 1),
        CommunityFailure.permissionDenied,
      );
      expect(
        failure(
          now.subtract(const Duration(days: 1)),
          now.subtract(const Duration(days: 1)),
          20,
        ),
        CommunityFailure.permissionDenied,
      );
      expect(
        failure(now, now, 20, clock: DateTime.utc(2000)),
        CommunityFailure.permissionDenied,
      );
      expect(
        failure(now, now, 20, clock: DateTime.utc(2100)),
        CommunityFailure.permissionDenied,
      );
    },
  );
  testWidgets(
    'saved comment returns even when moderation wake-up never finishes',
    (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      final pending = CommunitySubmission.requestModeration(
        commentId: 'already-saved',
        endpoint: Uri.parse('https://watchloom-community.example.workers.dev'),
        request: (_, _) {
          calls++;
          return gate.future;
        },
      );
      // The durable save completes before any timer/network result is awaited.
      expect(await pending, 'already-saved');
      expect(gate.isCompleted, false);
      await tester.pump(const Duration(seconds: 16));
      expect(await pending, 'already-saved');
      expect(calls, 1);
      gate.completeError(StateError('late network failure'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'wrong device clocks propose both window choices without local rejection',
    () {
      final started = DateTime.utc(2026, 11, 5);
      for (final clock in [DateTime.utc(2000), started, DateTime.utc(2100)]) {
        final options = [false, true]
            .map(
              (alternate) => CommunitySubmission.resetWindow(
                startedAt: started,
                deviceNow: clock,
                alternate: alternate,
              ),
            )
            .toSet();
        expect(options, {true, false});
      }
    },
  );
  test(
    'a denied atomic proposal retries once while keeping the allocated ID',
    () async {
      const id = 'allocated-outside-retry';
      final attempts = <String>[];
      final result = await CommunitySubmission.attempt(
        submit: (alternate) async {
          attempts.add('$id:$alternate');
          if (!alternate) throw StateError('permission-denied');
          return id;
        },
        canRetry: (error) => error is StateError,
      );
      expect(result, id);
      expect(attempts, ['$id:false', '$id:true']);
    },
  );
  test(
    'network/unknown commit failures never trigger an alternate write',
    () async {
      var attempts = 0;
      await expectLater(
        CommunitySubmission.attempt(
          submit: (alternate) async {
            attempts++;
            throw StateError('unavailable');
          },
          canRetry: (_) => false,
        ),
        throwsStateError,
      );
      expect(attempts, 1);
    },
  );
  test(
    'server rejection of both proposals is propagated after two attempts',
    () async {
      var attempts = 0;
      await expectLater(
        CommunitySubmission.attempt(
          submit: (alternate) async {
            attempts++;
            throw StateError('permission-denied');
          },
          canRetry: (_) => true,
        ),
        throwsStateError,
      );
      expect(attempts, 2);
    },
  );
}
