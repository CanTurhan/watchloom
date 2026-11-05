import 'package:sqflite/sqflite.dart';
import 'package:watchloom/core/database/watchloom_database.dart';

class ActivityLocalDataSource {
  const ActivityLocalDataSource(this._watchloomDatabase);

  final WatchloomDatabase _watchloomDatabase;

  Future<List<Map<String, Object?>>> getWatchLogs() async {
    final database = await _watchloomDatabase.database;

    return database.query(
      'episode_watch_logs',
      where: 'source = ?',
      whereArgs: ['manual_watch'],
      orderBy: 'watched_at DESC, id DESC',
    );
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
      final saved = await transaction.query(
        'library_entries',
        columns: ['show_id'],
        where: 'show_id = ?',
        whereArgs: [updatedLibraryEntry['show_id']],
        limit: 1,
      );
      if (saved.isEmpty) return false;
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

      await transaction.update(
        'library_entries',
        {
          for (final key in [
            'status',
            'last_season',
            'last_episode',
            'last_episode_id',
            'updated_at',
          ])
            key: updatedLibraryEntry[key],
        },
        where: 'show_id = ?',
        whereArgs: [updatedLibraryEntry['show_id']],
      );

      return true;
    });
  }

  Future<Map<String, Object?>?> undoLatestEpisode({
    required Map<String, Object?> currentLibraryEntry,
  }) async {
    final database = await _watchloomDatabase.database;

    return database.transaction((transaction) async {
      final showId = currentLibraryEntry['show_id'];
      final saved = await transaction.query(
        'library_entries',
        columns: ['show_id'],
        where: 'show_id = ?',
        whereArgs: [showId],
        limit: 1,
      );
      if (saved.isEmpty) return null;

      final logs = await transaction.query(
        'episode_watch_logs',
        where: 'show_id = ? AND source = ?',
        whereArgs: [showId, 'manual_watch'],
        orderBy: 'watched_at DESC, id DESC',
        limit: 2,
      );

      if (logs.isEmpty) {
        return null;
      }

      final latest = Map<String, Object?>.from(logs.first);

      final hasStoredPreviousState = latest['previous_status'] != null;

      String restoredStatus;
      int? restoredSeason;
      int? restoredEpisodeNumber;
      int? restoredEpisodeId;

      if (hasStoredPreviousState) {
        restoredStatus = latest['previous_status'] as String;
        restoredSeason = latest['previous_season'] as int?;
        restoredEpisodeNumber = latest['previous_episode_number'] as int?;
        restoredEpisodeId = latest['previous_episode_id'] as int?;
      } else if (logs.length > 1) {
        final previousLog = logs[1];

        restoredStatus = currentLibraryEntry['status'] as String? ?? 'watching';
        restoredSeason = previousLog['season'] as int?;
        restoredEpisodeNumber = previousLog['episode_number'] as int?;
        restoredEpisodeId = previousLog['episode_id'] as int?;
      } else {
        restoredStatus = currentLibraryEntry['status'] as String? ?? 'watching';
        restoredSeason = null;
        restoredEpisodeNumber = null;
        restoredEpisodeId = null;
      }

      final updatedEntry = Map<String, Object?>.from(currentLibraryEntry)
        ..['status'] = restoredStatus
        ..['last_season'] = restoredSeason
        ..['last_episode'] = restoredEpisodeNumber
        ..['last_episode_id'] = restoredEpisodeId
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await transaction.delete(
        'episode_watch_logs',
        where: 'id = ?',
        whereArgs: [latest['id']],
      );

      await transaction.update(
        'library_entries',
        {
          for (final key in [
            'status',
            'last_season',
            'last_episode',
            'last_episode_id',
            'updated_at',
          ])
            key: updatedEntry[key],
        },
        where: 'show_id = ?',
        whereArgs: [showId],
      );

      return latest;
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
