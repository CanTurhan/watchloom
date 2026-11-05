import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/premium/domain/subscription.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';

class PremiumPage extends StatelessWidget {
  const PremiumPage({this.libraryLimitReached = false, super.key});

  final bool libraryLimitReached;

  static Future<void> open(
    BuildContext context, {
    bool libraryLimitReached = false,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PremiumPage(libraryLimitReached: libraryLimitReached),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).premiumController;
    final strings = AppStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(strings.premiumTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF33284F), AppColors.surface],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.accentSoft,
                            size: 38,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            controller.hasAccess
                                ? strings.premiumActive
                                : strings.premiumHeadline,
                            style: const TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            controller.hasAccess
                                ? strings.premiumActiveBody
                                : strings.premiumSubtitle,
                            style: const TextStyle(
                              color: AppColors.accentSoft,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (libraryLimitReached && !controller.hasAccess) ...[
                      _Message(
                        title: strings.libraryLimitTitle,
                        body: strings.libraryLimitBody,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _Benefit(
                      icon: Icons.video_library_outlined,
                      title: strings.unlimitedShows,
                      body: strings.unlimitedShowsBody,
                    ),
                    const SizedBox(height: 18),
                    _Benefit(
                      icon: Icons.visibility_off_outlined,
                      title: strings.noAds,
                      body: strings.noAdsBody,
                    ),
                    const SizedBox(height: 24),
                    if (controller.hasAccess)
                      _ActivePlan(controller: controller)
                    else
                      _PurchasePlan(controller: controller),
                    if (_notice(controller.notice, strings)
                        case final String notice) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: _Message(body: notice),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      key: const Key('restore-purchases'),
                      onPressed: controller.isSupported && !controller.isBusy
                          ? controller.restore
                          : null,
                      child: Text(strings.restorePurchases),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.freeFeaturesRemain,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.existingLibrarySafe,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => LegalPage.openPrivacy(context),
                          child: Text(strings.privacyPolicy),
                        ),
                        TextButton(
                          onPressed: controller.openTerms,
                          child: Text(strings.subscriptionTerms),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _notice(SubscriptionNotice? notice, AppStrings strings) =>
      switch (notice) {
        SubscriptionNotice.purchaseFailed => strings.purchaseFailed,
        SubscriptionNotice.restoreFailed => strings.restoreFailed,
        SubscriptionNotice.pending => strings.purchasePending,
        SubscriptionNotice.restored => strings.purchaseRestored,
        SubscriptionNotice.nothingToRestore => strings.nothingToRestore,
        SubscriptionNotice.linkFailed => strings.linkFailed,
        // Product availability has its own recovery action in the plan card.
        SubscriptionNotice.storeUnavailable || null => null,
      };
}

class _PurchasePlan extends StatelessWidget {
  const _PurchasePlan({required this.controller});
  final SubscriptionController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final product = controller.product;
    final checking = !controller.isInitialized || controller.isCheckingAccess;
    final unavailable =
        !controller.isSupported ||
        controller.accessCheckFailed ||
        (!controller.isLoadingProduct && product == null);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.monthlyPlan,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (product != null)
            Text(
              strings.perMonth(product.displayPrice),
              key: const Key('monthly-price'),
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: AppColors.accentSoft,
              ),
            ),
          if (checking || controller.isLoadingProduct) ...[
            const SizedBox(height: 12),
            Text(
              checking ? strings.accessChecking : strings.storeLoading,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (unavailable && !checking) ...[
            Text(
              !controller.isSupported
                  ? strings.iosPurchaseOnly
                  : controller.accessCheckFailed
                  ? strings.accessCheckFailed
                  : strings.storeUnavailable,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (controller.isSupported)
              TextButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        await Future.wait([
                          controller.refreshEntitlement(),
                          controller.refreshProduct(),
                        ]);
                      },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(strings.retryStore),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('subscribe-monthly'),
            onPressed: controller.canPurchase ? controller.purchase : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: controller.isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    product == null
                        ? strings.premiumTitle
                        : strings.subscribeMonthly(product.displayPrice),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            strings.renewalTerms,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePlan extends StatelessWidget {
  const _ActivePlan({required this.controller});
  final SubscriptionController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final expiry = controller.entitlement.accessUntil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expiry != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              controller.entitlement.willAutoRenew == true
                  ? strings.renewsOn(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(expiry.toLocal()),
                    )
                  : strings.accessThrough(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(expiry.toLocal()),
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.accentSoft),
            ),
          ),
        FilledButton.tonal(
          onPressed: controller.isBusy ? null : controller.manage,
          child: Text(strings.manageSubscription),
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: AppColors.accentSoft),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({this.title, required this.body});
  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
        ],
        Text(body, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}
