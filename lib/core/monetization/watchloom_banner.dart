import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

class WatchloomBanner extends StatefulWidget {
  const WatchloomBanner({super.key});

  @override
  State<WatchloomBanner> createState() => _WatchloomBannerState();
}

class _WatchloomBannerState extends State<WatchloomBanner> {
  static const String _adUnitId = 'demo-banner-yandex';

  BannerAd? _banner;
  StreamSubscription<BannerAdLoadState>? _loadSubscription;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_requested) {
      return;
    }

    _requested = true;
    unawaited(_loadBanner());
  }

  Future<void> _loadBanner() async {
    final width = MediaQuery.sizeOf(context).width.round();

    final banner = BannerAd(adSize: BannerAdSize.sticky(width: width));

    _loadSubscription = banner.loadStateStream.listen((state) {
      if (state is BannerAdLoadStateLoaded) {
        debugPrint('YANDEX BANNER: LOADED');
      } else if (state is BannerAdLoadStateError) {
        debugPrint('YANDEX BANNER ERROR: $state');
      }
    });

    if (!mounted) {
      await banner.destroy();
      return;
    }

    setState(() {
      _banner = banner;
    });

    await banner.load(AdRequest(adUnitId: _adUnitId));
  }

  @override
  void dispose() {
    final subscription = _loadSubscription;
    final banner = _banner;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    if (banner != null) {
      unawaited(banner.destroy());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;

    if (banner == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.center,
      child: AdWidget(bannerAd: banner),
    );
  }
}
