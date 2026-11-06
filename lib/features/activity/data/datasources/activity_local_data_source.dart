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
    final showId = log['show_id'];
    final episodeId = log['episode_id'];
    if (showId is! int ||
        showId <= 0 ||
        episodeId is! int ||
        episodeId <= 0 ||
        showId != updatedLibraryEntry['show_id'] ||
        log['source'] != 'manual_watch' ||
        updatedLibraryEntry['last_season'] != log['season'] ||
        updatedLibraryEntry['last_episode'] != log['episode_number'] ||
        updatedLibraryEntry['last_episode_id'] != episodeId) {
      return false;
    }
    final database = await _watchloomDatabase.database;

    final result = await database.transaction((transaction) async {
      final saved = await transaction.query(
        'library_entries',
        columns: [
          'show_id',
          'status',
          'last_season',
          'last_episode',
          'last_episode_id',
        ],
        where: 'show_id = ?',
        whereArgs: [updatedLibraryEntry['show_id']],
        limit: 1,
      );
      if (saved.isEmpty) return false;
      final entry = saved.single;
      // A network request may finish after the user manually changes progress.
      // Reject that stale request instead of moving progress backwards or
      // storing an incorrect state for undo. Notes/favorites do not interfere.
      if (entry['status'] != log['previous_status'] ||
          entry['last_season'] != log['previous_season'] ||
          entry['last_episode'] != log['previous_episode_number'] ||
          entry['last_episode_id'] != log['previous_episode_id']) {
        return false;
      }
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

      await transaction.insert('episode_watch_logs', {
        ...log,
        'runtime_minutes':
            log['runtime_minutes'] is int && (log['runtime_minutes'] as int) > 0
            ? log['runtime_minutes']
            : null,
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      final changed = await transaction.update(
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
      if (changed != 1) throw StateError('watch-progress-not-saved');

      return true;
    });
    if (result) _watchloomDatabase.didChange();
    return result;
  }

  Future<Map<String, Object?>?> undoLatestEpisode({
    required Map<String, Object?> currentLibraryEntry,
  }) async {
    final database = await _watchloomDatabase.database;

    final result = await database.transaction((transaction) async {
      final showId = currentLibraryEntry['show_id'];
      final saved = await transaction.query(
        'library_entries',
        columns: [
          'show_id',
          'status',
          'last_season',
          'last_episode',
          'last_episode_id',
        ],
        where: 'show_id = ?',
        whereArgs: [showId],
        limit: 1,
      );
      if (saved.isEmpty) return null;
      final entry = saved.single;

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

        restoredStatus = entry['status'] as String? ?? 'watching';
        restoredSeason = previousLog['season'] as int?;
        restoredEpisodeNumber = previousLog['episode_number'] as int?;
        restoredEpisodeId = previousLog['episode_id'] as int?;
      } else {
        restoredStatus = entry['status'] as String? ?? 'watching';
        restoredSeason = null;
        restoredEpisodeNumber = null;
        restoredEpisodeId = null;
      }

      final stillAtRecordedEpisode =
          entry['last_season'] == latest['season'] &&
          entry['last_episode'] == latest['episode_number'] &&
          (entry['last_episode_id'] == null ||
              entry['last_episode_id'] == latest['episode_id']);
      final statusAfterRecord = latest['previous_status'] == 'watchlist'
          ? 'watching'
          : latest['previous_status'];
      // Undo removes the watch event. Restore progress only while it still
      // points at that event, and preserve a later manual status selection.
      final shouldRestoreStatus =
          !hasStoredPreviousState || entry['status'] == statusAfterRecord;

      final removed = await transaction.delete(
        'episode_watch_logs',
        where: 'id = ?',
        whereArgs: [latest['id']],
      );
      if (removed != 1) throw StateError('watch-event-not-removed');

      if (stillAtRecordedEpisode) {
        final changed = await transaction.update(
          'library_entries',
          {
            'status': shouldRestoreStatus ? restoredStatus : entry['status'],
            'last_season': restoredSeason,
            'last_episode': restoredEpisodeNumber,
            'last_episode_id': restoredEpisodeId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'show_id = ?',
          whereArgs: [showId],
        );
        if (changed != 1) throw StateError('watch-progress-not-restored');
      }

      return latest;
    });
    if (result != null) _watchloomDatabase.didChange();
    return result;
  }

  Future<bool> unlockAchievement(Map<String, Object?> achievement) async {
    final database = await _watchloomDatabase.database;

    final id = await database.insert(
      'unlocked_achievements',
      achievement,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    _watchloomDatabase.didChange();
    return id != 0;
  }
}
