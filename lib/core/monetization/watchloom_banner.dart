import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/core/localization/app_legal_strings.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

/// Removing the subtree disposes the native ad immediately after an upgrade
/// or when another route (including a purchase screen) covers the shell.
class WatchloomBannerSlot extends StatelessWidget {
  const WatchloomBannerSlot({
    required this.controller,
    required this.privacyController,
    this.adBuilder,
    super.key,
  });
  final SubscriptionController controller;
  final AdPrivacyController privacyController;
  final WidgetBuilder? adBuilder;

  @override
  Widget build(BuildContext context) {
    final routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, privacyController]),
      builder: (context, _) {
        if (!routeIsCurrent ||
            !controller.shouldShowAds ||
            !privacyController.adsAllowed) {
          return const SizedBox.shrink();
        }
        return adBuilder?.call(context) ??
            _AdaptiveBanner(privacyController: privacyController);
      },
    );
  }
}

class _AdaptiveBanner extends StatelessWidget {
  const _AdaptiveBanner({required this.privacyController});
  final AdPrivacyController privacyController;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    minimum: const EdgeInsets.symmetric(horizontal: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floor();
        if (width < 1) return const SizedBox.shrink();
        return Center(
          child: _Banner(
            key: ValueKey(width),
            width: width,
            privacyController: privacyController,
          ),
        );
      },
    ),
  );
}

class _Banner extends StatefulWidget {
  const _Banner({
    required this.width,
    required this.privacyController,
    super.key,
  });
  final int width;
  final AdPrivacyController privacyController;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  static Future<void>? _initialization;
  static const _testAds = bool.fromEnvironment('WATCHLOOM_TEST_ADS');
  static const _productionUnit = String.fromEnvironment(
    'WATCHLOOM_BANNER_AD_UNIT_ID',
    defaultValue: 'R-M-19758972-1',
  );
  static const _adUnit = kReleaseMode && !_testAds
      ? _productionUnit
      : 'demo-banner-yandex';

  BannerAd? _banner;
  StreamSubscription<BannerAdLoadState>? _subscription;
  double _width = 0;
  double _height = 0;
  bool _ready = false;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  static Future<void> _initializeSdk() async {
    await const MethodChannel(
      'watchloom/advertising_privacy',
    ).invokeMethod<void>('configure');
    // No advertising consent is asserted on the user's behalf. Library data
    // and viewing history are never attached to an ad request.
    await YandexAds.setUserConsent(false);
    await YandexAds.setLocationTracking(false);
    await YandexAds.setLogging(false);
    await YandexAds.initialize();
    // Reapply the IDFA/reporting restrictions after SDK activation as well.
    await const MethodChannel(
      'watchloom/advertising_privacy',
    ).invokeMethod<void>('configure');
  }

  Future<void> _load() async {
    try {
      if (!widget.privacyController.adsAllowed) return;
      widget.privacyController.markSdkStarted();
      await (_initialization ??= _initializeSdk());
      if (!mounted) return;
      final size = BannerAdSize.sticky(width: widget.width);
      final calculated = await size.getCalculatedBannerAdSize();
      if (!mounted) return;
      final banner = BannerAd(adSize: size);
      _banner = banner;
      _width = calculated.width.toDouble();
      _height = calculated.height.toDouble();
      _subscription = banner.loadStateStream.listen((state) {
        if (!mounted || _failed) return;
        if (state is BannerAdLoadStateLoaded) {
          setState(() {
            _loaded = true;
            _width = state.width.toDouble();
            _height = state.height.toDouble();
          });
        } else if (state is BannerAdLoadStateError) {
          _fail();
        }
      }, onError: (Object _) => _fail());
      // SDK 8.3 creates its platform widget in load(), before native loading
      // begins in onPlatformViewCreated. Mount AdWidget only after this call.
      await banner.load(const AdRequest(adUnitId: _adUnit));
      if (mounted && !_failed) setState(() => _ready = true);
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted || _failed) return;
    setState(() => _failed = true);
    _release();
  }

  void _release() {
    final subscription = _subscription;
    final banner = _banner;
    _subscription = null;
    _banner = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (banner != null) unawaited(_destroy(banner));
  }

  Future<void> _destroy(BannerAd banner) async {
    try {
      await banner.destroy();
    } catch (_) {
      // An ad disposal error must not interrupt navigation or a purchase.
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (banner == null || !_ready || _failed) return const SizedBox.shrink();
    return Offstage(
      offstage: !_loaded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.of(context).advertisement,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: AppStrings.of(context).reportAd,
                onPressed: () => LegalPage.openAdReport(context),
                icon: const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: _width,
            height: _height,
            child: AdWidget(bannerAd: banner),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
