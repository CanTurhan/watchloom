import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/community/domain/community_submission.dart';

void main() {
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
