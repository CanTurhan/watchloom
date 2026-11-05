import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a new installation has not granted advertising permission', () async {
    final controller = AdPrivacyController(
      await SharedPreferences.getInstance(),
    );
    addTearDown(controller.dispose);
    expect(controller.adsAllowed, isFalse);
    expect(controller.hasDecision, isFalse);
    expect(controller.sdkStartedThisSession, isFalse);
  });

  test(
    'a granted choice records the version and date and survives relaunch',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final controller = AdPrivacyController(preferences);
      addTearDown(controller.dispose);
      await controller.setAllowed(true);
      expect(controller.adsAllowed, isTrue);
      final record = jsonDecode(
        preferences.getString(AdPrivacyController.preferenceKey)!,
      );
      expect(record['version'], AdPrivacyController.noticeVersion);
      expect(DateTime.tryParse(record['decidedAt']), isNotNull);
      final relaunched = AdPrivacyController(preferences);
      addTearDown(relaunched.dispose);
      expect(relaunched.adsAllowed, isTrue);
    },
  );

  test(
    'withdrawal blocks ads immediately and remains withdrawn after relaunch',
    () async {
      final preferences = await SharedPreferences.getInstance();
      var nativeWithdrawals = 0;
      final controller = AdPrivacyController(
        preferences,
        withdrawNative: () async {
          nativeWithdrawals++;
        },
      );
      addTearDown(controller.dispose);
      await controller.setAllowed(true);
      controller.markSdkStarted();
      final withdrawal = controller.setAllowed(false);
      expect(controller.adsAllowed, isFalse);
      await withdrawal;
      expect(nativeWithdrawals, 1);
      expect(controller.choice, AdvertisingChoice.declined);
      expect(controller.sdkStartedThisSession, isTrue);
      final relaunched = AdPrivacyController(preferences);
      addTearDown(relaunched.dispose);
      expect(relaunched.adsAllowed, isFalse);
      expect(relaunched.sdkStartedThisSession, isFalse);
    },
  );

  test(
    'a native reporting failure cannot prevent persisting a refusal',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final controller = AdPrivacyController(
        preferences,
        withdrawNative: () async => throw StateError('native unavailable'),
      );
      addTearDown(controller.dispose);
      await controller.setAllowed(true);
      controller.markSdkStarted();
      await controller.setAllowed(false);
      final relaunched = AdPrivacyController(preferences);
      addTearDown(relaunched.dispose);
      expect(relaunched.choice, AdvertisingChoice.declined);
    },
  );

  test(
    'old permission and missing consent dates cannot initialize ads',
    () async {
      for (final record in [
        {'version': 0, 'allowed': true, 'decidedAt': '2026-11-05T00:00:00Z'},
        {'version': AdPrivacyController.noticeVersion, 'allowed': true},
        {
          'version': AdPrivacyController.noticeVersion,
          'allowed': true,
          'decidedAt': 'invalid',
        },
      ]) {
        SharedPreferences.setMockInitialValues({
          AdPrivacyController.preferenceKey: jsonEncode(record),
        });
        final controller = AdPrivacyController(
          await SharedPreferences.getInstance(),
        );
        expect(controller.adsAllowed, isFalse);
        controller.dispose();
      }
    },
  );

  test(
    'a previous refusal is respected when the notice version changes',
    () async {
      SharedPreferences.setMockInitialValues({
        AdPrivacyController.preferenceKey: '{"version":0,"allowed":false}',
      });
      final controller = AdPrivacyController(
        await SharedPreferences.getInstance(),
      );
      addTearDown(controller.dispose);
      expect(controller.hasDecision, isTrue);
      expect(controller.adsAllowed, isFalse);
    },
  );

  test('a corrupt record fails closed', () async {
    SharedPreferences.setMockInitialValues({
      AdPrivacyController.preferenceKey: 'broken-json',
    });
    final controller = AdPrivacyController(
      await SharedPreferences.getInstance(),
    );
    addTearDown(controller.dispose);
    expect(controller.adsAllowed, isFalse);
  });
}
