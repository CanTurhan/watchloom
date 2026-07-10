import 'package:dio/dio.dart';

class TvMazeRemoteDataSource {
  TvMazeRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> searchShows(String query) async {
    final response = await _get('/search/shows', queryParameters: {'q': query});

    final body = response.data;

    if (body is! List) {
      throw const FormatException('TVMaze search response is not a list.');
    }

    return body
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getShow(int showId) async {
    final response = await _get(
      '/shows/$showId'
      '?embed[]=nextepisode'
      '&embed[]=previousepisode',
    );

    final body = response.data;

    if (body is! Map) {
      throw const FormatException('TVMaze show response is not an object.');
    }

    return Map<String, dynamic>.from(body);
  }

  Future<List<Map<String, dynamic>>> getEpisodes(int showId) async {
    final response = await _get('/shows/$showId/episodes');
    final body = response.data;

    if (body is! List) {
      throw const FormatException('TVMaze episode response is not a list.');
    }

    return body
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<dynamic>(path, queryParameters: queryParameters);
    } on DioException catch (error) {
      if (error.response?.statusCode != 429) {
        rethrow;
      }

      final retryAfterHeader = error.response?.headers.value('retry-after');

      final retrySeconds = int.tryParse(retryAfterHeader ?? '') ?? 2;

      await Future<void>.delayed(
        Duration(seconds: retrySeconds.clamp(1, 5).toInt()),
      );

      return _dio.get<dynamic>(path, queryParameters: queryParameters);
    }
  }
}
