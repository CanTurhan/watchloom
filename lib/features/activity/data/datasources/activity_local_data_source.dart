import 'package:sqflite/sqflite.dart';
import 'package:watchloom/core/database/watchloom_database.dart';

class ActivityLocalDataSource {
  const ActivityLocalDataSource(this._watchloomDatabase);

  final WatchloomDatabase _watchloomDatabase;

  Future<List<Map<String, Object?>>> getWatchLogs() async {
    final database = await _watchloomDatabase.database;

    return database.query('episode_watch_logs', orderBy: 'watched_at DESC');
  }

  Future<List<Map<String, Object?>>> getUnlockedAchievements() async {
    final database = await _watchloomDatabase.database;

    return database.query('unlocked_achievements', orderBy: 'unlocked_at DESC');
  }

  Future<bool> recordEpisode({
    required Map<String, Object?> log,
    required Map<String, Object?> updatedLibraryEntry,
  }) async {
    final database = await _watchloomDatabase.database;

    return database.transaction((transaction) async {
      final existing = await transaction.query(
        'episode_watch_logs',
        columns: ['id'],
        where: 'show_id = ? AND episode_id = ?',
        whereArgs: [log['show_id'], log['episode_id']],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return false;
      }

      await transaction.insert(
        'episode_watch_logs',
        log,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await transaction.insert(
        'library_entries',
        updatedLibraryEntry,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return true;
    });
  }

  Future<bool> unlockAchievement(Map<String, Object?> achievement) async {
    final database = await _watchloomDatabase.database;

    final id = await database.insert(
      'unlocked_achievements',
      achievement,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    return id != 0;
  }
}
