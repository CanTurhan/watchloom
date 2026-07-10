import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

abstract interface class ActivityRepository {
  Future<List<EpisodeWatchLog>> getWatchLogs();

  Future<List<UnlockedAchievement>> getUnlockedAchievements();

  Future<bool> recordEpisode({
    required EpisodeWatchLog log,
    required LibraryEntry updatedLibraryEntry,
  });

  Future<EpisodeWatchLog?> undoLatestEpisode({
    required LibraryEntry currentLibraryEntry,
  });

  Future<bool> unlockAchievement(UnlockedAchievement achievement);
}
