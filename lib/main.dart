import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import 'package:watchloom/app/watchloom_app.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/network/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await YandexAds.initialize();

  await YandexAds.setUserConsent(false);
  await YandexAds.setLocationTracking(false);
  await YandexAds.setLogging(false);
  await YandexAds.initialize();

  final localeController = await AppLocaleController.create();
  final dependencies = await AppDependencies.create();

  runApp(
    WatchloomApp(
      localeController: localeController,
      showRepository: dependencies.showRepository,
      libraryController: dependencies.libraryController,
      activityController: dependencies.activityController,
    ),
  );
}
