import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shell/presentation/main_shell.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/features/account/presentation/account_session_controller.dart';
import 'package:watchloom/features/account/presentation/account_page.dart';

class WatchloomApp extends StatelessWidget {
  const WatchloomApp({
    required this.localeController,
    required this.showRepository,
    required this.libraryController,
    required this.activityController,
    required this.premiumController,
    required this.adPrivacyController,
    this.accountSession,
    super.key,
  });

  final AppLocaleController localeController;
  final ShowRepository showRepository;
  final LibraryController libraryController;
  final WatchActivityController activityController;
  final SubscriptionController premiumController;
  final AdPrivacyController adPrivacyController;
  final AccountSessionController? accountSession;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, accountSession]),
      builder: (context, _) {
        return AppScope(
          showRepository: showRepository,
          libraryController: accountSession?.library ?? libraryController,
          activityController: accountSession?.activity ?? activityController,
          premiumController: premiumController,
          adPrivacyController: adPrivacyController,
          accountSession: accountSession,
          child: MaterialApp(
            key: ValueKey(accountSession?.generation ?? 0),
            debugShowCheckedModeBanner: false,
            locale: localeController.locale,
            supportedLocales: const [Locale('en'), Locale('tr')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            onGenerateTitle: (context) {
              return AppStrings.of(context).appName;
            },
            theme: AppTheme.dark,
            home: accountSession?.switching == true
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : accountSession?.failed == true
                ? Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: accountSession!.retry,
                        child: Text(
                          localeController.locale.languageCode == 'tr'
                              ? 'Kütüphane açılamadı. Tekrar dene'
                              : 'Library unavailable. Retry',
                        ),
                      ),
                    ),
                  )
                : accountSession?.deletionPending == true
                ? AccountPage(session: accountSession!)
                : MainShell(localeController: localeController),
          ),
        );
      },
    );
  }
}
