import 'package:watchloom/features/activity/data/datasources/activity_local_data_source.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/repositories/activity_repository.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

class SqliteActivityRepository implements ActivityRepository {
  const SqliteActivityRepository(this._localDataSource);

  final ActivityLocalDataSource _localDataSource;

  @override
  Future<List<EpisodeWatchLog>> getWatchLogs() async {
    final rows = await _localDataSource.getWatchLogs();

    return rows.map(EpisodeWatchLog.fromMap).toList(growable: false);
  }

  @override
  Future<List<UnlockedAchievement>> getUnlockedAchievements() async {
    final rows = await _localDataSource.getUnlockedAchievements();

    return rows.map(UnlockedAchievement.fromMap).toList(growable: false);
  }

  @override
  Future<bool> recordEpisode({
    required EpisodeWatchLog log,
    required LibraryEntry updatedLibraryEntry,
  }) {
    return _localDataSource.recordEpisode(
      log: log.toMap(),
      updatedLibraryEntry: updatedLibraryEntry.toMap(),
    );
  }

  @override
  Future<EpisodeWatchLog?> undoLatestEpisode({
    required LibraryEntry currentLibraryEntry,
  }) async {
    final row = await _localDataSource.undoLatestEpisode(
      currentLibraryEntry: currentLibraryEntry.toMap(),
    );

    if (row == null) {
      return null;
    }

    return EpisodeWatchLog.fromMap(row);
  }

  @override
  Future<bool> unlockAchievement(UnlockedAchievement achievement) {
    return _localDataSource.unlockAchievement(achievement.toMap());
  }
}
