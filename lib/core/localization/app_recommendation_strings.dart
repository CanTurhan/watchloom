import 'package:watchloom/core/localization/app_strings.dart';

extension AppRecommendationStrings on AppStrings {
  String get recommendationsTitle =>
      value(en: 'You Might Like', tr: 'Bunları da Sevebilirsin');

  String get refreshRecommendations => value(en: 'Refresh', tr: 'Yenile');

  String get recommendationsLoading =>
      value(en: 'Finding shows for you…', tr: 'Sana uygun diziler bulunuyor…');

  String get recommendationsEmpty => value(
    en: 'Add a few shows to your library to improve your recommendations.',
    tr: 'Önerileri geliştirmek için kütüphanene birkaç dizi ekle.',
  );

  String get recommendationsFailed => value(
    en: 'Recommendations could not be loaded.',
    tr: 'Öneriler yüklenemedi.',
  );

  String recommendationGenreReason(String genre) {
    return value(
      en: 'Matches your interest in $genre',
      tr: '$genre ilgine uygun',
    );
  }

  String get recommendationPopularReason =>
      value(en: 'Popular and highly rated', tr: 'Popüler ve yüksek puanlı');
}
