import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

abstract final class TvMazeMapper {
  static TvShow showFromJson(Map<String, dynamic> json) {
    final image = _asMap(json['image']);
    final rating = _asMap(json['rating']);
    final network = _asMap(json['network']);
    final webChannel = _asMap(json['webChannel']);
    final embedded = _asMap(json['_embedded']);

    return TvShow(
      id: _asInt(json['id']),
      name: _asString(json['name'], fallback: 'Unknown Show'),
      summary: cleanHtml(json['summary']),
      genres: _asStringList(json['genres']),
      status: _nullableString(json['status']),
      language: _nullableString(json['language']),
      premiered: _nullableString(json['premiered']),
      ended: _nullableString(json['ended']),
      runtime: _nullableInt(json['runtime']),
      ratingAverage: _nullableDouble(rating?['average']),
      imageMedium: _nullableString(image?['medium']),
      imageOriginal: _nullableString(image?['original']),
      channelName: _nullableString(network?['name'] ?? webChannel?['name']),
      tvMazeUrl: _nullableString(json['url']),
      nextEpisode: episodeFromJson(embedded?['nextepisode']),
      previousEpisode: episodeFromJson(embedded?['previousepisode']),
    );
  }

  static TvEpisode? episodeFromJson(dynamic value) {
    final json = _asMap(value);

    if (json == null) {
      return null;
    }

    final image = _asMap(json['image']);

    return TvEpisode(
      id: _asInt(json['id']),
      name: _asString(json['name'], fallback: 'Untitled Episode'),
      summary: cleanHtml(json['summary']),
      season: _nullableInt(json['season']),
      number: _nullableInt(json['number']),
      airDate: _nullableString(json['airdate']),
      airTime: _nullableString(json['airtime']),
      runtime: _nullableInt(json['runtime']),
      imageUrl: _nullableString(image?['original'] ?? image?['medium']),
    );
  }

  static String cleanHtml(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return '';
    }

    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static String _asString(dynamic value, {required String fallback}) {
    final result = _nullableString(value);
    return result ?? fallback;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return null;
    }

    return result;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
