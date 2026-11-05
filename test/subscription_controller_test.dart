import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/premium/domain/subscription.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'helpers/fake_subscription_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSubscriptionRepository store;
  late SubscriptionController controller;
  var now = DateTime.utc(2026, 11, 4);
  PremiumEntitlement active() => PremiumEntitlement(
    status: PremiumStatus.subscribed,
    accessUntil: now.add(const Duration(days: 30)),
  );

  setUp(() {
    now = DateTime.utc(2026, 11, 4);
    store = FakeSubscriptionRepository();
    controller = SubscriptionController(store, now: () => now);
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
  });

  test(
    'ads wait for verified free status; missing prices do not block free use',
    () async {
      expect(controller.shouldShowAds, isFalse);
      store.productError = StateError('not configured');
      await controller.initialize();
      expect(controller.shouldShowAds, isTrue);
      expect(controller.canPurchase, isFalse);
      expect(controller.product, isNull);
    },
  );

  test(
    'a failed entitlement check never shows ads or allows a duplicate purchase',
    () async {
      store.readError = StateError('unavailable');
      await controller.initialize();
      expect(controller.accessCheckFailed, isTrue);
      expect(controller.shouldShowAds, isFalse);
      expect(controller.canPurchase, isFalse);
      store.readError = null;
      await controller.refreshEntitlement();
      expect(controller.shouldShowAds, isTrue);
      expect(controller.canPurchase, isTrue);
    },
  );

  test('successful purchase opens Premium and removes ads', () async {
    store.purchaseEntitlement = active();
    await controller.initialize();
    final purchase = controller.purchase();
    expect(controller.shouldShowAds, isFalse);
    await purchase;
    expect(controller.hasAccess, isTrue);
    expect(controller.shouldShowAds, isFalse);
    expect(store.purchaseCount, 1);
    await controller.purchase();
    expect(store.purchaseCount, 1);
  });

  test(
    'cancellation does not grant access; pending waits for verified update',
    () async {
      await controller.initialize();
      store.outcome = PurchaseOutcome.cancelled;
      await controller.purchase();
      expect(controller.hasAccess, isFalse);
      expect(controller.notice, isNull);
      store.outcome = PurchaseOutcome.pending;
      await controller.purchase();
      expect(controller.isPurchasePending, isTrue);
      expect(controller.canPurchase, isFalse);
      expect(controller.hasAccess, isFalse);
      store.entitlement = active();
      await controller.refreshEntitlement();
      expect(controller.hasAccess, isTrue);
      expect(controller.isPurchasePending, isFalse);
    },
  );

  test('purchase and restore failures remain recoverable', () async {
    await controller.initialize();
    store.purchaseError = StateError('failure');
    await controller.purchase();
    expect(controller.notice, SubscriptionNotice.purchaseFailed);
    expect(controller.isBusy, isFalse);
    store.restoreError = StateError('failure');
    await controller.restore();
    expect(controller.notice, SubscriptionNotice.restoreFailed);
    expect(controller.shouldShowAds, isFalse);
    store.restoreError = null;
    store.entitlement = active();
    await controller.restore();
    expect(controller.hasAccess, isTrue);
    expect(controller.notice, SubscriptionNotice.restored);
  });

  test('offline access cannot outlive its signed expiration', () async {
    store.entitlement = active();
    await controller.initialize();
    store.readError = StateError('offline');
    await controller.refreshEntitlement();
    expect(controller.hasAccess, isTrue);
    now = now.add(const Duration(days: 31));
    expect(controller.hasAccess, isFalse);
    store.readError = null;
    store.entitlement = const PremiumEntitlement();
    await controller.refreshEntitlement();
    expect(controller.shouldShowAds, isTrue);
  });

  test('restore wins over an older entitlement request', () async {
    await controller.initialize();
    final oldRead = Completer<PremiumEntitlement>();
    store.entitlementRead = oldRead.future;
    final refresh = controller.refreshEntitlement();
    store.entitlement = active();
    await controller.restore();
    oldRead.complete(const PremiumEntitlement());
    await refresh;
    expect(controller.hasAccess, isTrue);
    expect(controller.shouldShowAds, isFalse);
  });

  test(
    'storefront change invalidates previous localized price immediately',
    () async {
      await controller.initialize();
      expect(controller.product?.displayPrice, r'$0.99');
      store.product = const PremiumProduct(
        displayPrice: '₺39,99',
        currencyCode: 'TRY',
      );
      final refresh = controller.refreshProduct();
      expect(controller.product, isNull);
      expect(controller.canPurchase, isFalse);
      await refresh;
      expect(controller.product?.displayPrice, '₺39,99');
    },
  );

  test('invalid or unrelated native products are rejected', () {
    expect(
      () => PremiumProduct.fromMap({
        'id': 'other',
        'displayPrice': '₺39,99',
        'currencyCode': 'TRY',
      }),
      throwsFormatException,
    );
    expect(
      () => PremiumProduct.fromMap({
        'id': premiumMonthlyProductId,
        'displayPrice': '',
        'currencyCode': 'TRY',
      }),
      throwsFormatException,
    );
    expect(
      const PremiumEntitlement(
        status: PremiumStatus.subscribed,
      ).hasAccessAt(now),
      isFalse,
    );
  });
}
