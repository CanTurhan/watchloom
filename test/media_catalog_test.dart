import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/features/shows/data/repositories/media_catalog_repository.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';
import 'package:watchloom/features/shows/presentation/widgets/trailer_button.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/account/data/library_backup.dart';

class _Series implements ShowRepository {
  @override
  Future<TvShow> getShow(int id) async => TvShow(
    id: id,
    name: 'Series',
    summary: 'Keep summary',
    genres: const ['Drama'],
    imdbId: 'tt0903747',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final rating in ['PG-13', 'R', 'unknown']) {
    testWidgets('trailer requires consent before opening $rating', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrailerButton(
              url: 'https://www.youtube.com/watch?v=cdx31ak4KbQ',
              rating: rating,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(
          rating == 'PG-13'
              ? '13+'
              : rating == 'R'
              ? '18+'
              : 'Age rating unavailable',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  const movie = <String, dynamic>{
    'id': 'tt1375666',
    'type': 'movie',
    'name': 'Inception',
    'description': 'A dream',
    'runtime': '148 min',
    'released': '2010-07-16',
    'genres': ['Sci-Fi'],
    'imdbRating': '8.8',
    'trailers': [
      {'type': 'Trailer', 'source': 'cdx31ak4KbQ'},
    ],
  };

  test(
    'movie catalog uses disjoint IDs, real runtime and exact trailer ID',
    () {
      final result = MediaCatalogRepository.movieFromJson(movie);
      expect(result.id, TvShow.movieIdOffset + 1375666);
      expect(result.isMovie, isTrue);
      expect(result.runtime, 148);
      expect(result.trailerUrl, 'https://www.youtube.com/watch?v=cdx31ak4KbQ');
      expect(result.contentRating, isNull);
      expect(result.ratingAverage, 8.8);
      expect(
        MediaCatalogRepository.trailerFromJson({
          'trailers': [
            {'type': 'Trailer', 'source': 'https://evil.example'},
          ],
        }),
        isNull,
      );
    },
  );

  test('search results never act as complete cached details', () async {
    final paths = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          paths.add(request.path);
          handler.resolve(
            Response(
              requestOptions: request,
              data: request.path.contains('/catalog/')
                  ? {
                      'metas': [
                        {
                          'id': 'tt1375666',
                          'type': 'movie',
                          'name': 'Inception',
                        },
                      ],
                    }
                  : {'meta': movie},
            ),
          );
        },
      ),
    );
    final catalog = MediaCatalogRepository(_Series(), movieClient: dio);
    final results = await catalog.searchMovies('Inception');
    expect(results.single.runtime, isNull);
    final episodes = await catalog.getEpisodes(results.single.id);
    expect(episodes.single.runtime, 148);
    expect(paths.last, '/meta/movie/tt1375666.json');
  });

  test('series trailer outage preserves existing TVMaze details', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            ),
          );
        },
      ),
    );
    final catalog = MediaCatalogRepository(_Series(), movieClient: dio);
    final show = await catalog.getShow(169);
    expect(show.id, 169);
    expect(show.summary, 'Keep summary');
    expect(show.trailerUrl, isNull);
  });

  test('series trailer matching uses exact IMDb identity', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'meta': {
                  ...movie,
                  'id': 'tt0903747',
                  'type': 'series',
                  'contentRating': 'TV-MA',
                },
              },
            ),
          );
        },
      ),
    );
    final show = await MediaCatalogRepository(
      _Series(),
      movieClient: dio,
    ).getShow(169);
    expect(show.id, 169);
    expect(show.summary, 'Keep summary');
    expect(show.trailerUrl, isNotNull);
    expect(show.contentRating, 'TV-MA');
  });

  test('age gate preserves restrictions and unknown does not mean safe', () {
    expect(trailerAge('PG-13'), 13);
    expect(trailerAge('R'), 18);
    expect(trailerAge('TV-MA'), 18);
    expect(trailerAge('16+'), 16);
    expect(trailerAge('G'), 0);
    expect(trailerAge(null), isNull);
    expect(trailerAge('unrated'), isNull);
  });

  test('movie fields survive backups and old series remain series', () {
    final entry = LibraryEntry(
      showId: TvShow.movieIdOffset + 1375666,
      name: 'Inception',
      summary: '',
      genres: const [],
      status: LibraryStatus.completed,
      isMovie: true,
      runtime: 148,
      trailerUrl: 'https://www.youtube.com/watch?v=cdx31ak4KbQ',
      contentRating: 'PG-13',
      isFavorite: true,
      personalNote: 'Private',
      addedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final decoded = LibraryBackup.decode(
      LibraryBackup(
        entries: [entry.toMap()],
        logs: [],
        achievements: [],
      ).encode(),
    );
    final restored = LibraryEntry.fromMap(decoded.entries.single);
    expect(restored.isMovie, isTrue);
    expect(restored.runtime, 148);
    expect(restored.toTvShow().trailerUrl, entry.trailerUrl);
    expect(restored.copyWith(isFavorite: false).isMovie, isTrue);
    final legacy = entry.toMap()
      ..remove('media_type')
      ..remove('runtime_minutes')
      ..remove('trailer_url')
      ..remove('content_rating');
    expect(LibraryEntry.fromMap(legacy).isMovie, isFalse);
  });
}
