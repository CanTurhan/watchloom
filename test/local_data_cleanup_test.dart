import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/settings/data/local_data_reset_service.dart';

void main() {
  test(
    'clear watch data removes generated exports and preserves unrelated files and links',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'watchloom-cleanup-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final generated = File('${directory.path}/watchloom_2026_11_123.png');
      final unrelated = File('${directory.path}/other.png');
      final similarlyNamed = File('${directory.path}/watchloom_user_photo.png');
      await generated.writeAsString('generated watch activity');
      await unrelated.writeAsString('unrelated');
      await similarlyNamed.writeAsString('unrelated');
      final link = Link('${directory.path}/watchloom_2026_11_456.png');
      await link.create(unrelated.path);
      await LocalDataResetService.clearGeneratedShareImages(directory);
      expect(await generated.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
      expect(await similarlyNamed.exists(), isTrue);
      expect(await link.exists(), isTrue);
    },
  );
}
