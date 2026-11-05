import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/subscription.dart';

abstract class SubscriptionRepository {
  bool get isSupported;
  Stream<String> get updates;
  Future<PremiumEntitlement> readEntitlement();
  Future<PremiumProduct> readProduct();
  Future<PurchaseOutcome> purchase();
  Future<PremiumEntitlement> restore();
  Future<void> manage();
  Future<void> openPrivacy();
  Future<void> openTerms();
}

class StoreKitSubscriptionRepository implements SubscriptionRepository {
  static const _methods = MethodChannel('watchloom/subscriptions');
  static const _events = EventChannel('watchloom/subscription_updates');

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Stream<String> get updates => isSupported
      ? _events.receiveBroadcastStream().cast<String>()
      : const Stream.empty();

  @override
  Future<PremiumEntitlement> readEntitlement() async {
    if (!isSupported) return const PremiumEntitlement();
    final value = await _methods.invokeMapMethod<Object?, Object?>(
      'entitlement',
    );
    if (value == null) throw const FormatException('Missing entitlement');
    return PremiumEntitlement.fromMap(value);
  }

  @override
  Future<PremiumProduct> readProduct() async {
    final value = await _methods.invokeMapMethod<Object?, Object?>('product');
    if (value == null) throw const FormatException('Missing product');
    return PremiumProduct.fromMap(value);
  }

  @override
  Future<PurchaseOutcome> purchase() async {
    final outcome = await _methods.invokeMethod<String>('purchase');
    return switch (outcome) {
      'purchased' => PurchaseOutcome.purchased,
      'pending' => PurchaseOutcome.pending,
      'cancelled' => PurchaseOutcome.cancelled,
      _ => throw const FormatException('Unknown purchase result'),
    };
  }

  @override
  Future<PremiumEntitlement> restore() async {
    final value = await _methods.invokeMapMethod<Object?, Object?>('restore');
    if (value == null) {
      throw const FormatException('Missing restored entitlement');
    }
    return PremiumEntitlement.fromMap(value);
  }

  @override
  Future<void> manage() => _methods.invokeMethod<void>('manage');

  @override
  Future<void> openPrivacy() => _methods.invokeMethod<void>('privacy');

  @override
  Future<void> openTerms() => _methods.invokeMethod<void>('terms');
}
