import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/legal/app_legal.dart';

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
    en: '''Show and episode metadata is provided by TVmaze under Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA 4.0). Watchloom formats dates, removes summary markup and combines this metadata with your personal tracking records. TVmaze-derived data remains subject to that license; your personal notes and the Watchloom application are not licensed as TVmaze data.

Use the source and license links below. Show pages link to the original TVmaze entry. Posters and other artwork may carry additional rights belonging to their respective owners; a source link is not permission to use protected artwork for unrelated purposes. Watchloom does not provide streaming video and is not affiliated with TVmaze, broadcasters or streaming platforms.''',
    tr: '''Dizi ve bölüm bilgileri TVmaze tarafından Creative Commons Atıf-AynıLisanslaPaylaş 4.0 (CC BY-SA 4.0) kapsamında sağlanır. Watchloom tarihleri biçimlendirir, özetlerdeki işaretlemeyi kaldırır ve bu verileri kişisel takip kayıtlarınla birlikte gösterir. TVmaze kaynaklı veriler bu lisansa tabidir; kişisel notların ve Watchloom uygulamasının kendisi TVmaze verisi olarak lisanslanmaz.

Aşağıdaki kaynak ve lisans bağlantılarını kullanabilirsin. Dizi sayfaları TVmaze kaydına bağlantı verir. Afişler ve diğer görseller ilgili hak sahiplerinin ek haklarını içerebilir; kaynak bağlantısı, korunan görsellerin ilgisiz amaçlarla kullanımı için izin değildir. Watchloom video yayını sunmaz; TVmaze, yayıncılar veya dijital platformlarla bağlantılı değildir.''',
  );

  String get privacyTitle => value(en: 'Privacy', tr: 'Gizlilik');

  String get privacySubtitle => value(
    en: 'How Watchloom handles your information.',
    tr: 'Watchloom verilerini nasıl işler?',
  );

  String get privacyBody => value(
    en: '''Provider and contact: ${AppLegal.controllerName}. Privacy and support requests: ${AppLegal.contact}

Processing grounds: the minimum network data needed for features you request is used to provide that service; optional advertising depends on your permission; support information is used to answer your request and meet applicable legal duties. Statutory processing and cross-border transfer requirements apply separately. Withdrawing permission does not affect processing that was lawful before withdrawal.\n\nYour library, episode progress, favorites, notes and activity stay in this device's local database. Watchloom does not run a user account or upload this library to its own cloud server. Device backups are controlled by your operating system. TVmaze receives your search text and network requests to return show information; poster providers receive image requests. These providers may process standard network information such as your IP address.

Optional advertising: Yandex Mobile Ads is not initialized until you allow limited ads in Advertising & Privacy and your subscription is verified as free. Yandex and its measurement components may process device identifiers, IP address and approximate region, advertising interactions and technical or diagnostic information. Your library and notes are not attached to ad requests. Personalized-ad consent, SDK location tracking and optional AppMetrica app/ad analytics reporting stay off. Watchloom does not request tracking permission. Premium never loads banner ads.

You may decline or withdraw advertising permission without losing the free features. Withdrawal stops new banner requests and removes the banner. A previously initialized SDK may complete technical processing in the current session; it will not be initialized on subsequent launches while permission remains off. Your decision, notice version and decision date are saved locally.

Apple processes monthly subscriptions. Watchloom verifies Apple-signed access and expiry information on your device and does not receive card details. User-initiated sharing sends your selected monthly viewing summary to the app or recipient you choose through the system share sheet.

Retention and deletion: watch data remains until you remove it, clear watch data in Settings, or remove the app, subject to OS backups. Clearing watch data also removes generated Watchloom share images in its temporary folder; language and privacy choices remain. Clearing data does not cancel Apple billing or delete records already held by other providers. Support correspondence is retained only as needed to handle the request and meet applicable legal duties.

Apple, TVmaze, image providers and Yandex may process data outside your country. Yandex identifies processing in Russia and other jurisdictions in its policy. Provider-held information is subject to their retention and deletion procedures. You can request information, correction, deletion, withdrawal or objection where applicable, and contact your local data protection authority. We can help direct provider-specific requests, but cannot access your local library remotely. Contact us using the link below.

Watchloom is not directed at children under 13. Do not send private notes, passwords or payment information in a public support issue.''',
    tr: '''Sağlayıcı ve iletişim: ${AppLegal.controllerName}. Gizlilik ve destek talepleri: ${AppLegal.contact}

İşleme sebepleri: Talep ettiğin özelliklerin gerektirdiği asgari ağ bilgileri bu hizmeti sağlamak için; isteğe bağlı reklamlar iznine bağlı olarak; destek bilgileri talebini yanıtlamak ve geçerli yasal yükümlülükleri karşılamak için kullanılır. Kanuni işleme ve yurt dışı aktarım şartları ayrıca geçerlidir. Rızayı geri çekmek, önceki hukuka uygun işlemeyi etkilemez.\n\nKütüphanen, bölüm ilerlemen, favorilerin, notların ve etkinliklerin bu cihazın yerel veritabanında saklanır. Watchloom kullanıcı hesabı işletmez ve bu kütüphaneyi kendi bulut sunucusuna yüklemez. Cihaz yedeklerini işletim sistemin yönetir. TVmaze, dizi bilgilerini getirmek için arama metnini ve ağ isteklerini alır; görsel sağlayıcıları görsel isteklerini alır. Bu sağlayıcılar IP adresi gibi standart ağ bilgilerini işleyebilir.

İsteğe bağlı reklamlar: Reklam ve Gizlilik ekranında sınırlı reklamlara izin vermeden ve ücretsiz abonelik durumu doğrulanmadan Yandex Mobile Ads başlatılmaz. Yandex ve ölçüm bileşenleri; cihaz tanımlayıcıları, IP adresi ve yaklaşık bölge, reklam etkileşimleri, teknik veya tanılama bilgilerini işleyebilir. Kütüphanen ve notların reklam isteklerine eklenmez. Kişiselleştirilmiş reklam onayı, SDK konum takibi ve isteğe bağlı AppMetrica uygulama/reklam analitiği kapalı kalır. Watchloom takip izni istemez. Premium banner reklam yüklemez.

Ücretsiz özellikleri kaybetmeden reklam iznini reddedebilir veya geri çekebilirsin. Geri çekme yeni banner isteklerini durdurur ve banner'ı kaldırır. Daha önce başlatılmış SDK bu oturumda teknik işlemleri tamamlayabilir; izin kapalı kaldığında sonraki açılışlarda başlatılmaz. Tercihin, bilgilendirme sürümü ve karar tarihi yerel olarak saklanır.

Aylık abonelikleri Apple işler. Watchloom cihazında Apple imzalı erişim ve bitiş bilgilerini doğrular; kart bilgilerini almaz. Paylaşmayı seçtiğinde aylık izleme özetin sistem paylaşım ekranında seçtiğin uygulama veya alıcıya gönderilir.

Saklama ve silme: İzleme verileri, sen kaldırana, Ayarlar'dan izleme verilerini silene veya işletim sistemi yedeklerine bağlı olarak uygulamayı kaldırana kadar saklanır. İzleme verilerini silmek, geçici klasördeki oluşturulmuş Watchloom paylaşım görsellerini de kaldırır; dil ve gizlilik tercihleri korunur. Veri silmek Apple ödemesini iptal etmez ve diğer sağlayıcılardaki kayıtları silmez. Destek yazışmaları yalnızca talebi karşılamak ve geçerli yasal yükümlülükleri yerine getirmek için gerektiği kadar saklanır.

Apple, TVmaze, görsel sağlayıcıları ve Yandex verileri ülken dışında işleyebilir. Yandex politikası Rusya ve diğer ülkelerde işlemeyi belirtir. Sağlayıcılardaki bilgiler kendi saklama ve silme süreçlerine tabidir. Geçerli olduğu ölçüde bilgi, düzeltme, silme, rızayı geri çekme ve itiraz haklarını kullanabilir; yerel veri koruma otoritesine başvurabilirsin. Sağlayıcıya özel talepler için yönlendirme yapabiliriz; yerel kütüphanene uzaktan erişemeyiz. Aşağıdaki iletişim bağlantısını kullanabilirsin.

Watchloom 13 yaş altındaki çocuklara yönelik değildir. Herkese açık destek talebine özel notlarını, parolalarını veya ödeme bilgilerini yazma.''',
  );

  String get termsTitle => value(en: 'Terms of Use', tr: 'Kullanım Koşulları');

  String get termsSubtitle => value(
    en: 'Important information about using Watchloom.',
    tr: 'Watchloom kullanımıyla ilgili önemli bilgiler.',
  );

  String get termsBody => value(
    en: 'Watchloom is a personal television tracking tool. Third-party show information may change or be incomplete.\n\nFree includes up to 5 saved shows. Banner ads are optional and depend on your Advertising & Privacy choice. Premium is a monthly auto-renewable subscription for unlimited saved shows and removal of banner ads. Other tracking features remain free. The App Store displays your local price before purchase. Payment is charged to your Apple Account at confirmation and renews monthly unless cancelled at least 24 hours before the period ends. Manage or cancel in your App Store account settings. Restore Purchases recovers an active subscription for the same Apple Account; it does not restore your locally stored library.\n\nIf Premium ends, saved shows and history are preserved. New additions are restricted while the library contains 5 or more shows. Deleting the app or clearing data may remove local records and does not cancel billing.\n\nApple Standard EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
    tr: 'Watchloom kişisel bir dizi takip aracıdır. Üçüncü taraf dizi bilgileri değişebilir veya eksik olabilir.\n\nÜcretsiz sürümde en fazla 5 dizi kaydedebilirsin. Banner reklamlar isteğe bağlıdır; Reklam ve Gizlilik tercihine göre yüklenir. Premium, sınırsız dizi kaydı ve banner reklamların kaldırılması için aylık, otomatik yenilenen bir aboneliktir. Diğer takip özellikleri ücretsizdir. App Store satın almadan önce yerel fiyatı gösterir. Onayda Apple Hesabından ödeme alınır; dönem sonundan en az 24 saat önce iptal edilmezse abonelik her ay yenilenir. App Store hesap ayarlarından yönetebilir veya iptal edebilirsin. Satın Alımları Geri Yükle, aynı Apple Hesabındaki aktif aboneliği geri getirir; cihazında saklanan kütüphaneyi geri getirmez.\n\nPremium bittiğinde kayıtlı diziler ve geçmiş korunur. Kütüphanede 5 veya daha fazla dizi varken yeni kayıt eklenemez. Uygulamayı veya yerel verileri silmek kayıtları kaldırabilir; abonelik ödemesini iptal etmez.\n\nApple Standart EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );

  String get localDataTitle => value(en: 'Local Data', tr: 'Yerel Veriler');

  String get clearAllData =>
      value(en: 'Clear Watch Data', tr: 'İzleme Verilerini Sil');

  String get clearAllDataSubtitle => value(
    en: 'Remove your library, progress, notes, favorites and activity.',
    tr: 'Kütüphaneni, ilerlemeni, notlarını, favorilerini ve etkinliklerini kaldır.',
  );

  String get clearDataConfirmationTitle =>
      value(en: 'Clear all local data?', tr: 'Tüm yerel veriler silinsin mi?');

  String get clearDataConfirmationBody => value(
    en: 'This permanently removes your library, watch progress, favorites, personal notes, activity history, streaks, achievements and scheduled Watchloom notifications. Generated share images are also removed; language and advertising privacy choices are kept. This action cannot be undone. Clearing data does not cancel your Apple subscription. Manage or cancel billing in your Apple Account subscription settings.',
    tr: 'Bu işlem kütüphaneni, izleme ilerlemeni, favorilerini, kişisel notlarını, etkinlik geçmişini, serilerini, başarımlarını ve planlanan Watchloom bildirimlerini kalıcı olarak siler. Oluşturulmuş paylaşım görselleri de kaldırılır; dil ve reklam gizliliği tercihleri korunur. Bu işlem geri alınamaz. Veri silmek Apple aboneliğini iptal etmez. Ödemeyi Apple Hesabı abonelik ayarlarından yönetebilir veya iptal edebilirsin.',
  );

  String get clearDataConfirmAction =>
      value(en: 'Delete Everything', tr: 'Her Şeyi Sil');

  String get clearDataSuccess => value(
    en: 'Your local watch data and generated share images were cleared.',
    tr: 'Yerel izleme verilerin ve oluşturulan paylaşım görselleri silindi.',
  );

  String get clearDataFailed => value(
    en: 'Local data could not be cleared.',
    tr: 'Yerel veriler silinemedi.',
  );

  String get informationTitle => value(en: 'Information', tr: 'Bilgilendirme');
}
