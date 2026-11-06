import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';

/// Converts an instant to the calendar date used by the viewer.
/// Production uses the device's local timezone; tests can supply a timezone.
typedef WatchDateConverter = DateTime Function(DateTime instant);

DateTime _deviceLocalDate(DateTime instant) => instant.toLocal();

/// Exact, nonnegative duration components. Active watch days are a different
/// metric and must not be inferred from this duration.
class WatchDuration {
  const WatchDuration._(this.totalMinutes);

  factory WatchDuration.fromMinutes(int value) =>
      WatchDuration._(value < 0 ? 0 : value);

  final int totalMinutes;
  int get totalHours => totalMinutes ~/ 60;
  int get days => totalMinutes ~/ (24 * 60);
  int get hours => (totalMinutes % (24 * 60)) ~/ 60;
  int get minutes => totalMinutes % 60;
  bool get isZero => totalMinutes == 0;
}

/// Canonical read model. It never changes or deletes the underlying history.
/// v6 records an episode once, so duplicate (show, episode) rows are not
/// rewatches. Keep the earliest valid event across the whole supplied history,
/// including duplicates that would otherwise be counted in different months.
class WatchActivityHistory {
  WatchActivityHistory._({
    required this.episodeLogs,
    required this.duplicateRecordCount,
    required this.futureRecordCount,
    required this.invalidRecordCount,
  });

  factory WatchActivityHistory.fromLogs({
    required Iterable<EpisodeWatchLog> episodeLogs,
    required DateTime asOf,
  }) {
    final episodes = <(int, int), EpisodeWatchLog>{};
    var duplicates = 0;
    var future = 0;
    var invalid = 0;
    for (final log in episodeLogs) {
      if (log.showId <= 0 ||
          log.episodeId <= 0 ||
          log.source != WatchLogSource.manualWatch) {
        invalid++;
        continue;
      }
      if (log.watchedAt.isAfter(asOf)) {
        future++;
        continue;
      }
      final key = (log.showId, log.episodeId);
      final previous = episodes[key];
      if (previous != null) {
        duplicates++;
        if (!log.watchedAt.isBefore(previous.watchedAt) &&
            !(log.watchedAt.isAtSameMomentAs(previous.watchedAt) &&
                (log.id ?? 0) < (previous.id ?? 0))) {
          continue;
        }
      }
      episodes[key] = log;
    }
    final sortedEpisodes = episodes.values.toList()
      ..sort((a, b) {
        final date = b.watchedAt.compareTo(a.watchedAt);
        return date != 0 ? date : (b.id ?? 0).compareTo(a.id ?? 0);
      });
    return WatchActivityHistory._(
      episodeLogs: List.unmodifiable(sortedEpisodes),
      duplicateRecordCount: duplicates,
      futureRecordCount: future,
      invalidRecordCount: invalid,
    );
  }

  final List<EpisodeWatchLog> episodeLogs;
  final int duplicateRecordCount;
  final int futureRecordCount;
  final int invalidRecordCount;
}

/// A single snapshot of a selected calendar month. A missing runtime contributes
/// no invented minutes and is exposed through [unknownRuntimeCount].
class WatchActivitySummary {
  const WatchActivitySummary._({
    required this.year,
    required this.month,
    required this.logs,
    required this.seriesCount,
    required this.knownWatchMinutes,
    required this.unknownRuntimeCount,
    required this.activeDayCount,
    required this.duplicateRecordCount,
    required this.futureRecordCount,
    required this.invalidRecordCount,
  });

  factory WatchActivitySummary.fromLogs({
    required Iterable<EpisodeWatchLog> episodeLogs,
    required DateTime month,
    DateTime? asOf,
    WatchDateConverter? toLocalDate,
  }) {
    final localDate = toLocalDate ?? _deviceLocalDate;
    final history = WatchActivityHistory.fromLogs(
      episodeLogs: episodeLogs,
      asOf: asOf ?? DateTime.now(),
    );
    bool inMonth(DateTime instant) {
      final date = localDate(instant);
      // The argument selects a year/month, rather than representing an instant.
      return date.year == month.year && date.month == month.month;
    }

    final selectedEpisodes = history.episodeLogs
        .where((log) => inMonth(log.watchedAt))
        .toList(growable: false);
    int knownMinutes(Iterable<int?> values) => values.fold(
      0,
      (total, runtime) =>
          total + (runtime != null && runtime > 0 ? runtime : 0),
    );
    int unknownCount(Iterable<int?> values) =>
        values.where((runtime) => runtime == null || runtime <= 0).length;
    final days = <int>{
      for (final log in selectedEpisodes)
        _civilDayOrdinal(localDate(log.watchedAt)),
    };
    return WatchActivitySummary._(
      year: month.year,
      month: month.month,
      logs: List.unmodifiable(selectedEpisodes),
      seriesCount: selectedEpisodes.map((log) => log.showId).toSet().length,
      knownWatchMinutes: knownMinutes(
        selectedEpisodes.map((log) => log.runtimeMinutes),
      ),
      unknownRuntimeCount: unknownCount(
        selectedEpisodes.map((log) => log.runtimeMinutes),
      ),
      activeDayCount: days.length,
      duplicateRecordCount: history.duplicateRecordCount,
      futureRecordCount: history.futureRecordCount,
      invalidRecordCount: history.invalidRecordCount,
    );
  }

  final int year;
  final int month;
  final List<EpisodeWatchLog> logs;

  int get episodeCount => logs.length;

  /// Distinct series with an actual episode event, not completed series.
  final int seriesCount;
  int get showCount => seriesCount;

  final int knownWatchMinutes;
  final int unknownRuntimeCount;
  bool get hasIncompleteDuration => unknownRuntimeCount > 0;
  WatchDuration get duration => WatchDuration.fromMinutes(knownWatchMinutes);
  final int activeDayCount;

  /// Data-quality counters apply to the supplied history, before month filtering.
  final int duplicateRecordCount;
  final int futureRecordCount;
  final int invalidRecordCount;
}

/// Daily/monthly streaks follow civil calendar dates, not 24-hour intervals.
/// This keeps adjacent days adjacent across daylight-saving transitions.
class WatchStreaks {
  const WatchStreaks({
    required this.currentDaily,
    required this.bestDaily,
    required this.currentMonthly,
  });

  factory WatchStreaks.fromLogs({
    required Iterable<EpisodeWatchLog> episodeLogs,
    DateTime? asOf,
    WatchDateConverter? toLocalDate,
  }) {
    final now = asOf ?? DateTime.now();
    final localDate = toLocalDate ?? _deviceLocalDate;
    final history = WatchActivityHistory.fromLogs(
      episodeLogs: episodeLogs,
      asOf: now,
    );
    final dates = history.episodeLogs.map((log) => localDate(log.watchedAt));
    final days = dates.map(_civilDayOrdinal).toSet().toList()..sort();
    final months =
        dates.map((date) => date.year * 12 + date.month).toSet().toList()
          ..sort();
    final today = localDate(now);
    int endingStreak(List<int> values, int current) {
      if (values.isEmpty) return 0;
      final gap = current - values.last;
      if (gap < 0 || gap > 1) return 0;
      var count = 1;
      for (var i = values.length - 2; i >= 0; i--) {
        if (values[i + 1] - values[i] != 1) break;
        count++;
      }
      return count;
    }

    var best = days.isEmpty ? 0 : 1;
    var current = best;
    for (var i = 1; i < days.length; i++) {
      current = days[i] - days[i - 1] == 1 ? current + 1 : 1;
      if (current > best) best = current;
    }
    return WatchStreaks(
      currentDaily: endingStreak(days, _civilDayOrdinal(today)),
      bestDaily: best,
      currentMonthly: endingStreak(months, today.year * 12 + today.month),
    );
  }

  final int currentDaily;
  final int bestDaily;
  final int currentMonthly;
}

int _civilDayOrdinal(DateTime localDate) =>
    DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
    ).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
