const premiumMonthlyProductId = 'com.canturhan.watchloom.premium.monthly';

enum PremiumStatus { free, subscribed }

class PremiumEntitlement {
  const PremiumEntitlement({
    this.status = PremiumStatus.free,
    this.accessUntil,
    this.willAutoRenew,
  });

  factory PremiumEntitlement.fromMap(Map<Object?, Object?> value) {
    return PremiumEntitlement(
      status: switch (value['status']) {
        'subscribed' => PremiumStatus.subscribed,
        _ => PremiumStatus.free,
      },
      accessUntil: switch (value['accessUntil']) {
        final num milliseconds => DateTime.fromMillisecondsSinceEpoch(
          milliseconds.toInt(),
          isUtc: true,
        ),
        _ => null,
      },
      willAutoRenew: value['willAutoRenew'] as bool?,
    );
  }

  final PremiumStatus status;
  final DateTime? accessUntil;
  final bool? willAutoRenew;

  bool hasAccessAt(DateTime now) =>
      (status == PremiumStatus.subscribed &&
      accessUntil != null &&
      now.isBefore(accessUntil!));
}

class PremiumProduct {
  const PremiumProduct({
    required this.displayPrice,
    required this.currencyCode,
  });

  factory PremiumProduct.fromMap(Map<Object?, Object?> value) {
    if (value['id'] != premiumMonthlyProductId ||
        value['displayPrice'] is! String ||
        (value['displayPrice'] as String).isEmpty ||
        value['currencyCode'] is! String ||
        (value['currencyCode'] as String).isEmpty) {
      throw const FormatException('Invalid subscription product');
    }
    return PremiumProduct(
      displayPrice: value['displayPrice'] as String,
      currencyCode: value['currencyCode'] as String,
    );
  }

  // Preserve StoreKit's exact formatting, including currency and separators.
  // The app language and the Apple Account storefront can be different.
  final String displayPrice;
  final String currencyCode;
}

enum PurchaseOutcome { purchased, pending, cancelled }

enum SubscriptionNotice {
  storeUnavailable,
  purchaseFailed,
  restoreFailed,
  pending,
  restored,
  nothingToRestore,
  linkFailed,
}
