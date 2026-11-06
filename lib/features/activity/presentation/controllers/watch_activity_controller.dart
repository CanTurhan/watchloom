import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/entities/watch_activity_summary.dart';
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
    DateTime Function()? now,
    WatchDateConverter? toLocalDate,
  }) {
    return WatchActivityController._(
      repository,
      libraryController,
      showRepository,
      now ?? DateTime.now,
      toLocalDate ?? (instant) => instant.toLocal(),
    );
  }

  WatchActivityController._(
    this._repository,
    this._libraryController,
    this._showRepository,
    this._now,
    this._toLocalDate,
  );

  final ActivityRepository _repository;
  final LibraryController _libraryController;
  final ShowRepository _showRepository;
  final DateTime Function() _now;
  final WatchDateConverter _toLocalDate;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

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

  int get totalEpisodes => WatchActivityHistory.fromLogs(
    episodeLogs: _logs,
    asOf: _now(),
  ).episodeLogs.length;

  WatchActivitySummary get currentMonthSummary {
    final now = _now();
    return summaryForMonth(_toLocalDate(now), asOf: now);
  }

  WatchActivitySummary summaryForMonth(DateTime month, {DateTime? asOf}) {
    return WatchActivitySummary.fromLogs(
      episodeLogs: _logs,
      month: month,
      asOf: asOf ?? _now(),
      toLocalDate: _toLocalDate,
    );
  }

  WatchStreaks get streaks => WatchStreaks.fromLogs(
    episodeLogs: _logs,
    asOf: _now(),
    toLocalDate: _toLocalDate,
  );

  bool get canUndoLatest {
    if (_logs.isEmpty || _isUndoing) {
      return false;
    }

    return _libraryController.findByShowId(_logs.first.showId) != null;
  }

  int get monthEpisodeCount => currentMonthSummary.episodeCount;

  int get monthShowCount => currentMonthSummary.seriesCount;

  int get monthWatchMinutes => currentMonthSummary.knownWatchMinutes;

  int get currentDailyStreak => streaks.currentDaily;

  int get bestDailyStreak => streaks.bestDaily;

  int get currentMonthlyStreak => streaks.currentMonthly;

  List<UnlockedAchievement> get achievementsUnlockedThisMonth {
    final now = _now();
    final localNow = _toLocalDate(now);

    return _unlockedAchievements
        .where((achievement) {
          if (achievement.unlockedAt.isAfter(now)) return false;
          final date = _toLocalDate(achievement.unlockedAt);

          return date.year == localNow.year && date.month == localNow.month;
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
    return summaryForMonth(month).logs;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Preserve every stored row for undo; statistics use a separate,
      // canonical read model. The repository's order is not part of its API.
      _logs = List.of(await _repository.getWatchLogs())
        ..sort((a, b) {
          final date = b.watchedAt.compareTo(a.watchedAt);
          return date != 0 ? date : (b.id ?? 0).compareTo(a.id ?? 0);
        });

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

      final now = _now();

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
          runtimeMinutes:
              nextEpisode.runtime != null && nextEpisode.runtime! > 0
              ? nextEpisode.runtime
              : null,
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
        // A duplicate or a progress change while fetching episodes can reject
        // this write. Refresh both views and only label a real event duplicate.
        await _libraryController.load();
        await load();
        final alreadyRecorded = _logs.any(
          (log) =>
              log.showId == entry.showId && log.episodeId == nextEpisode.id,
        );
        return MarkNextEpisodeResult(
          status: alreadyRecorded
              ? MarkNextEpisodeStatus.alreadyRecorded
              : MarkNextEpisodeStatus.failed,
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

    final now = _toLocalDate(_now());

    final today = DateTime(now.year, now.month, now.day);

    final airDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    return airDate.isAfter(today);
  }

  Future<bool> _unlockEligibleAchievements() async {
    final now = _now();
    final total = WatchActivityHistory.fromLogs(
      episodeLogs: _logs,
      asOf: now,
    ).episodeLogs.length;
    final currentStreaks = WatchStreaks.fromLogs(
      episodeLogs: _logs,
      asOf: now,
      toLocalDate: _toLocalDate,
    );
    final eligibleCodes = <String>{
      if (total >= 1) AchievementCatalog.firstEpisode,
      if (total >= 10) AchievementCatalog.tenEpisodes,
      if (total >= 50) AchievementCatalog.fiftyEpisodes,
      if (total >= 100) AchievementCatalog.hundredEpisodes,
      if (currentStreaks.bestDaily >= 3) AchievementCatalog.threeDayStreak,
      if (currentStreaks.bestDaily >= 7) AchievementCatalog.sevenDayStreak,
      if (currentStreaks.bestDaily >= 14) AchievementCatalog.fourteenDayStreak,
      if (currentStreaks.currentMonthly >= 3)
        AchievementCatalog.threeMonthStreak,
      if (currentStreaks.currentMonthly >= 6) AchievementCatalog.sixMonthStreak,
      if (currentStreaks.currentMonthly >= 12)
        AchievementCatalog.twelveMonthStreak,
    };

    final unlockedCodes = _unlockedAchievements
        .map((achievement) => achievement.code)
        .toSet();

    var unlockedAny = false;

    for (final code in eligibleCodes.difference(unlockedCodes)) {
      final inserted = await _repository.unlockAchievement(
        UnlockedAchievement(code: code, unlockedAt: now),
      );

      unlockedAny = unlockedAny || inserted;
    }

    return unlockedAny;
  }
}
