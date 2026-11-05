import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/subscription_repository.dart';
import '../domain/subscription.dart';

class SubscriptionController extends ChangeNotifier
    with WidgetsBindingObserver {
  SubscriptionController(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SubscriptionRepository _repository;
  final DateTime Function() _now;
  StreamSubscription<String>? _updates;
  Timer? _expirationTimer;
  bool _disposed = false;
  int _entitlementRevision = 0;
  int _productRevision = 0;

  PremiumEntitlement _entitlement = const PremiumEntitlement();
  PremiumProduct? _product;
  bool _initialized = false;
  bool _checkingAccess = false;
  bool _accessCheckFailed = false;
  bool _pendingPurchase = false;
  bool _loadingProduct = false;
  bool _busy = false;
  SubscriptionNotice? _notice;

  PremiumEntitlement get entitlement => _entitlement;
  PremiumProduct? get product => _product;
  bool get isInitialized => _initialized;
  bool get isCheckingAccess => _checkingAccess;
  bool get accessCheckFailed => _accessCheckFailed;
  bool get isPurchasePending => _pendingPurchase;
  bool get isLoadingProduct => _loadingProduct;
  bool get isBusy => _busy;
  bool get isSupported => _repository.isSupported;
  bool get shouldShowAds =>
      isSupported &&
      _initialized &&
      !_checkingAccess &&
      !_accessCheckFailed &&
      !_busy &&
      !hasAccess;
  bool get hasAccess => _entitlement.hasAccessAt(_now());
  bool get canPurchase =>
      isSupported &&
      _initialized &&
      !_checkingAccess &&
      !_accessCheckFailed &&
      !_pendingPurchase &&
      !_busy &&
      !_loadingProduct &&
      _product != null &&
      !hasAccess;
  SubscriptionNotice? get notice => _notice;

  bool _started = false;

  Future<void> initialize() async {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _updates = _repository.updates.listen((event) {
      unawaited(refreshEntitlement());
      unawaited(refreshProduct());
    }, onError: (Object _) => unawaited(refreshEntitlement()));
    unawaited(refreshProduct());
    await refreshEntitlement();
  }

  Future<void> refreshEntitlement() async {
    if (_disposed) return;
    final revision = ++_entitlementRevision;
    _checkingAccess = true;
    notifyListeners();
    try {
      final value = await _repository.readEntitlement().timeout(
        const Duration(seconds: 12),
      );
      if (_disposed || revision != _entitlementRevision) return;
      _accessCheckFailed = false;
      _setEntitlement(value);
    } catch (_) {
      // A failed network request cannot invent or extend access. An existing
      // verified entitlement remains usable only until its signed expiry.
      if (!_disposed && revision == _entitlementRevision) {
        _accessCheckFailed = true;
      }
    } finally {
      if (!_disposed && revision == _entitlementRevision) {
        _initialized = true;
        _checkingAccess = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshProduct() async {
    if (!isSupported || _disposed) return;
    final revision = ++_productRevision;
    // Invalidate old prices immediately, including on a storefront change.
    _product = null;
    _loadingProduct = true;
    notifyListeners();
    try {
      final value = await _repository.readProduct().timeout(
        const Duration(seconds: 12),
      );
      if (_disposed || revision != _productRevision) return;
      _product = value;
      if (_notice == SubscriptionNotice.storeUnavailable) _notice = null;
    } catch (_) {
      if (!_disposed && revision == _productRevision && !hasAccess) {
        _notice = SubscriptionNotice.storeUnavailable;
      }
    } finally {
      if (!_disposed && revision == _productRevision) {
        _loadingProduct = false;
        notifyListeners();
      }
    }
  }

  void _setEntitlement(PremiumEntitlement value) {
    _entitlement = value;
    if (hasAccess) {
      _pendingPurchase = false;
      if (_notice == SubscriptionNotice.storeUnavailable ||
          _notice == SubscriptionNotice.pending) {
        _notice = null;
      }
    }
    _expirationTimer?.cancel();
    final expiry = value.accessUntil;
    if (expiry != null && expiry.isAfter(_now())) {
      _expirationTimer = Timer(expiry.difference(_now()), () {
        if (_disposed) return;
        notifyListeners();
        unawaited(refreshEntitlement());
      });
    }
  }

  Future<void> purchase() async {
    if (!canPurchase) return;
    _busy = true;
    _notice = null;
    notifyListeners();
    try {
      final outcome = await _repository.purchase();
      if (_disposed) return;
      await Future.wait([refreshEntitlement(), refreshProduct()]);
      if (!_disposed &&
          !hasAccess &&
          (outcome == PurchaseOutcome.pending ||
              outcome == PurchaseOutcome.purchased)) {
        _pendingPurchase = true;
        _notice = SubscriptionNotice.pending;
      }
    } catch (_) {
      if (!_disposed) _notice = SubscriptionNotice.purchaseFailed;
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> restore() async {
    if (_busy || !isSupported) return;
    _busy = true;
    _notice = null;
    notifyListeners();
    ++_entitlementRevision;
    try {
      final value = await _repository.restore();
      if (_disposed) return;
      ++_entitlementRevision;
      _checkingAccess = false;
      _accessCheckFailed = false;
      _setEntitlement(value);
      _initialized = true;
      _notice = hasAccess
          ? SubscriptionNotice.restored
          : SubscriptionNotice.nothingToRestore;
      await refreshProduct();
    } catch (_) {
      if (!_disposed) {
        _notice = SubscriptionNotice.restoreFailed;
        _accessCheckFailed = true;
      }
    } finally {
      if (!_disposed) {
        _initialized = true;
        _checkingAccess = false;
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> manage() => _open(() async {
    await _repository.manage();
    await refreshEntitlement();
    await refreshProduct();
  });
  Future<void> openPrivacy() => _open(_repository.openPrivacy);
  Future<void> openTerms() => _open(_repository.openTerms);

  Future<void> _open(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!_disposed) {
        _notice = SubscriptionNotice.linkFailed;
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshEntitlement());
      unawaited(refreshProduct());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _updates?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}
