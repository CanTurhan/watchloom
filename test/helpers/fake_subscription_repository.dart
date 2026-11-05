import 'dart:async';
import 'package:watchloom/features/premium/data/subscription_repository.dart';
import 'package:watchloom/features/premium/domain/subscription.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  @override
  bool isSupported = true;
  final events = StreamController<String>.broadcast(sync: true);
  PremiumEntitlement entitlement = const PremiumEntitlement();
  PremiumProduct product = const PremiumProduct(
    displayPrice: r'$0.99',
    currencyCode: 'USD',
  );
  PurchaseOutcome outcome = PurchaseOutcome.purchased;
  PremiumEntitlement? purchaseEntitlement;
  Object? readError;
  Object? productError;
  Object? purchaseError;
  Object? restoreError;
  Future<PremiumEntitlement>? entitlementRead;
  Future<PremiumEntitlement>? restoreRead;
  int purchaseCount = 0;
  int restoreCount = 0;

  @override
  Stream<String> get updates => events.stream;
  @override
  Future<PremiumEntitlement> readEntitlement() async {
    if (readError != null) throw readError!;
    return entitlementRead ?? Future.value(entitlement);
  }

  @override
  Future<PremiumProduct> readProduct() async {
    if (productError != null) throw productError!;
    return product;
  }

  @override
  Future<PurchaseOutcome> purchase() async {
    purchaseCount++;
    if (purchaseError != null) throw purchaseError!;
    if (purchaseEntitlement != null) entitlement = purchaseEntitlement!;
    return outcome;
  }

  @override
  Future<PremiumEntitlement> restore() async {
    restoreCount++;
    if (restoreError != null) throw restoreError!;
    return restoreRead ?? Future.value(entitlement);
  }

  @override
  Future<void> manage() async {}
  @override
  Future<void> openPrivacy() async {}
  @override
  Future<void> openTerms() async {}

  Future<void> close() => events.close();
}
