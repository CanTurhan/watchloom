import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerNativeLicenses() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  LicenseRegistry.addLicense(() async* {
    final records =
        jsonDecode(
              await rootBundle.loadString('assets/legal/ios_licenses.json'),
            )
            as List;
    for (final record in records.cast<Map<String, dynamic>>()) {
      yield LicenseEntryWithLineBreaks([
        record['name'] as String,
      ], record['text'] as String);
    }
  });
}
