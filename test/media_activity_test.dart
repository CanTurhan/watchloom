import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/entities/watch_activity_summary.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/presentation/library_share.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

void main() {
  EpisodeWatchLog log(int show, int episode, String date, int minutes) =>
      EpisodeWatchLog(
        showId: show,
        showName: 'Title',
        episodeId: episode,
        season: 1,
        episodeNumber: 1,
        watchedAt: DateTime.parse(date),
        runtimeMinutes: minutes,
        source: WatchLogSource.manualWatch,
      );

  test(
    'daily monthly yearly totals use the same events with civil date boundaries',
    () {
      final logs = [
        log(1, 1, '2026-11-12T20:00:00Z', 45),
        log(1, 2, '2026-11-12T21:30:00Z', 30), // Next day in Turkey.
        log(
          TvShow.movieIdOffset + 1375666,
          1375666,
          '2026-10-05T10:00:00Z',
          148,
        ),
        log(1, 3, '2025-12-31T10:00:00Z', 20),
      ];
      WatchActivitySummary summary(DateTime start, DateTime end) =>
          WatchActivitySummary.fromLogs(
            episodeLogs: logs,
            month: start,
            asOf: DateTime.utc(2026, 12),
            toLocalDate: (value) => value.toUtc().add(const Duration(hours: 3)),
            rangeStart: start,
            rangeEnd: end,
          );
      final day = summary(DateTime(2026, 11, 12), DateTime(2026, 11, 13));
      final month = summary(DateTime(2026, 11), DateTime(2026, 12));
      final year = summary(DateTime(2026), DateTime(2027));
      expect(day.episodeCount, 1);
      expect(day.knownWatchMinutes, 45);
      expect(month.episodeCount, 2);
      expect(month.knownWatchMinutes, 75);
      expect(year.episodeCount, 2);
      expect(year.seriesCount, 1);
      expect(year.movieCount, 1);
      expect(year.knownWatchMinutes, 223);
      expect(year.activeDayCount, 3);
      expect(
        WatchStreaks.fromLogs(
          episodeLogs: logs,
          asOf: DateTime.utc(2026, 11, 13),
          toLocalDate: (value) => value.toUtc().add(const Duration(hours: 3)),
        ).currentDaily,
        2,
      );
    },
  );

  for (final language in ['en', 'tr']) {
    test(
      'sharing exports status and source without private notes ($language)',
      () {
        final entry = LibraryEntry(
          showId: 169,
          name: 'Breaking Bad',
          summary: '',
          genres: const [],
          status: LibraryStatus.watching,
          isFavorite: true,
          lastSeason: 2,
          lastEpisode: 3,
          personalNote: 'SECRET NOTE',
          tvMazeUrl: 'https://www.tvmaze.com/shows/169/breaking-bad',
          addedAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final text = libraryShareText(
          [entry],
          AppStrings(language),
          wishlist: false,
        );
        expect(text, contains('Breaking Bad'));
        expect(text, contains('S02 · E03'));
        expect(text, contains('https://www.tvmaze.com/shows/169/breaking-bad'));
        expect(text, isNot(contains('SECRET NOTE')));
      },
    );
  }
}
