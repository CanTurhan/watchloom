import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:watchloom/core/notifications/upcoming_episode_notification_service.dart';

class LocalDataResetService {
  const LocalDataResetService();

  Future<void> clearAllWatchloomData() async {
    await UpcomingEpisodeNotificationService.instance.disable();

    final databasesPath = await getDatabasesPath();

    final databasePath = path.join(databasesPath, 'watchloom.db');

    final database = await openDatabase(databasePath);

    await database.transaction((transaction) async {
      await transaction.delete('episode_watch_logs');

      await transaction.delete('unlocked_achievements');

      await transaction.delete('library_entries');
    });
  }
}
