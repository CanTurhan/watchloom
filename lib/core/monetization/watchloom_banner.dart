import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:watchloom/core/monetization/ad_consent_controller.dart';
import 'package:watchloom/core/theme/app_colors.dart';

class WatchloomBanner extends StatefulWidget {
  const WatchloomBanner({super.key});

  @override
  State<WatchloomBanner> createState() {
    return _WatchloomBannerState();
  }
}

class _WatchloomBannerState extends State<WatchloomBanner> {
  static const String _iosBannerAdUnitId =
      'ca-app-pub-8274979068153688/1762523828';

  final AdConsentController _consentController = AdConsentController.instance;

  BannerAd? _bannerAd;

  bool _loadingAd = false;
  int? _loadedWidth;

  @override
  void initState() {
    super.initState();

    _consentController.addListener(_handleConsentChanged);

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _consentController.initialize();

    _scheduleRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _scheduleRefresh();
  }

  void _handleConsentChanged() {
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_refreshAd());
    });
  }

  Future<void> _refreshAd() async {
    if (!mounted) {
      return;
    }

    if (!_consentController.canRequestAds) {
      await _disposeBanner();
      return;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();

    if (width <= 0 ||
        _loadingAd ||
        (_bannerAd != null && _loadedWidth == width)) {
      return;
    }

    await _disposeBanner();

    _loadingAd = true;
    _loadedWidth = width;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);

    if (size == null || !mounted) {
      _loadingAd = false;
      return;
    }

    final banner = BannerAd(
      adUnitId: _iosBannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            unawaited(ad.dispose());
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
            _loadingAd = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          unawaited(ad.dispose());

          if (!mounted) {
            return;
          }

          setState(() {
            _bannerAd = null;
            _loadingAd = false;
          });

          debugPrint(
            'Watchloom banner load failed: '
            '${error.code} ${error.message}',
          );
        },
      ),
    );

    await banner.load();
  }

  Future<void> _disposeBanner() async {
    final currentBanner = _bannerAd;

    _bannerAd = null;
    _loadedWidth = null;
    _loadingAd = false;

    if (currentBanner != null) {
      await currentBanner.dispose();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _consentController.removeListener(_handleConsentChanged);

    final currentBanner = _bannerAd;

    if (currentBanner != null) {
      unawaited(currentBanner.dispose());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;

    if (banner == null) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: AppColors.surface,
      child: SizedBox(
        width: double.infinity,
        height: banner.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: banner.size.width.toDouble(),
            height: banner.size.height.toDouble(),
            child: AdWidget(ad: banner),
          ),
        ),
      ),
    );
  }
}
