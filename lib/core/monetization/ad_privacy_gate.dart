import 'package:flutter/material.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:watchloom/features/settings/presentation/pages/ad_privacy_page.dart';

/// Ask once in a session, after StoreKit has identified a free user. Dismissing
/// the page leaves the SDK off, and does not restrict the app's free features.
class AdPrivacyGate extends StatefulWidget {
  const AdPrivacyGate({
    required this.premium,
    required this.privacy,
    required this.child,
    super.key,
  });
  final SubscriptionController premium;
  final AdPrivacyController privacy;
  final Widget child;
  @override
  State<AdPrivacyGate> createState() => _AdPrivacyGateState();
}

class _AdPrivacyGateState extends State<AdPrivacyGate> {
  bool _prompted = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.premium.addListener(_schedule);
  }

  @override
  void didUpdateWidget(AdPrivacyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.premium != widget.premium) {
      oldWidget.premium.removeListener(_schedule);
      widget.premium.addListener(_schedule);
    }
  }

  void _schedule() {
    if (_scheduled || _prompted || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          _prompted ||
          widget.privacy.hasDecision ||
          !widget.premium.shouldShowAds ||
          !(ModalRoute.isCurrentOf(context) ?? true)) {
        return;
      }
      _prompted = true;
      AdPrivacyPage.open(context, closeAfterChoice: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    ModalRoute.isCurrentOf(context);
    _schedule();
    return widget.child;
  }

  @override
  void dispose() {
    widget.premium.removeListener(_schedule);
    super.dispose();
  }
}
