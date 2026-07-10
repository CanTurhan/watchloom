import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';

class TvShow {
  const TvShow({
    required this.id,
    required this.name,
    required this.summary,
    required this.genres,
    this.status,
    this.language,
    this.premiered,
    this.ended,
    this.runtime,
    this.ratingAverage,
    this.imageMedium,
    this.imageOriginal,
    this.channelName,
    this.tvMazeUrl,
    this.nextEpisode,
    this.previousEpisode,
  });

  final int id;
  final String name;
  final String summary;
  final List<String> genres;

  final String? status;
  final String? language;
  final String? premiered;
  final String? ended;
  final int? runtime;
  final double? ratingAverage;
  final String? imageMedium;
  final String? imageOriginal;
  final String? channelName;
  final String? tvMazeUrl;

  final TvEpisode? nextEpisode;
  final TvEpisode? previousEpisode;

  String? get premiereYear {
    final value = premiered;

    if (value == null || value.length < 4) {
      return null;
    }

    return value.substring(0, 4);
  }
}
