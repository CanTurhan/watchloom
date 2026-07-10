import 'package:watchloom/core/localization/app_strings.dart';

extension AppSettingsStrings on AppStrings {
  String get settingsTitle => value(en: 'Settings', tr: 'Ayarlar');

  String get settingsSubtitle => value(
    en: 'Manage notifications, information and local data.',
    tr: 'Bildirimleri, bilgileri ve yerel verileri yönet.',
  );

  String get notificationsSettingTitle =>
      value(en: 'Episode Notifications', tr: 'Bölüm Bildirimleri');

  String get notificationsSettingSubtitle => value(
    en: 'Manage upcoming episode reminders.',
    tr: 'Yaklaşan bölüm hatırlatmalarını yönet.',
  );

  String get dataSourceTitle => value(en: 'Data Source', tr: 'Veri Kaynağı');

  String get dataSourceSubtitle => value(
    en: 'Learn where show information comes from.',
    tr: 'Dizi bilgilerinin nereden geldiğini öğren.',
  );

  String get dataSourceBody => value(
    en: 'Watchloom uses TVMaze to retrieve show names, episodes, release dates, cast, ratings, networks and streaming platform information. Availability and accuracy depend on the information provided by TVMaze.',
    tr: 'Watchloom; dizi adları, bölümler, yayın tarihleri, oyuncular, puanlar, kanallar ve dijital platform bilgileri için TVMaze verilerini kullanır. Bilgilerin bulunabilirliği ve doğruluğu TVMaze tarafından sağlanan verilere bağlıdır.',
  );

  String get privacyTitle => value(en: 'Privacy', tr: 'Gizlilik');

  String get privacySubtitle => value(
    en: 'How Watchloom handles your information.',
    tr: 'Watchloom verilerini nasıl işler?',
  );

  String get privacyBody => value(
    en: 'Your library, watch progress, favorites, personal notes, achievements and activity history are stored locally on this device. Watchloom does not require an account. Show information is requested from TVMaze when needed.',
    tr: 'Kütüphanen, izleme ilerlemen, favorilerin, kişisel notların, başarımların ve etkinlik geçmişin bu cihazda yerel olarak saklanır. Watchloom hesap gerektirmez. Dizi bilgileri gerektiğinde TVMaze üzerinden alınır.',
  );

  String get termsTitle => value(en: 'Terms of Use', tr: 'Kullanım Koşulları');

  String get termsSubtitle => value(
    en: 'Important information about using Watchloom.',
    tr: 'Watchloom kullanımıyla ilgili önemli bilgiler.',
  );

  String get termsBody => value(
    en: 'Watchloom is a personal television tracking tool. Release dates, platforms, cast information and ratings may change or be incomplete. Watchloom does not guarantee the availability or accuracy of third-party information.',
    tr: 'Watchloom kişisel bir dizi takip aracıdır. Yayın tarihleri, platformlar, oyuncu bilgileri ve puanlar değişebilir veya eksik olabilir. Watchloom üçüncü taraf bilgilerinin kullanılabilirliğini ya da doğruluğunu garanti etmez.',
  );

  String get localDataTitle => value(en: 'Local Data', tr: 'Yerel Veriler');

  String get clearAllData =>
      value(en: 'Clear All Watchloom Data', tr: 'Tüm Watchloom Verilerini Sil');

  String get clearAllDataSubtitle => value(
    en: 'Remove your library, progress, notes, favorites and activity.',
    tr: 'Kütüphaneni, ilerlemeni, notlarını, favorilerini ve etkinliklerini kaldır.',
  );

  String get clearDataConfirmationTitle =>
      value(en: 'Clear all local data?', tr: 'Tüm yerel veriler silinsin mi?');

  String get clearDataConfirmationBody => value(
    en: 'This permanently removes your library, watch progress, favorites, personal notes, activity history, streaks, achievements and scheduled Watchloom notifications. This action cannot be undone.',
    tr: 'Bu işlem kütüphaneni, izleme ilerlemeni, favorilerini, kişisel notlarını, etkinlik geçmişini, serilerini, başarımlarını ve planlanan Watchloom bildirimlerini kalıcı olarak siler. Bu işlem geri alınamaz.',
  );

  String get clearDataConfirmAction =>
      value(en: 'Delete Everything', tr: 'Her Şeyi Sil');

  String get clearDataSuccess => value(
    en: 'All local Watchloom data was cleared.',
    tr: 'Tüm yerel Watchloom verileri silindi.',
  );

  String get clearDataFailed => value(
    en: 'Local data could not be cleared.',
    tr: 'Yerel veriler silinemedi.',
  );

  String get informationTitle => value(en: 'Information', tr: 'Bilgilendirme');
}
