import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_recap_strings.dart';
import 'package:watchloom/core/localization/app_show_strings.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_policy.dart';
import 'package:watchloom/features/community/domain/community_watch_context.dart';
import 'package:watchloom/features/community/presentation/community_strings.dart';

void main() {
  test(
    'recap arrows preserve day selection and clamp leap and short months',
    () {
      expect(
        moveRecapPeriod(DateTime(2026, 1, 31), 1, 1),
        DateTime(2026, 2, 28),
      );
      expect(
        moveRecapPeriod(DateTime(2024, 2, 29), 2, 1),
        DateTime(2025, 2, 28),
      );
      expect(
        moveRecapPeriod(DateTime(2026, 11, 12), 1, -1),
        DateTime(2026, 10, 12),
      );
      expect(
        moveRecapPeriod(DateTime(2026, 12, 31), 0, 1),
        DateTime(2027, 1, 1),
      );
    },
  );
  LibraryEntry entry({
    bool movie = false,
    LibraryStatus status = LibraryStatus.watching,
    int? season,
    int? episode,
  }) => LibraryEntry(
    showId: 1,
    name: 'Friends',
    summary: '',
    genres: const [],
    status: status,
    isMovie: movie,
    lastSeason: season,
    lastEpisode: episode,
    addedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test(
    'viewing snapshot distinguishes progress, watched movies and not-started titles',
    () {
      final snapshot = watchContextForEntry(entry(season: 8, episode: 5));
      expect(snapshot.toMap(), {
        'status': 'watching',
        'season': 8,
        'episode': 5,
      });
      expect(watchContextForEntry(null).status, 'not_started');
      expect(
        watchContextForEntry(
          entry(movie: true, status: LibraryStatus.watchlist),
        ).status,
        'not_started',
      );
      expect(
        watchContextForEntry(
          entry(movie: true, status: LibraryStatus.completed),
        ).status,
        'watched',
      );
      expect(
        watchContextForEntry(entry(movie: true, season: 1, episode: 1)).season,
        isNull,
      );
      expect(
        watchContextForEntry(entry(status: LibraryStatus.completed)).status,
        'watched',
      );
      expect(CommunityWatchContext.fromMap(snapshot.toMap())?.episode, 5);
      expect(
        CommunityWatchContext.fromMap({
          'status': 'not_started',
          'season': 8,
          'episode': 5,
        }),
        isNull,
      );
      expect(CommunityWatchContext.fromMap(null), isNull);
    },
  );

  test(
    'movie keys cannot be used as series keys or as arbitrary manual IDs',
    () {
      CommunityPolicy.content(
        'imdb:movie:tt1375666',
        CommunityContentKind.movie,
      );
      expect(
        () => CommunityPolicy.content(
          'imdb:movie:tt1375666',
          CommunityContentKind.series,
        ),
        throwsA(isA<CommunityException>()),
      );
      expect(
        () => CommunityPolicy.content(
          'tvmaze:show:1',
          CommunityContentKind.movie,
        ),
        throwsA(isA<CommunityException>()),
      );
    },
  );

  for (final language in ['en', 'tr']) {
    final s = AppStrings(language);
    final c = CommunityStrings.forLanguage(language);
    test('viewing and media strings are type-aware in $language', () {
      expect(
        c.watchLabel(
          const CommunityWatchContext(
            status: 'watching',
            season: 8,
            episode: 5,
          ),
          false,
        ),
        language == 'tr' ? '8. sezon · 5. bölüm' : 'Season 8 · Episode 5',
      );
      expect(
        c.watchLabel(const CommunityWatchContext(status: 'not_started'), true),
        language == 'tr' ? 'Henüz izlenmedi' : 'Not watched yet',
      );
      expect(
        c.watchLabel(const CommunityWatchContext(status: 'watched'), true),
        language == 'tr' ? 'İzlendi' : 'Watched',
      );
      expect(
        s.noSummaryFor(true),
        language == 'tr'
            ? 'Bu film için özet bulunmuyor.'
            : 'No summary is available for this movie.',
      );
      expect(
        s.noSummaryFor(false),
        language == 'tr'
            ? 'Bu dizi için özet bulunmuyor.'
            : 'No summary is available for this series.',
      );
      expect(
        s.searchTitleFor(true),
        language == 'tr' ? 'Film Ara' : 'Search Movies',
      );
      expect(s.myMonth, language == 'tr' ? 'Özet' : 'Recap');
    });
    test(
      'recap labels follow selected civil date across month and year boundaries ($language)',
      () {
        final now = DateTime(2026, 12, 31, 23);
        expect(
          s.recapPeriodLabel(DateTime(2026, 12, 31), 0, now),
          language == 'tr' ? 'Bugün' : 'Today',
        );
        expect(
          s.recapPeriodLabel(DateTime(2026, 12, 30), 0, now),
          language == 'tr' ? 'Dün' : 'Yesterday',
        );
        expect(
          s.recapPeriodLabel(DateTime(2027, 1, 1), 0, now),
          language == 'tr' ? 'Yarın' : 'Tomorrow',
        );
        expect(
          s.recapPeriodLabel(DateTime(2026, 12), 1, now),
          language == 'tr' ? 'Bu ay' : 'This month',
        );
        expect(
          s.recapPeriodLabel(DateTime(2026, 11), 1, now),
          language == 'tr' ? 'Kasım ayı' : 'November',
        );
        expect(s.recapPeriodLabel(DateTime(2027), 2, now), '2027');
        expect(
          s.recapPeriodLabel(DateTime(2027, 3), 1, now),
          language == 'tr' ? 'Mart 2027' : 'March 2027',
        );
        expect(
          s.recapPeriodLabel(DateTime(2027, 1, 2), 0, now),
          contains('2027'),
        );
      },
    );
  }
}
