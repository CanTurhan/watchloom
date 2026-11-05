import 'package:watchloom/core/localization/app_strings.dart';

extension AppLegalStrings on AppStrings {
  String get licenseAcknowledgements => value(
    en: 'License notices for third-party software.',
    tr: 'Üçüncü taraf yazılımların lisans bildirimleri.',
  );
  String get adPrivacyTitle =>
      value(en: 'Advertising & Privacy', tr: 'Reklam ve Gizlilik');
  String get adPrivacySubtitle => value(
    en: 'Choose whether Watchloom may load banner ads.',
    tr: 'Watchloom’un banner reklam yükleyip yükleyemeyeceğini seç.',
  );
  String get adPrivacyBody => value(
    en: 'With your permission, the free plan loads Yandex banner ads. Yandex and its measurement components may receive device identifiers, IP address and approximate region, ad interactions and technical or diagnostic information to deliver and measure ads. Processing may take place outside your country, including in Russia. Your library, notes and watch history are not included in ad requests.\n\nWatchloom keeps personalized-ad consent and SDK location tracking off and does not request App Tracking Transparency permission. Allowing these limited ads does not authorize tracking across other apps.\n\nYou can decline or withdraw this choice here at any time. Your free library of 5 shows and the other free features remain available with either choice. Premium does not load banner ads regardless of this setting.',
    tr: 'İzin verirsen ücretsiz planda Yandex banner reklamları yüklenir. Reklam sunumu ve ölçümü için Yandex ve ölçüm bileşenlerine cihaz tanımlayıcıları, IP adresi ve yaklaşık bölge, reklam etkileşimleri, teknik veya tanılama bilgileri iletilebilir. Veriler, Rusya dahil ülken dışındaki yerlerde işlenebilir. Kütüphanen, notların ve izleme geçmişin reklam isteklerine eklenmez.\n\nWatchloom kişiselleştirilmiş reklam onayını ve SDK konum takibini kapalı tutar; App Tracking Transparency izni istemez. Bu sınırlı reklamlara izin vermek diğer uygulamalarda takip izni vermez.\n\nBu tercihi istediğin zaman reddedebilir veya buradan geri çekebilirsin. Her iki seçenekle de 5 dizilik ücretsiz kütüphanen ve diğer ücretsiz özellikler açık kalır. Premium, bu ayardan bağımsız olarak banner reklam yüklemez.',
  );
  String get allowLimitedAds =>
      value(en: 'Allow Limited Ads', tr: 'Sınırlı Reklamlara İzin Ver');
  String get declineAds =>
      value(en: 'Do Not Allow Ads', tr: 'Reklamlara İzin Verme');
  String get adsAllowedStatus => value(
    en: 'Limited ads are allowed',
    tr: 'Sınırlı reklamlara izin verildi',
  );
  String get adsDeclinedStatus => value(
    en: 'Ads are turned off by your choice',
    tr: 'Tercihin doğrultusunda reklamlar kapalı',
  );
  String get adPrivacySaveFailed => value(
    en: 'Your choice could not be saved. Please try again.',
    tr: 'Tercihin kaydedilemedi. Lütfen tekrar dene.',
  );
  String get adSdkWithdrawal => value(
    en: 'New ad requests stop when you decline. A previously initialized SDK may still finish technical processing in the current session; after you close and reopen Watchloom it will not be initialized while this choice is off.',
    tr: 'Reddettiğinde yeni reklam istekleri durur. Daha önce başlatılan SDK bu oturumda teknik işlemleri tamamlayabilir; Watchloom’u kapatıp yeniden açtığında bu tercih kapalıyken SDK başlatılmaz.',
  );
  String get reportAd => value(en: 'Report an Ad', tr: 'Reklam Bildir');
  String get reportAdBody => value(
    en: 'To report an inappropriate or misleading ad, describe the ad, when you saw it and your app version. You may attach a screenshot if it contains no private information. You can also use the ad’s own information or report button. Change Advertising & Privacy to stop new banner requests.',
    tr: 'Uygunsuz veya yanıltıcı reklamı bildirmek için reklamı, ne zaman gördüğünü ve uygulama sürümünü belirt. Özel bilgi içermiyorsa ekran görüntüsü ekleyebilirsin. Reklamın kendi bilgi veya bildirim düğmesini de kullanabilirsin. Yeni banner isteklerini durdurmak için Reklam ve Gizlilik tercihini değiştirebilirsin.',
  );
  String get contactSupport =>
      value(en: 'Contact Support', tr: 'Destek ile İletişime Geç');
  String get privacyRequest =>
      value(en: 'Send a Privacy Request', tr: 'Gizlilik Talebi İlet');
  String get onlinePrivacy =>
      value(en: 'Privacy Policy on the Web', tr: 'Web Gizlilik Politikası');
  String get providerPrivacy =>
      value(en: 'Yandex Privacy Policy', tr: 'Yandex Gizlilik Politikası');
  String get contentLicense => value(
    en: 'TVmaze data · CC BY-SA 4.0',
    tr: 'TVmaze verileri · CC BY-SA 4.0',
  );
  String get sourceAndLicense =>
      value(en: 'Source & License', tr: 'Kaynak ve Lisans');
  String get refundSupport => value(
    en: 'Apple Purchase & Refund Help',
    tr: 'Apple Satın Alma ve İade Yardımı',
  );
}
