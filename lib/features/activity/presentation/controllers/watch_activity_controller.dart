import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/repositories/activity_repository.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';

enum MarkNextEpisodeStatus {
  success,
  noAvailableEpisode,
  alreadyRecorded,
  failed,
}

enum UndoLatestEpisodeStatus {
  success,
  nothingToUndo,
  libraryEntryMissing,
  failed,
}

class MarkNextEpisodeResult {
  const MarkNextEpisodeResult({required this.status, this.episode});

  final MarkNextEpisodeStatus status;
  final TvEpisode? episode;
}

class UndoLatestEpisodeResult {
  const UndoLatestEpisodeResult({required this.status, this.log});

  final UndoLatestEpisodeStatus status;
  final EpisodeWatchLog? log;
}

class WatchActivityController extends ChangeNotifier {
  factory WatchActivityController({
    required ActivityRepository repository,
    required LibraryController libraryController,
    required ShowRepository showRepository,
  }) {
    return WatchActivityController._(
      repository,
      libraryController,
      showRepository,
    );
  }

  WatchActivityController._(
    this._repository,
    this._libraryController,
    this._showRepository,
  );

  final ActivityRepository _repository;
  final LibraryController _libraryController;
  final ShowRepository _showRepository;

  List<EpisodeWatchLog> _logs = const [];
  List<UnlockedAchievement> _unlockedAchievements = const [];

  final Set<int> _processingShowIds = {};

  bool _isLoading = false;
  bool _isUndoing = false;
  Object? _error;

  UnmodifiableListView<EpisodeWatchLog> get logs {
    return UnmodifiableListView(_logs);
  }

  UnmodifiableListView<UnlockedAchievement> get unlockedAchievements {
    return UnmodifiableListView(_unlockedAchievements);
  }

  bool get isLoading => _isLoading;
  bool get isUndoing => _isUndoing;
  Object? get error => _error;

  int get totalEpisodes => _logs.length;

  bool get canUndoLatest {
    if (_logs.isEmpty || _isUndoing) {
      return false;
    }

    return _libraryController.findByShowId(_logs.first.showId) != null;
  }

  int get monthEpisodeCount {
    return logsForMonth(DateTime.now()).length;
  }

  int get monthShowCount {
    return logsForMonth(DateTime.now()).map((log) => log.showId).toSet().length;
  }

  int get monthWatchMinutes {
    return logsForMonth(
      DateTime.now(),
    ).fold(0, (total, log) => total + (log.runtimeMinutes ?? 0));
  }

  int get currentDailyStreak {
    return _calculateCurrentDailyStreak(_logs);
  }

  int get bestDailyStreak {
    return _calculateBestDailyStreak(_logs);
  }

  int get currentMonthlyStreak {
    return _calculateCurrentMonthlyStreak(_logs);
  }

  List<UnlockedAchievement> get achievementsUnlockedThisMonth {
    final now = DateTime.now();

    return _unlockedAchievements
        .where((achievement) {
          final date = achievement.unlockedAt.toLocal();

          return date.year == now.year && date.month == now.month;
        })
        .toList(growable: false);
  }

  bool isProcessing(int showId) {
    return _processingShowIds.contains(showId);
  }

  bool isAchievementUnlocked(String code) {
    return _unlockedAchievements.any((achievement) => achievement.code == code);
  }

  List<EpisodeWatchLog> logsForMonth(DateTime month) {
    return _logs
        .where((log) {
          final date = log.watchedAt.toLocal();

          return date.year == month.year && date.month == month.month;
        })
        .toList(growable: false);
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logs = await _repository.getWatchLogs();

      _unlockedAchievements = await _repository.getUnlockedAchievements();

      final unlockedNew = await _unlockEligibleAchievements();

      if (unlockedNew) {
        _unlockedAchievements = await _repository.getUnlockedAchievements();
      }
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MarkNextEpisodeResult> markNextEpisode(LibraryEntry entry) async {
    if (_processingShowIds.contains(entry.showId)) {
      return const MarkNextEpisodeResult(status: MarkNextEpisodeStatus.failed);
    }

    _processingShowIds.add(entry.showId);
    notifyListeners();

    try {
      final allEpisodes = await _showRepository.getEpisodes(entry.showId);

      final episodes = allEpisodes
          .where((episode) => episode.season != null && episode.number != null)
          .toList();

      episodes.sort((first, second) {
        final seasonComparison = first.season!.compareTo(second.season!);

        if (seasonComparison != 0) {
          return seasonComparison;
        }

        return first.number!.compareTo(second.number!);
      });

      final nextEpisode = _findNextEpisode(entry, episodes);

      if (nextEpisode == null || _isFutureEpisode(nextEpisode)) {
        return const MarkNextEpisodeResult(
          status: MarkNextEpisodeStatus.noAvailableEpisode,
        );
      }

      final now = DateTime.now();

      final updatedEntry = entry.copyWith(
        status: entry.status == LibraryStatus.watchlist
            ? LibraryStatus.watching
            : entry.status,
        lastSeason: nextEpisode.season,
        lastEpisode: nextEpisode.number,
        lastEpisodeId: nextEpisode.id,
        updatedAt: now,
      );

      final inserted = await _repository.recordEpisode(
        log: EpisodeWatchLog(
          showId: entry.showId,
          showName: entry.name,
          episodeId: nextEpisode.id,
          season: nextEpisode.season!,
          episodeNumber: nextEpisode.number!,
          runtimeMinutes: nextEpisode.runtime,
          watchedAt: now,
          source: WatchLogSource.manualWatch,
          previousStatus: entry.status,
          previousSeason: entry.lastSeason,
          previousEpisodeNumber: entry.lastEpisode,
          previousEpisodeId: entry.lastEpisodeId,
        ),
        updatedLibraryEntry: updatedEntry,
      );

      if (!inserted) {
        return MarkNextEpisodeResult(
          status: MarkNextEpisodeStatus.alreadyRecorded,
          episode: nextEpisode,
        );
      }

      await _libraryController.load();
      await load();

      return MarkNextEpisodeResult(
        status: MarkNextEpisodeStatus.success,
        episode: nextEpisode,
      );
    } catch (_) {
      return const MarkNextEpisodeResult(status: MarkNextEpisodeStatus.failed);
    } finally {
      _processingShowIds.remove(entry.showId);
      notifyListeners();
    }
  }

  Future<UndoLatestEpisodeResult> undoLastEpisode() async {
    if (_isUndoing) {
      return const UndoLatestEpisodeResult(
        status: UndoLatestEpisodeStatus.failed,
      );
    }

    if (_logs.isEmpty) {
      return const UndoLatestEpisodeResult(
        status: UndoLatestEpisodeStatus.nothingToUndo,
      );
    }

    final latestLog = _logs.first;

    final currentEntry = _libraryController.findByShowId(latestLog.showId);

    if (currentEntry == null) {
      return const UndoLatestEpisodeResult(
        status: UndoLatestEpisodeStatus.libraryEntryMissing,
      );
    }

    _isUndoing = true;
    notifyListeners();

    try {
      final removedLog = await _repository.undoLatestEpisode(
        currentLibraryEntry: currentEntry,
      );

      if (removedLog == null) {
        return const UndoLatestEpisodeResult(
          status: UndoLatestEpisodeStatus.nothingToUndo,
        );
      }

      await _libraryController.load();
      await load();

      return UndoLatestEpisodeResult(
        status: UndoLatestEpisodeStatus.success,
        log: removedLog,
      );
    } catch (_) {
      return const UndoLatestEpisodeResult(
        status: UndoLatestEpisodeStatus.failed,
      );
    } finally {
      _isUndoing = false;
      notifyListeners();
    }
  }

  TvEpisode? _findNextEpisode(LibraryEntry entry, List<TvEpisode> episodes) {
    if (episodes.isEmpty) {
      return null;
    }

    if (!entry.hasProgress) {
      return episodes.first;
    }

    var currentIndex = -1;

    if (entry.lastEpisodeId != null) {
      currentIndex = episodes.indexWhere(
        (episode) => episode.id == entry.lastEpisodeId,
      );
    }

    if (currentIndex < 0) {
      currentIndex = episodes.indexWhere(
        (episode) =>
            episode.season == entry.lastSeason &&
            episode.number == entry.lastEpisode,
      );
    }

    if (currentIndex < 0) {
      return episodes.first;
    }

    final nextIndex = currentIndex + 1;

    if (nextIndex >= episodes.length) {
      return null;
    }

    return episodes[nextIndex];
  }

  bool _isFutureEpisode(TvEpisode episode) {
    final parsedDate = DateTime.tryParse(episode.airDate ?? '');

    if (parsedDate == null) {
      return false;
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final airDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    return airDate.isAfter(today);
  }

  Future<bool> _unlockEligibleAchievements() async {
    final eligibleCodes = <String>{
      if (totalEpisodes >= 1) AchievementCatalog.firstEpisode,
      if (totalEpisodes >= 10) AchievementCatalog.tenEpisodes,
      if (totalEpisodes >= 50) AchievementCatalog.fiftyEpisodes,
      if (totalEpisodes >= 100) AchievementCatalog.hundredEpisodes,
      if (bestDailyStreak >= 3) AchievementCatalog.threeDayStreak,
      if (bestDailyStreak >= 7) AchievementCatalog.sevenDayStreak,
      if (bestDailyStreak >= 14) AchievementCatalog.fourteenDayStreak,
      if (currentMonthlyStreak >= 3) AchievementCatalog.threeMonthStreak,
      if (currentMonthlyStreak >= 6) AchievementCatalog.sixMonthStreak,
      if (currentMonthlyStreak >= 12) AchievementCatalog.twelveMonthStreak,
    };

    final unlockedCodes = _unlockedAchievements
        .map((achievement) => achievement.code)
        .toSet();

    var unlockedAny = false;

    for (final code in eligibleCodes.difference(unlockedCodes)) {
      final inserted = await _repository.unlockAchievement(
        UnlockedAchievement(code: code, unlockedAt: DateTime.now()),
      );

      unlockedAny = unlockedAny || inserted;
    }

    return unlockedAny;
  }

  int _calculateCurrentDailyStreak(List<EpisodeWatchLog> logs) {
    final days = _uniqueWatchDays(logs);

    if (days.isEmpty) {
      return 0;
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final latest = days.last;

    final daysSinceLatest = today.difference(latest).inDays;

    if (daysSinceLatest > 1) {
      return 0;
    }

    var streak = 1;
    var cursor = latest;

    for (var index = days.length - 2; index >= 0; index--) {
      final difference = cursor.difference(days[index]).inDays;

      if (difference != 1) {
        break;
      }

      streak++;
      cursor = days[index];
    }

    return streak;
  }

  int _calculateBestDailyStreak(List<EpisodeWatchLog> logs) {
    final days = _uniqueWatchDays(logs);

    if (days.isEmpty) {
      return 0;
    }

    var best = 1;
    var current = 1;

    for (var index = 1; index < days.length; index++) {
      final difference = days[index].difference(days[index - 1]).inDays;

      if (difference == 1) {
        current++;
        best = current > best ? current : best;
      } else {
        current = 1;
      }
    }

    return best;
  }

  int _calculateCurrentMonthlyStreak(List<EpisodeWatchLog> logs) {
    final months =
        logs
            .map((log) {
              final date = log.watchedAt.toLocal();

              return date.year * 12 + date.month;
            })
            .toSet()
            .toList()
          ..sort();

    if (months.isEmpty) {
      return 0;
    }

    final now = DateTime.now();

    final currentMonth = now.year * 12 + now.month;

    final latestMonth = months.last;

    if (currentMonth - latestMonth > 1) {
      return 0;
    }

    var streak = 1;
    var cursor = latestMonth;

    for (var index = months.length - 2; index >= 0; index--) {
      if (months[index] != cursor - 1) {
        break;
      }

      streak++;
      cursor = months[index];
    }

    return streak;
  }

  List<DateTime> _uniqueWatchDays(List<EpisodeWatchLog> logs) {
    final days =
        logs
            .map((log) {
              final date = log.watchedAt.toLocal();

              return DateTime(date.year, date.month, date.day);
            })
            .toSet()
            .toList()
          ..sort();

    return days;
  }
}
