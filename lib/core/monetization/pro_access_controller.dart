import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProAccessController extends ChangeNotifier {
  ProAccessController._();

  static final ProAccessController instance = ProAccessController._();

  static const String productId = 'com.canturhan.watchloom.removeads';

  static const String _proUnlockedKey = 'watchloom_pro_unlocked';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Future<void>? _initializationFuture;

  ProductDetails? _product;

  bool _isPro = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  bool _storeAvailable = false;

  String? _lastError;

  bool get isPro => _isPro;

  bool get isLoading => _isLoading;

  bool get isPurchasing => _isPurchasing;

  bool get isRestoring => _isRestoring;

  bool get storeAvailable => _storeAvailable;

  ProductDetails? get product => _product;

  String? get lastError => _lastError;

  String? get localizedPrice => _product?.price;

  Future<void> initialize() {
    return _initializationFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      (purchases) {
        unawaited(_handlePurchases(purchases));
      },
      onError: (Object error) {
        _lastError = error.toString();
        _isPurchasing = false;
        _isRestoring = false;
        notifyListeners();
      },
    );

    final preferences = await SharedPreferences.getInstance();

    _isPro = preferences.getBool(_proUnlockedKey) ?? false;

    try {
      _storeAvailable = await _inAppPurchase.isAvailable();

      if (_storeAvailable) {
        final response = await _inAppPurchase.queryProductDetails(
          const <String>{productId},
        );

        if (response.error != null) {
          _lastError = response.error?.message;
        }

        for (final product in response.productDetails) {
          if (product.id == productId) {
            _product = product;
            break;
          }
        }
      }
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> purchase() async {
    await initialize();

    final selectedProduct = _product;

    if (!_storeAvailable || selectedProduct == null || _isPurchasing) {
      return false;
    }

    _lastError = null;
    _isPurchasing = true;
    notifyListeners();

    try {
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: selectedProduct),
      );

      if (!started) {
        _isPurchasing = false;
        notifyListeners();
      }

      return started;
    } catch (error) {
      _lastError = error.toString();
      _isPurchasing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    await initialize();

    if (!_storeAvailable || _isRestoring) {
      return false;
    }

    _lastError = null;
    _isRestoring = true;
    notifyListeners();

    try {
      await _inAppPurchase.restorePurchases();
      return true;
    } catch (error) {
      _lastError = error.toString();
      return false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isPurchasing = true;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _unlockPro();

          _isPurchasing = false;
          _isRestoring = false;
          _lastError = null;

        case PurchaseStatus.error:
          _lastError = purchase.error?.message;
          _isPurchasing = false;
          _isRestoring = false;

        case PurchaseStatus.canceled:
          _isPurchasing = false;
          _isRestoring = false;
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchase);
        } catch (error) {
          _lastError = error.toString();
        }
      }
    }

    notifyListeners();
  }

  Future<void> _unlockPro() async {
    if (_isPro) {
      return;
    }

    _isPro = true;

    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_proUnlockedKey, true);
  }
}
