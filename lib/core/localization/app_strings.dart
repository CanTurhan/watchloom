import 'package:flutter/material.dart';

class AppStrings {
  AppStrings(this.languageCode);

  final String languageCode;

  bool get isTurkish => languageCode == 'tr';

  static AppStrings of(BuildContext context) {
    return AppStrings(Localizations.localeOf(context).languageCode);
  }

  String value({required String en, required String tr}) {
    return isTurkish ? tr : en;
  }

  String get appName => 'Watchloom';

  String get tagline =>
      value(en: 'Your shows, remembered.', tr: 'Dizilerin, kaldığın yerden.');

  String get home => value(en: 'Home', tr: 'Ana Sayfa');
  String get library => value(en: 'Library', tr: 'Kütüphane');
  String get discover => value(en: 'Discover', tr: 'Keşfet');
  String get myMonth => value(en: 'My Month', tr: 'Ayım');
  String get profile => value(en: 'Profile', tr: 'Profil');

  String get continueWatching =>
      value(en: 'CONTINUE WATCHING', tr: 'İZLEMEYE DEVAM ET');

  String get markNextWatched => value(
    en: 'Mark next episode watched',
    tr: 'Sonraki bölümü izlendi işaretle',
  );

  String get comingUp => value(en: 'Coming Up', tr: 'Yakında');

  String get seeAll => value(en: 'See all', tr: 'Tümünü gör');

  String get youMightLike =>
      value(en: 'You Might Like', tr: 'Bunları Sevebilirsin');

  String get refresh => value(en: 'Refresh', tr: 'Yenile');

  String get thisMonth => value(en: 'This Month', tr: 'Bu Ay');

  String get yourJuly => value(en: 'YOUR JULY', tr: 'TEMMUZ AYIN');

  String get episodes => value(en: 'Episodes', tr: 'Bölüm');

  String get shows => value(en: 'Shows', tr: 'Dizi');

  String get watchTime => value(en: 'Watch time', tr: 'İzleme süresi');

  String get dayStreak =>
      value(en: '7 day watching streak', tr: '7 günlük izleme serisi');

  String get personalBest => value(en: 'Personal best', tr: 'Kişisel rekor');

  String get releaseDatePending =>
      value(en: 'Release date not announced', tr: 'Yayın tarihi açıklanmadı');

  String get becauseDark =>
      value(en: 'Because you liked Dark', tr: 'Dark dizisini sevdiğin için');

  String get matchingGenres => value(
    en: 'Matches your favorite genres',
    tr: 'Sevdiğin türlerle eşleşiyor',
  );

  String get shortMystery =>
      value(en: 'A short sci-fi mystery', tr: 'Kısa bir bilim kurgu gizemi');

  String get libraryDescription => value(
    en: 'Your watching, watchlist, completed, paused and dropped shows.',
    tr: 'İzlediğin, beklettiğin, tamamladığın ve bıraktığın diziler.',
  );

  String get discoverDescription => value(
    en: 'Recommendations based on your watch history and ratings.',
    tr: 'İzleme geçmişine ve puanlarına göre kişisel öneriler.',
  );

  String get monthDescription => value(
    en: 'Monthly activity, statistics and Instagram Story sharing.',
    tr: 'Aylık etkinliklerin, istatistiklerin ve Story paylaşımların.',
  );

  String get profileDescription => value(
    en: 'Your streaks, achievements and lifetime statistics.',
    tr: 'Serilerin, başarımların ve genel izleme istatistiklerin.',
  );

  String get dailyStreak => value(en: 'Daily streak', tr: 'Günlük seri');

  String get monthlyStreak => value(en: 'Monthly streak', tr: 'Aylık seri');

  String get totalEpisodes => value(en: 'Total episodes', tr: 'Toplam bölüm');

  String get achievements => value(en: 'Achievements', tr: 'Başarımlar');

  String get unlocked => value(en: 'Unlocked', tr: 'Açıldı');

  String get settings => value(en: 'Settings', tr: 'Ayarlar');

  String get settingsDescription => value(
    en: 'Language, privacy, legal information and app details.',
    tr: 'Dil, gizlilik, yasal bilgiler ve uygulama detayları.',
  );

  String get general => value(en: 'GENERAL', tr: 'GENEL');

  String get legal =>
      value(en: 'LEGAL & INFORMATION', tr: 'YASAL VE BİLGİLENDİRME');

  String get language => value(en: 'Language', tr: 'Dil');

  String get english => value(en: 'English', tr: 'İngilizce');

  String get turkish => value(en: 'Turkish', tr: 'Türkçe');

  String get privacyPolicy =>
      value(en: 'Privacy Policy', tr: 'Gizlilik Politikası');

  String get termsOfUse => value(en: 'Terms of Use', tr: 'Kullanım Koşulları');

  String get dataSources => value(en: 'Data Sources', tr: 'Veri Kaynakları');

  String get openSourceLicenses =>
      value(en: 'Open-Source Licenses', tr: 'Açık Kaynak Lisansları');

  String get helpSupport => value(en: 'Help & Support', tr: 'Yardım ve Destek');

  String get about => value(en: 'About Watchloom', tr: 'Watchloom Hakkında');

  String get version => value(en: 'Version', tr: 'Sürüm');

  String get languageChanged =>
      value(en: 'Language updated.', tr: 'Dil güncellendi.');
}
