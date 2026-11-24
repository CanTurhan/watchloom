import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/community/presentation/community_strings.dart';

void main() {
  for (final language in ['en', 'tr']) {
    test(
      'rejection feedback separates language, privacy and account failures ($language)',
      () {
        final s = CommunityStrings.forLanguage(language);
        for (final reason in [
          'abuse',
          'hate',
          'sexual',
          'violence',
          'selfHarm',
        ]) {
          expect(s.rejection(reason), s.rejection('abuse'));
          expect(
            s.rejection(reason),
            contains(language == 'tr' ? 'tekrar gönder' : 'submit it again'),
          );
        }
        expect(s.rejection('personalInformation'), isNot(s.rejection('abuse')));
        expect(
          s.rejection('accountUnavailable'),
          contains(
            language == 'tr' ? 'doğrulanamadığı' : 'could not be verified',
          ),
        );
        expect(s.rejection('unknown-server-reason'), s.rejected);
        expect(s.rejection(null), s.rejected);
        expect(
          s.rejection('private backend error'),
          isNot(contains('private backend error')),
        );
      },
    );
  }
}
