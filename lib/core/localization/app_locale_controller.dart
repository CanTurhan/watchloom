import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._({
    required this._preferences,
    required Locale initialLocale,
  }) : _locale = initialLocale;

  static const String _languageKey = 'watchloom_language';

  final SharedPreferences _preferences;

  Locale _locale;

  Locale get locale => _locale;

  static Future<AppLocaleController> create() async {
    final preferences = await SharedPreferences.getInstance();
    final savedLanguage = preferences.getString(_languageKey);

    final deviceLanguage = PlatformDispatcher.instance.locale.languageCode
        .toLowerCase();

    final initialLanguage =
        savedLanguage ?? (deviceLanguage == 'tr' ? 'tr' : 'en');

    return AppLocaleController._(
      preferences: preferences,
      initialLocale: Locale(initialLanguage),
    );
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'tr') {
      return;
    }

    if (_locale.languageCode == languageCode) {
      return;
    }

    _locale = Locale(languageCode);
    await _preferences.setString(_languageKey, languageCode);
    notifyListeners();
  }
}
