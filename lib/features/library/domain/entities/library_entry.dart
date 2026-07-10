import 'dart:convert';

import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

enum LibraryStatus { watching, watchlist, completed, paused, dropped }

extension LibraryStatusCode on LibraryStatus {
  String get code => name;

  static LibraryStatus fromCode(String? code) {
    return LibraryStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => LibraryStatus.watchlist,
    );
  }
}

class LibraryEntry {
  const LibraryEntry({
    required this.showId,
    required this.name,
    required this.summary,
    required this.genres,
    required this.status,
    required this.addedAt,
    required this.updatedAt,
    this.imageMedium,
    this.imageOriginal,
    this.ratingAverage,
    this.channelName,
    this.premiered,
    this.tvMazeUrl,
    this.lastSeason,
    this.lastEpisode,
    this.lastEpisodeId,
  });

  final int showId;
  final String name;
  final String summary;
  final List<String> genres;
  final LibraryStatus status;

  final String? imageMedium;
  final String? imageOriginal;
  final double? ratingAverage;
  final String? channelName;
  final String? premiered;
  final String? tvMazeUrl;

  final int? lastSeason;
  final int? lastEpisode;
  final int? lastEpisodeId;

  final DateTime addedAt;
  final DateTime updatedAt;

  bool get hasProgress {
    return lastSeason != null && lastEpisode != null;
  }

  String get progressCode {
    if (!hasProgress) {
      return '';
    }

    final seasonText = lastSeason.toString().padLeft(2, '0');
    final episodeText = lastEpisode.toString().padLeft(2, '0');

    return 'S$seasonText · E$episodeText';
  }

  LibraryEntry copyWith({
    LibraryStatus? status,
    int? lastSeason,
    int? lastEpisode,
    int? lastEpisodeId,
    DateTime? updatedAt,
  }) {
    return LibraryEntry(
      showId: showId,
      name: name,
      summary: summary,
      genres: genres,
      status: status ?? this.status,
      imageMedium: imageMedium,
      imageOriginal: imageOriginal,
      ratingAverage: ratingAverage,
      channelName: channelName,
      premiered: premiered,
      tvMazeUrl: tvMazeUrl,
      lastSeason: lastSeason ?? this.lastSeason,
      lastEpisode: lastEpisode ?? this.lastEpisode,
      lastEpisodeId: lastEpisodeId ?? this.lastEpisodeId,
      addedAt: addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  TvShow toTvShow() {
    return TvShow(
      id: showId,
      name: name,
      summary: summary,
      genres: genres,
      imageMedium: imageMedium,
      imageOriginal: imageOriginal,
      ratingAverage: ratingAverage,
      channelName: channelName,
      premiered: premiered,
      tvMazeUrl: tvMazeUrl,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'show_id': showId,
      'name': name,
      'summary': summary,
      'genres_json': jsonEncode(genres),
      'status': status.code,
      'image_medium': imageMedium,
      'image_original': imageOriginal,
      'rating_average': ratingAverage,
      'channel_name': channelName,
      'premiered': premiered,
      'tvmaze_url': tvMazeUrl,
      'last_season': lastSeason,
      'last_episode': lastEpisode,
      'last_episode_id': lastEpisodeId,
      'added_at': addedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory LibraryEntry.fromMap(Map<String, Object?> map) {
    final genresValue = map['genres_json'];
    final decodedGenres = genresValue is String
        ? jsonDecode(genresValue)
        : const <dynamic>[];

    return LibraryEntry(
      showId: map['show_id'] as int,
      name: map['name'] as String,
      summary: map['summary'] as String? ?? '',
      genres: decodedGenres is List
          ? decodedGenres.map((item) => item.toString()).toList(growable: false)
          : const [],
      status: LibraryStatusCode.fromCode(map['status'] as String?),
      imageMedium: map['image_medium'] as String?,
      imageOriginal: map['image_original'] as String?,
      ratingAverage: (map['rating_average'] as num?)?.toDouble(),
      channelName: map['channel_name'] as String?,
      premiered: map['premiered'] as String?,
      tvMazeUrl: map['tvmaze_url'] as String?,
      lastSeason: map['last_season'] as int?,
      lastEpisode: map['last_episode'] as int?,
      lastEpisodeId: map['last_episode_id'] as int?,
      addedAt: DateTime.parse(map['added_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
