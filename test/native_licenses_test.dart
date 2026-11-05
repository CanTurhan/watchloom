import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the app bundles notices for the native advertising and crash SDKs', () async {
    final records = jsonDecode(await rootBundle.loadString('assets/legal/ios_licenses.json')) as List;
    final packages = records.map((record) => record['name']).toSet();
    expect(packages, containsAll(['YandexMobileAds', 'AppMetricaCore', 'KSCrash']));
    for (final record in records) {
      expect((record['text'] as String).trim(), isNotEmpty, reason: record['name']);
    }
  });
}
