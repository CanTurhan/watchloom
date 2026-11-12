import 'package:dio/dio.dart';
import 'dart:io';
import 'package:watchloom/features/shows/data/datasources/tvmaze_remote_data_source.dart';
import 'package:watchloom/features/shows/data/repositories/tvmaze_show_repository.dart';
import 'package:watchloom/features/shows/data/repositories/media_catalog_repository.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

Future<void> main() async {
  final series = TvMazeShowRepository(
    TvMazeRemoteDataSource(
      Dio(
        BaseOptions(
          baseUrl: 'https://api.tvmaze.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ),
    ),
  );
  final catalog = MediaCatalogRepository(series);
  final movies = await catalog.searchMovies('Inception');
  final result = movies.firstWhere(
    (movie) => movie.id == TvShow.movieIdOffset + 1375666,
  );
  final movie = await catalog.getShow(result.id);
  if (movie.runtime != 148 || movie.trailerUrl == null) {
    throw StateError('Live movie details are incomplete');
  }
  final episodes = await catalog.getEpisodes(movie.id);
  if (episodes.length != 1 || episodes.single.runtime != 148) {
    throw StateError('Movie watch event is invalid');
  }
  final show = await catalog.getShow(169);
  if (show.name != 'Breaking Bad' ||
      show.imdbId != 'tt0903747' ||
      show.trailerUrl == null) {
    throw StateError('Live series details or trailer are incomplete');
  }
  stdout.writeln(
    'Live catalog verified: ${movies.length} movie results; ${movie.name} ${movie.runtime} min; ${show.name}; movie and series trailers available.',
  );
}
