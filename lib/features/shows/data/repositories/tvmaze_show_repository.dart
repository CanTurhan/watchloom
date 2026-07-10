import 'package:dio/dio.dart';
import 'package:watchloom/features/shows/data/datasources/tvmaze_remote_data_source.dart';
import 'package:watchloom/features/shows/data/mappers/tvmaze_mapper.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';

class TvMazeShowRepository implements ShowRepository {
  TvMazeShowRepository(this._remoteDataSource);

  final TvMazeRemoteDataSource _remoteDataSource;

  @override
  Future<List<TvShow>> searchShows(String query) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.length < 2) {
      return const [];
    }

    try {
      final response = await _remoteDataSource.searchShows(normalizedQuery);

      return response
          .map((searchItem) {
            final showValue = searchItem['show'];

            if (showValue is! Map) {
              throw const FormatException(
                'Search result does not contain a show.',
              );
            }

            return TvMazeMapper.showFromJson(
              Map<String, dynamic>.from(showValue),
            );
          })
          .where((show) => show.id > 0)
          .toList(growable: false);
    } catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<TvShow> getShow(int showId) async {
    try {
      final response = await _remoteDataSource.getShow(showId);
      return TvMazeMapper.showFromJson(response);
    } catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<List<TvEpisode>> getEpisodes(int showId) async {
    try {
      final response = await _remoteDataSource.getEpisodes(showId);

      return response
          .map(TvMazeMapper.episodeFromJson)
          .whereType<TvEpisode>()
          .toList(growable: false);
    } catch (error) {
      throw _mapFailure(error);
    }
  }

  ShowFailure _mapFailure(Object error) {
    if (error is ShowFailure) {
      return error;
    }

    if (error is FormatException) {
      return const ShowFailure(ShowFailureType.invalidResponse);
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;

      if (statusCode == 404) {
        return const ShowFailure(ShowFailureType.notFound);
      }

      if (statusCode == 429) {
        return const ShowFailure(ShowFailureType.rateLimited);
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const ShowFailure(ShowFailureType.network);

        case DioExceptionType.transformTimeout:
          return const ShowFailure(ShowFailureType.invalidResponse);

        case DioExceptionType.badCertificate:
        case DioExceptionType.badResponse:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          return const ShowFailure(ShowFailureType.unknown);
      }
    }

    return const ShowFailure(ShowFailureType.unknown);
  }
}
