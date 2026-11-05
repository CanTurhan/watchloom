import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/account/presentation/sign_in_page.dart';

void main() {
  for (final language in ['en', 'tr']) {
    testWidgets('account screen is readable on a small screen in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = AuthController.guestOnly();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: SignInPage(auth: auth),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(
          language == 'tr' ? 'Apple ile devam et' : 'Continue with Apple',
        ),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          language == 'tr' ? 'Apple ile devam et' : 'Continue with Apple',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text(
          language == 'tr' ? 'Google ile devam et' : 'Continue with Google',
        ),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          language == 'tr' ? 'Google ile devam et' : 'Continue with Google',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text(
          language == 'tr' ? 'Misafir olarak devam et' : 'Continue as guest',
        ),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          language == 'tr' ? 'Misafir olarak devam et' : 'Continue as guest',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
