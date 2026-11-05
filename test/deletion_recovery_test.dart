import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchloom/features/account/data/firestore_account_store.dart';

class NoCloudCalls implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected cloud operation before Auth deletion.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'an unfinished Auth deletion never submits an anonymous completion proof',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DeletionRecoveryStore(NoCloudCalls(), prefs);
      await store.prepare('user-a', 'n' * 44);
      await store.retry();
      final record =
          (jsonDecode(prefs.getString('watchloom_deletion_cleanup_v1')!)
              as Map)['user-a'];
      expect(record['deleted'], false);
      expect(record.keys, isNot(contains('email')));
    },
  );
  test(
    'corrupt recovery preferences do not crash startup or touch cloud data',
    () async {
      for (final value in [
        'invalid-json',
        '[]',
        '{"a":1}',
        '{"../bad":{"deleted":true}}',
        '{"a":{"deleted":true,"proof":42}}',
      ]) {
        SharedPreferences.setMockInitialValues({
          'watchloom_deletion_cleanup_v1': value,
        });
        final store = DeletionRecoveryStore(
          NoCloudCalls(),
          await SharedPreferences.getInstance(),
        );
        await expectLater(store.retry(), completes);
      }
    },
  );
}
