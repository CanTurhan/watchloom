import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

class WatchloomBanner extends StatefulWidget {
  const WatchloomBanner({super.key});

  @override
  State<WatchloomBanner> createState() => _WatchloomBannerState();
}

class _WatchloomBannerState extends State<WatchloomBanner> {
  static const String _adUnitId = 'R-M-19758972-1';

  BannerAd? _banner;
  StreamSubscription<BannerAdLoadState>? _subscription;

  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_requested) {
      return;
    }

    _requested = true;
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final width = MediaQuery.sizeOf(context).width.round();

    final banner = BannerAd(adSize: BannerAdSize.sticky(width: width));

    _banner = banner;

    _subscription = banner.loadStateStream.listen((state) {
      if (!mounted) {
        return;
      }

      if (state is BannerAdLoadStateLoaded) {
        setState(() {
          _loaded = true;
        });
      }

      if (state is BannerAdLoadStateError) {
        setState(() {
          _loaded = false;
        });
      }
    });

    await banner.load(AdRequest(adUnitId: _adUnitId));
  }

  @override
  void dispose() {
    final subscription = _subscription;
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

    if (!_loaded || banner == null) {
      return const SizedBox.shrink();
    }

    return AdWidget(bannerAd: banner);
  }
}
