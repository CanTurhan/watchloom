import 'package:watchloom/features/library/domain/entities/library_entry.dart';

enum WatchLogSource { manualWatch }

extension WatchLogSourceCode on WatchLogSource {
  String get code {
    switch (this) {
      case WatchLogSource.manualWatch:
        return 'manual_watch';
    }
  }

  static WatchLogSource fromCode(String? code) {
    switch (code) {
      case 'manual_watch':
      default:
        return WatchLogSource.manualWatch;
    }
  }
}

class EpisodeWatchLog {
  const EpisodeWatchLog({
    required this.showId,
    required this.showName,
    required this.episodeId,
    required this.season,
    required this.episodeNumber,
    required this.watchedAt,
    required this.source,
    this.id,
    this.runtimeMinutes,
    this.previousStatus,
    this.previousSeason,
    this.previousEpisodeNumber,
    this.previousEpisodeId,
  });

  final int? id;
  final int showId;
  final String showName;
  final int episodeId;
  final int season;
  final int episodeNumber;
  final int? runtimeMinutes;
  final DateTime watchedAt;
  final WatchLogSource source;

  final LibraryStatus? previousStatus;
  final int? previousSeason;
  final int? previousEpisodeNumber;
  final int? previousEpisodeId;

  String get episodeCode {
    final seasonText = season.toString().padLeft(2, '0');
    final episodeText = episodeNumber.toString().padLeft(2, '0');

    return 'S$seasonText · E$episodeText';
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'show_id': showId,
      'show_name': showName,
      'episode_id': episodeId,
      'season': season,
      'episode_number': episodeNumber,
      'runtime_minutes': runtimeMinutes,
      'watched_at': watchedAt.toUtc().toIso8601String(),
      'source': source.code,
      'previous_status': previousStatus?.code,
      'previous_season': previousSeason,
      'previous_episode_number': previousEpisodeNumber,
      'previous_episode_id': previousEpisodeId,
    };
  }

  factory EpisodeWatchLog.fromMap(Map<String, Object?> map) {
    final previousStatusCode = map['previous_status'] as String?;

    return EpisodeWatchLog(
      id: map['id'] as int?,
      showId: map['show_id'] as int,
      showName: map['show_name'] as String,
      episodeId: map['episode_id'] as int,
      season: map['season'] as int,
      episodeNumber: map['episode_number'] as int,
      runtimeMinutes: map['runtime_minutes'] as int?,
      watchedAt: DateTime.parse(map['watched_at'] as String),
      source: WatchLogSourceCode.fromCode(map['source'] as String?),
      previousStatus: previousStatusCode == null
          ? null
          : LibraryStatusCode.fromCode(previousStatusCode),
      previousSeason: map['previous_season'] as int?,
      previousEpisodeNumber: map['previous_episode_number'] as int?,
      previousEpisodeId: map['previous_episode_id'] as int?,
    );
  }
}
