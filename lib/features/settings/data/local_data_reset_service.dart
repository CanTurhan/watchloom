import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/core/notifications/upcoming_episode_notification_service.dart';

class LocalDataResetService {
  const LocalDataResetService({this.database});
  final WatchloomDatabase? database;

  Future<void> clearAllWatchloomData() async {
    await UpcomingEpisodeNotificationService.instance.disable();

    final ownerDatabase = database ?? WatchloomDatabase();
    final db = await ownerDatabase.database;

    await db.transaction((transaction) async {
      await transaction.delete('episode_watch_logs');

      await transaction.delete('unlocked_achievements');

      await transaction.delete('library_entries');
    });
    ownerDatabase.didChange();
    await clearGeneratedShareImages(await getTemporaryDirectory());
  }

  /// Delete only this app's generated exports, never arbitrary temporary files.
  static Future<void> clearGeneratedShareImages(Directory directory) async {
    final ownedImage = RegExp(r'^watchloom_\d+_\d+_\d+\.png$');
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && ownedImage.hasMatch(path.basename(entity.path))) {
        await entity.delete();
      }
    }
  }
}
