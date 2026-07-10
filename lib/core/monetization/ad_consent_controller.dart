import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentController extends ChangeNotifier {
  AdConsentController._();

  static final AdConsentController instance = AdConsentController._();

  Future<void>? _initializationFuture;

  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _mobileAdsInitialized = false;

  bool get canRequestAds => _canRequestAds;

  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<void> initialize() {
    return _initializationFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    final completer = Completer<void>();

    Future<void> finish() async {
      await _refreshConsentState();

      if (_canRequestAds) {
        await _initializeMobileAds();
      }

      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {
          // Önceki oturumun onay durumu
          // yine de kullanılabilir.
        }

        await finish();
      },
      (_) async {
        await finish();
      },
    );

    await completer.future;
  }

  Future<void> _refreshConsentState() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();

    final requirement = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();

    _privacyOptionsRequired =
        requirement == PrivacyOptionsRequirementStatus.required;

    notifyListeners();
  }

  Future<void> _initializeMobileAds() async {
    if (_mobileAdsInitialized) {
      return;
    }

    await MobileAds.instance.initialize();

    _mobileAdsInitialized = true;
  }

  Future<bool> showPrivacyOptions() async {
    if (!_privacyOptionsRequired) {
      return false;
    }

    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});

      await _refreshConsentState();

      if (_canRequestAds) {
        await _initializeMobileAds();
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
