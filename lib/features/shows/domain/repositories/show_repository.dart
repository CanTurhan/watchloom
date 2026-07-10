import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

enum ShowFailureType {
  network,
  rateLimited,
  notFound,
  invalidResponse,
  unknown,
}

class ShowFailure implements Exception {
  const ShowFailure(this.type);

  final ShowFailureType type;
}

abstract interface class ShowRepository {
  Future<List<TvShow>> searchShows(String query);

  Future<TvShow> getShow(int showId);

  Future<List<TvEpisode>> getEpisodes(int showId);
}
