import 'package:watchloom/core/localization/app_strings.dart';

extension AppMonetizationStrings on AppStrings {
  String get watchloomProTitle =>
      value(en: 'Watchloom Pro', tr: 'Watchloom Pro');

  String get watchloomProSubtitle => value(
    en: 'Remove banner ads permanently.',
    tr: 'Banner reklamları kalıcı olarak kaldır.',
  );

  String get watchloomProDescription => value(
    en: 'Upgrade once and enjoy Watchloom without banner ads. This is a permanent, non-subscription purchase.',
    tr: 'Tek seferlik yükseltmeyle Watchloom’u banner reklamsız kullan. Bu kalıcı bir satın almadır ve abonelik değildir.',
  );

  String get watchloomProActive =>
      value(en: 'Watchloom Pro is active', tr: 'Watchloom Pro aktif');

  String get watchloomProActiveDescription => value(
    en: 'Banner ads have been removed from this device.',
    tr: 'Banner reklamları bu cihazdan kaldırıldı.',
  );

  String buyWatchloomPro(String price) =>
      value(en: 'Remove Ads · $price', tr: 'Reklamları Kaldır · $price');

  String get restorePurchases =>
      value(en: 'Restore Purchases', tr: 'Satın Alımları Geri Yükle');

  String get purchaseStarted => value(
    en: 'Complete the purchase in the App Store window.',
    tr: 'Satın alma işlemini App Store penceresinde tamamla.',
  );

  String get purchaseUnavailable => value(
    en: 'Watchloom Pro is not available from the App Store yet.',
    tr: 'Watchloom Pro henüz App Store üzerinden kullanılamıyor.',
  );

  String get storeUnavailable => value(
    en: 'The App Store could not be reached.',
    tr: 'App Store’a ulaşılamadı.',
  );

  String get purchaseRestored => value(
    en: 'Purchase restore request completed.',
    tr: 'Satın alma geri yükleme isteği tamamlandı.',
  );

  String get purchaseFailed => value(
    en: 'The purchase could not be completed.',
    tr: 'Satın alma tamamlanamadı.',
  );

  String get oneTimePurchase => value(
    en: 'One-time purchase · No subscription',
    tr: 'Tek seferlik satın alma · Abonelik yok',
  );

  String get privacyChoicesTitle =>
      value(en: 'Ad Privacy Choices', tr: 'Reklam Gizlilik Tercihleri');

  String get privacyChoicesSubtitle => value(
    en: 'Review or change your advertising consent choices.',
    tr: 'Reklam onayı tercihlerini görüntüle veya değiştir.',
  );

  String get privacyOptionsUnavailable => value(
    en: 'Privacy choices are not required for this device.',
    tr: 'Bu cihaz için ek gizlilik tercihi gerekmiyor.',
  );
}
