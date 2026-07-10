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

class WatchloomApp extends StatelessWidget {
  const WatchloomApp({
    required this.localeController,
    required this.showRepository,
    required this.libraryController,
    required this.activityController,
    super.key,
  });

  final AppLocaleController localeController;
  final ShowRepository showRepository;
  final LibraryController libraryController;
  final WatchActivityController activityController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) {
        return AppScope(
          showRepository: showRepository,
          libraryController: libraryController,
          activityController: activityController,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: localeController.locale,
            supportedLocales: const [Locale('en'), Locale('tr')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            onGenerateTitle: (context) {
              return AppStrings.of(context).appName;
            },
            theme: AppTheme.dark,
            home: MainShell(localeController: localeController),
          ),
        );
      },
    );
  }
}
