import 'package:flutter/material.dart';
import 'package:watchloom/app/watchloom_app.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/network/app_dependencies.dart';
import 'package:watchloom/core/legal/native_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerNativeLicenses();

  final localeController = await AppLocaleController.create();
  final dependencies = await AppDependencies.create();

  runApp(
    WatchloomApp(
      localeController: localeController,
      showRepository: dependencies.showRepository,
      libraryController: dependencies.libraryController,
      activityController: dependencies.activityController,
      premiumController: dependencies.premiumController,
      adPrivacyController: dependencies.adPrivacyController,
    ),
  );
}
