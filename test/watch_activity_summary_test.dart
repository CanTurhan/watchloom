import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/entities/watch_activity_summary.dart';

EpisodeWatchLog _log({
  int? id,
  int showId = 1,
  int episodeId = 1,
  int? minutes = 45,
  required String at,
}) => EpisodeWatchLog(
  id: id,
  showId: showId,
  showName: 'Series $showId',
  episodeId: episodeId,
  season: 1,
  episodeNumber: episodeId,
  runtimeMinutes: minutes,
  watchedAt: DateTime.parse(at),
  source: WatchLogSource.manualWatch,
);

DateTime _utcDate(DateTime instant) => instant.toUtc();

void main() {
  final november = DateTime(2026, 11);
  final asOf = DateTime.utc(2026, 11, 30, 23, 59, 59);
  WatchActivitySummary summarize(Iterable<EpisodeWatchLog> logs) =>
      WatchActivitySummary.fromLogs(
        episodeLogs: logs,
        month: november,
        asOf: asOf,
        toLocalDate: _utcDate,
      );

  test(
    'counts recorded episodes and distinct series, not library progress',
    () {
      final summary = summarize([
        _log(episodeId: 1, at: '2026-11-03T10:00:00Z'),
        _log(episodeId: 2, minutes: 25, at: '2026-11-03T20:00:00Z'),
        _log(showId: 2, episodeId: 3, at: '2026-11-04T10:00:00Z'),
        _log(episodeId: 4, at: '2026-10-31T10:00:00Z'),
      ]);
      expect(summary.episodeCount, 3);
      expect(summary.seriesCount, 2);
      expect(summary.showCount, 2);
      expect(summary.knownWatchMinutes, 115);
      expect(summary.activeDayCount, 2);
      expect(summary.logs.map((log) => log.episodeId), [3, 2, 1]);
    },
  );

  test(
    'duration components preserve total time and differ from active days',
    () {
      final summary = summarize([
        _log(minutes: 3064, at: '2026-11-03T10:00:00Z'),
      ]);
      expect(summary.duration.totalMinutes, 3064);
      expect(summary.duration.totalHours, 51);
      expect(summary.duration.days, 2);
      expect(summary.duration.hours, 3);
      expect(summary.duration.minutes, 4);
      expect(summary.activeDayCount, 1);
      expect(WatchDuration.fromMinutes(-12).totalMinutes, 0);
      expect(WatchDuration.fromMinutes(0).isZero, isTrue);
      expect(WatchDuration.fromMinutes(60).hours, 1);
      expect(WatchDuration.fromMinutes(1440).days, 1);
    },
  );

  test('unknown, zero and negative runtimes never invent or subtract time', () {
    final summary = summarize([
      _log(episodeId: 1, minutes: null, at: '2026-11-03T10:00:00Z'),
      _log(episodeId: 2, minutes: 0, at: '2026-11-03T11:00:00Z'),
      _log(episodeId: 3, minutes: -50, at: '2026-11-03T12:00:00Z'),
      _log(episodeId: 4, minutes: 24, at: '2026-11-03T13:00:00Z'),
    ]);
    expect(summary.episodeCount, 4);
    expect(summary.knownWatchMinutes, 24);
    expect(summary.unknownRuntimeCount, 3);
    expect(summary.hasIncompleteDuration, isTrue);
    expect(summary.logs[1].runtimeMinutes, -50);
    expect(summarize([]).hasIncompleteDuration, isFalse);
  });

  test('duplicate episode events count once across month boundaries', () {
    final logs = [
      _log(id: 3, episodeId: 1, minutes: 60, at: '2026-11-01T10:00:00Z'),
      _log(id: 1, episodeId: 1, minutes: 30, at: '2026-10-31T10:00:00Z'),
      _log(id: 2, episodeId: 2, minutes: 20, at: '2026-11-03T10:00:00Z'),
      _log(id: 4, episodeId: 2, minutes: 20, at: '2026-11-03T10:00:00Z'),
      // Episode IDs are scoped to their series for defensive deduplication.
      _log(id: 5, showId: 2, episodeId: 2, at: '2026-11-04T10:00:00Z'),
    ];
    final summary = summarize(logs);
    expect(summary.episodeCount, 2);
    expect(summary.knownWatchMinutes, 65);
    expect(summary.duplicateRecordCount, 2);
    expect(summary.logs.last.id, 2);
    final october = WatchActivitySummary.fromLogs(
      episodeLogs: logs,
      month: DateTime(2026, 10),
      asOf: asOf,
      toLocalDate: _utcDate,
    );
    expect(october.episodeCount, 1);
    expect(october.knownWatchMinutes, 30);
  });

  test('invalid and future records do not inflate any statistic', () {
    final summary = summarize([
      _log(episodeId: 1, at: '2026-11-01T10:00:00Z'),
      _log(episodeId: 2, at: '2026-12-01T10:00:00Z'),
      _log(showId: 0, episodeId: 3, at: '2026-11-02T10:00:00Z'),
      _log(episodeId: -1, at: '2026-11-02T10:00:00Z'),
    ]);
    expect(summary.episodeCount, 1);
    expect(summary.knownWatchMinutes, 45);
    expect(summary.futureRecordCount, 1);
    expect(summary.invalidRecordCount, 2);
  });

  test(
    'calendar month boundaries use the viewer timezone and include the year',
    () {
      final logs = [
        _log(episodeId: 1, at: '2025-12-31T23:30:00Z'),
        _log(episodeId: 2, at: '2026-01-31T23:30:00Z'),
        _log(episodeId: 3, at: '2026-12-31T23:30:00Z'),
      ];
      final summary = WatchActivitySummary.fromLogs(
        episodeLogs: logs,
        month: DateTime(2026, 1),
        asOf: DateTime.utc(2027, 1, 2),
        toLocalDate: (date) => date.toUtc().add(const Duration(hours: 2)),
      );
      expect(summary.episodeCount, 1);
      expect(summary.logs.single.episodeId, 1);
      expect(summary.year, 2026);
      expect(summary.month, 1);
    },
  );

  test('active days are local calendar dates across a UTC midnight', () {
    final summary = WatchActivitySummary.fromLogs(
      episodeLogs: [
        _log(episodeId: 1, at: '2026-11-01T22:30:00Z'),
        _log(episodeId: 2, at: '2026-11-02T01:30:00Z'),
        _log(episodeId: 3, at: '2026-11-02T22:30:00Z'),
      ],
      month: november,
      asOf: asOf,
      toLocalDate: (date) => date.toUtc().add(const Duration(hours: 3)),
    );
    expect(summary.episodeCount, 3);
    expect(summary.activeDayCount, 2);
  });

  test('read models are immutable and leave stored input unchanged', () {
    final logs = [
      _log(id: 1, at: '2026-11-01T10:00:00Z'),
      _log(id: 2, episodeId: 2, at: '2026-11-02T10:00:00Z'),
    ];
    final original = List<EpisodeWatchLog>.of(logs);
    final summary = summarize(logs);
    expect(logs, original);
    expect(() => summary.logs.clear(), throwsUnsupportedError);
    final history = WatchActivityHistory.fromLogs(
      episodeLogs: logs,
      asOf: asOf,
    );
    expect(() => history.episodeLogs.clear(), throwsUnsupportedError);
    expect(logs.length, 2);
  });

  group('calendar streaks', () {
    test('spring DST change keeps consecutive civil days consecutive', () {
      DateTime newYorkDate(DateTime instant) {
        final utc = instant.toUtc();
        final daylight = !utc.isBefore(DateTime.utc(2026, 3, 8, 7));
        return utc.subtract(Duration(hours: daylight ? 4 : 5));
      }

      final streaks = WatchStreaks.fromLogs(
        episodeLogs: [
          _log(episodeId: 1, at: '2026-03-07T15:00:00Z'),
          _log(episodeId: 2, at: '2026-03-08T15:00:00Z'),
          _log(episodeId: 3, at: '2026-03-09T15:00:00Z'),
        ],
        asOf: DateTime.utc(2026, 3, 9, 20),
        toLocalDate: newYorkDate,
      );
      expect(streaks.currentDaily, 3);
      expect(streaks.bestDaily, 3);
    });

    test(
      'fall DST, repeated dates and future events cannot break/inflate streak',
      () {
        DateTime newYorkDate(DateTime instant) {
          final utc = instant.toUtc();
          final standard = !utc.isBefore(DateTime.utc(2026, 11, 1, 6));
          return utc.subtract(Duration(hours: standard ? 5 : 4));
        }

        final streaks = WatchStreaks.fromLogs(
          episodeLogs: [
            _log(episodeId: 1, at: '2026-10-31T15:00:00Z'),
            _log(episodeId: 2, at: '2026-11-01T15:00:00Z'),
            _log(episodeId: 3, at: '2026-11-01T16:00:00Z'),
            _log(episodeId: 4, at: '2026-11-02T15:00:00Z'),
            _log(episodeId: 5, at: '2026-11-03T15:00:00Z'),
          ],
          asOf: DateTime.utc(2026, 11, 2, 20),
          toLocalDate: newYorkDate,
        );
        expect(streaks.currentDaily, 3);
        expect(streaks.bestDaily, 3);
        expect(streaks.currentMonthly, 2);
      },
    );

    test('yesterday remains current; a two-day gap resets current only', () {
      final logs = [
        _log(episodeId: 1, at: '2026-11-01T15:00:00Z'),
        _log(episodeId: 2, at: '2026-11-02T15:00:00Z'),
      ];
      final yesterday = WatchStreaks.fromLogs(
        episodeLogs: logs,
        asOf: DateTime.utc(2026, 11, 3, 20),
        toLocalDate: _utcDate,
      );
      final afterGap = WatchStreaks.fromLogs(
        episodeLogs: logs,
        asOf: DateTime.utc(2026, 11, 4, 20),
        toLocalDate: _utcDate,
      );
      expect(yesterday.currentDaily, 2);
      expect(afterGap.currentDaily, 0);
      expect(afterGap.bestDaily, 2);
    });

    test('monthly streak crosses December and handles a missed month', () {
      final logs = [
        _log(episodeId: 1, at: '2025-11-02T15:00:00Z'),
        _log(episodeId: 2, at: '2025-12-02T15:00:00Z'),
        _log(episodeId: 3, at: '2026-01-02T15:00:00Z'),
      ];
      WatchStreaks at(DateTime now) => WatchStreaks.fromLogs(
        episodeLogs: logs,
        asOf: now,
        toLocalDate: _utcDate,
      );
      expect(at(DateTime.utc(2026, 1, 20)).currentMonthly, 3);
      expect(at(DateTime.utc(2026, 2, 20)).currentMonthly, 3);
      expect(at(DateTime.utc(2026, 3, 1)).currentMonthly, 0);
      expect(at(DateTime.utc(2025, 11, 1)).bestDaily, 0);
    });
  });
}
