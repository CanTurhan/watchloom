import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';

/// Metadata and trailer references only; no streaming resources.
/// Existing TVMaze IDs remain unchanged; IMDb movie IDs have their own range.
class MediaCatalogRepository implements ShowRepository {
  MediaCatalogRepository(this.series, {Dio? movieClient})
    : _catalog =
          movieClient ??
          Dio(
            BaseOptions(
              baseUrl: 'https://v3-cinemeta.strem.io',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
  final ShowRepository series;
  final Dio _catalog;

  Future<Map<String, dynamic>> _request(String path) async {
    try {
      final response = await _catalog.get<Object?>(path);
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data is! Map) throw const FormatException('invalid-catalog-response');
      return Map<String, dynamic>.from(data);
    } on DioException catch (error) {
      throw ShowFailure(
        error.response?.statusCode == 429
            ? ShowFailureType.rateLimited
            : ShowFailureType.network,
      );
    } on FormatException {
      throw const ShowFailure(ShowFailureType.invalidResponse);
    }
  }

  Future<List<TvShow>> searchMovies(String query) async {
    if (query.trim().length < 2) return const [];
    final data = await _request(
      '/catalog/movie/top/search=${Uri.encodeComponent(query.trim())}.json',
    );
    if (data['metas'] is! List) {
      throw const ShowFailure(ShowFailureType.invalidResponse);
    }
    final results = <TvShow>[];
    for (final row in (data['metas'] as List).whereType<Map>()) {
      if (row['type'] != 'movie') continue;
      try {
        results.add(movieFromJson(Map<String, dynamic>.from(row)));
      } on FormatException {
        /* Ignore malformed individual search results. */
      }
    }
    return results;
  }

  static String? trailerFromJson(Map<String, dynamic> row) {
    final trailers = row['trailers'];
    if (trailers is! List) return null;
    for (final trailer in trailers.whereType<Map>()) {
      final id = trailer['source'];
      if (trailer['type'] == 'Trailer' &&
          id is String &&
          RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
        return Uri.https('www.youtube.com', '/watch', {'v': id}).toString();
      }
    }
    return null;
  }

  static TvShow movieFromJson(Map<String, dynamic> row) {
    final id = row['imdb_id'] ?? row['id'];
    final name = row['name'];
    if (id is! String ||
        !RegExp(r'^tt\d{7,10}$').hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('invalid-movie');
    }
    final runtimeMatch = RegExp(
      r'^(\d+)\s*min$',
    ).firstMatch(row['runtime']?.toString() ?? '');
    final runtime = runtimeMatch == null
        ? null
        : int.tryParse(runtimeMatch.group(1)!);
    final genres = row['genres'] ?? row['genre'];
    return TvShow(
      id: TvShow.movieIdOffset + int.parse(id.substring(2)),
      isMovie: true,
      name: name,
      imdbId: id,
      summary: row['description'] as String? ?? '',
      genres: genres is List ? genres.whereType<String>().toList() : const [],
      runtime: runtime != null && runtime > 0 ? runtime : null,
      premiered: row['released'] as String? ?? row['releaseInfo'] as String?,
      imageMedium: row['poster'] as String?,
      imageOriginal: row['poster'] as String?,
      tvMazeUrl: 'https://www.imdb.com/title/$id/',
      ratingAverage: double.tryParse(row['imdbRating']?.toString() ?? ''),
      trailerUrl: trailerFromJson(row),
      contentRating:
          row['contentRating'] as String? ?? row['certification'] as String?,
    );
  }

  Future<Map<String, dynamic>> _metadata(String type, String imdb) async {
    final data = await _request('/meta/$type/$imdb.json');
    final meta = data['meta'];
    if (meta is! Map ||
        (meta['imdb_id'] ?? meta['id']) != imdb ||
        meta['type'] != type) {
      throw const ShowFailure(ShowFailureType.invalidResponse);
    }
    return Map<String, dynamic>.from(meta);
  }

  @override
  Future<List<TvShow>> searchShows(String query) => series.searchShows(query);
  @override
  Future<List<TvShow>> getShowsPage(int page) => series.getShowsPage(page);
  @override
  Future<TvShow> getShow(int showId) async {
    if (showId < TvShow.movieIdOffset) {
      final show = await series.getShow(showId);
      final imdb = show.imdbId;
      if (imdb == null || !RegExp(r'^tt\d{7,10}$').hasMatch(imdb)) return show;
      try {
        final meta = await _metadata('series', imdb);
        return show.withTrailer(
          trailerFromJson(meta),
          meta['contentRating'] as String? ?? meta['certification'] as String?,
        );
      } catch (_) {
        return show;
      }
    }
    final imdb =
        'tt${(showId - TvShow.movieIdOffset).toString().padLeft(7, '0')}';
    return movieFromJson(await _metadata('movie', imdb));
  }

  @override
  Future<List<TvEpisode>> getEpisodes(int showId) async {
    if (showId < TvShow.movieIdOffset) return series.getEpisodes(showId);
    final movie = await getShow(showId);
    return [
      TvEpisode(
        id: showId,
        name: movie.name,
        summary: movie.summary,
        season: 1,
        number: 1,
        runtime: movie.runtime,
        airDate: movie.premiered,
      ),
    ];
  }
}
