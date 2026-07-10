import 'package:watchloom/core/localization/app_strings.dart';

extension AppShowStrings on AppStrings {
  String get searchShows => value(en: 'Search Shows', tr: 'Dizi Ara');

  String get searchHint =>
      value(en: 'Search by show name', tr: 'Dizi adıyla ara');

  String get searchIntro => value(
    en: 'Find a show and view its episodes, summary and release information.',
    tr: 'Bir dizi bul; özetini, bölümlerini ve yayın bilgilerini görüntüle.',
  );

  String get minimumTwoCharacters =>
      value(en: 'Enter at least 2 characters.', tr: 'En az 2 karakter gir.');

  String get noShowsFound =>
      value(en: 'No matching shows found.', tr: 'Eşleşen dizi bulunamadı.');

  String get tryAnotherSearch => value(
    en: 'Try another title or check the spelling.',
    tr: 'Başka bir isim dene veya yazımı kontrol et.',
  );

  String get retry => value(en: 'Try Again', tr: 'Tekrar Dene');

  String get summaryTitle => value(en: 'Summary', tr: 'Özet');

  String get nextEpisodeTitle => value(en: 'Next Episode', tr: 'Gelecek Bölüm');

  String get previousEpisodeTitle =>
      value(en: 'Latest Episode', tr: 'Son Yayınlanan Bölüm');

  String get noSummary => value(
    en: 'No summary is available for this title.',
    tr: 'Bu dizi için özet bulunmuyor.',
  );

  String get noUpcomingEpisode => value(
    en: 'No upcoming episode has been announced.',
    tr: 'Açıklanmış gelecek bölüm bulunmuyor.',
  );

  String get releaseDateUnknown =>
      value(en: 'Release date not announced', tr: 'Yayın tarihi açıklanmadı');

  String get today => value(en: 'Today', tr: 'Bugün');

  String get tomorrow => value(en: 'Tomorrow', tr: 'Yarın');

  String get aired => value(en: 'Aired', tr: 'Yayınlandı');

  String inDays(int days) => value(en: 'In $days days', tr: '$days gün sonra');

  String get networkError => value(
    en: 'The internet connection could not be reached.',
    tr: 'İnternet bağlantısına ulaşılamadı.',
  );

  String get rateLimitError => value(
    en: 'Too many requests were made. Wait briefly and try again.',
    tr: 'Çok fazla istek gönderildi. Kısa süre bekleyip tekrar dene.',
  );

  String get notFoundError => value(
    en: 'The requested show could not be found.',
    tr: 'İstenen dizi bulunamadı.',
  );

  String get invalidResponseError => value(
    en: 'The show data could not be read.',
    tr: 'Dizi verisi okunamadı.',
  );

  String get unknownError => value(
    en: 'Something went wrong while loading the show data.',
    tr: 'Dizi verileri yüklenirken bir sorun oluştu.',
  );

  String get statusLabel => value(en: 'Status', tr: 'Durum');

  String get channelLabel => value(en: 'Channel', tr: 'Kanal');

  String get premieredLabel => value(en: 'Premiered', tr: 'Başlangıç');

  String get dataByTvMaze => value(
    en: 'TV data provided by TVMaze',
    tr: 'Dizi verileri TVMaze tarafından sağlanmaktadır',
  );
}
