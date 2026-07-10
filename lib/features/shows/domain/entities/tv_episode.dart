class TvEpisode {
  const TvEpisode({
    required this.id,
    required this.name,
    required this.summary,
    this.season,
    this.number,
    this.airDate,
    this.airTime,
    this.runtime,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String summary;
  final int? season;
  final int? number;
  final String? airDate;
  final String? airTime;
  final int? runtime;
  final String? imageUrl;

  String get code {
    final seasonValue = season;
    final numberValue = number;

    if (seasonValue != null && numberValue != null) {
      final seasonText = seasonValue.toString().padLeft(2, '0');
      final episodeText = numberValue.toString().padLeft(2, '0');

      return 'S$seasonText E$episodeText';
    }

    if (seasonValue != null) {
      return 'S${seasonValue.toString().padLeft(2, '0')}';
    }

    return 'Episode';
  }
}
