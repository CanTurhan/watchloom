import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdvertisingChoice { undecided, allowed, declined }

/// A separate, revocable choice for loading the advertising SDK. The SDK's own
/// personal-data consent remains false; choosing ads does not authorize tracking.
class AdPrivacyController extends ChangeNotifier {
  AdPrivacyController(
    this._preferences, {
    Future<void> Function()? withdrawNative,
  }) : _withdrawNative = withdrawNative ?? _stopNativeReporting {
    try {
      final record = jsonDecode(
        _preferences.getString(preferenceKey) ?? 'null',
      );
      if (record is Map && record['allowed'] == false) {
        // A previous refusal remains a refusal after a notice update.
        _choice = AdvertisingChoice.declined;
      } else if (record is Map &&
          record['version'] == noticeVersion &&
          record['allowed'] == true &&
          record['decidedAt'] is String &&
          DateTime.tryParse(record['decidedAt'] as String) != null) {
        _choice = AdvertisingChoice.allowed;
      }
    } catch (_) {
      // A missing, older or invalid consent record never permits SDK startup.
    }
  }

  static const preferenceKey = 'watchloom_advertising_choice';
  static const noticeVersion = 1;
  final SharedPreferences _preferences;
  final Future<void> Function() _withdrawNative;
  AdvertisingChoice _choice = AdvertisingChoice.undecided;
  bool _saving = false;
  bool _sdkStarted = false;
  bool _disposed = false;

  AdvertisingChoice get choice => _choice;
  bool get hasDecision => _choice != AdvertisingChoice.undecided;
  bool get adsAllowed => _choice == AdvertisingChoice.allowed;
  bool get isSaving => _saving;
  bool get sdkStartedThisSession => _sdkStarted;

  void markSdkStarted() => _sdkStarted = true;

  static Future<void> _stopNativeReporting() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await const MethodChannel(
        'watchloom/advertising_privacy',
      ).invokeMethod<void>('withdraw');
    }
  }

  Future<void> setAllowed(bool allowed) async {
    if (_disposed || _saving) return;
    _saving = true;
    // Withdrawal removes the active banner before persistence or native work.
    if (!allowed) _choice = AdvertisingChoice.declined;
    notifyListeners();
    try {
      if (!allowed && _sdkStarted) {
        try {
          await _withdrawNative();
        } catch (_) {
          // Persist the refusal regardless. The UI explains that closing the
          // current session stops a previously initialized SDK completely.
        }
      }
      final saved = await _preferences.setString(
        preferenceKey,
        jsonEncode({
          'version': noticeVersion,
          'allowed': allowed,
          'decidedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (!saved) throw StateError('Advertising preference could not be saved');
      if (!_disposed) {
        _choice = allowed
            ? AdvertisingChoice.allowed
            : AdvertisingChoice.declined;
      }
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
