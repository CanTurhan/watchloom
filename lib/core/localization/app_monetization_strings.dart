import 'package:watchloom/core/localization/app_strings.dart';

extension AppMonetizationStrings on AppStrings {
  String get premiumTitle => 'Watchloom Premium';
  String get premiumHeadline =>
      value(en: 'Make room for every story.', tr: 'Her hikâyeye yer aç.');
  String get premiumSubtitle => value(
    en: 'Your next favorite deserves a place in your library.',
    tr: 'Sıradaki favorinin kütüphanende bir yeri olsun.',
  );
  String get unlimitedShows =>
      value(en: 'An unlimited library', tr: 'Sınırsız dizi kütüphanesi');
  String get unlimitedShowsBody => value(
    en: 'Save and track as many shows as you like.',
    tr: 'Dilediğin kadar dizi kaydet ve takip et.',
  );
  String get noAds =>
      value(en: 'An ad-free experience', tr: 'Reklamsız deneyim');
  String get noAdsBody => value(
    en: 'Enjoy Watchloom without banner ads.',
    tr: 'Watchloom’u banner reklamlar olmadan kullan.',
  );
  String get freeFeaturesRemain => value(
    en: 'Free includes 5 saved shows. Progress, reminders, notes, favorites and statistics stay available on both plans.',
    tr: 'Ücretsiz planda 5 dizi kaydedebilirsin. İlerleme, hatırlatmalar, notlar, favoriler ve istatistikler her iki planda da açık.',
  );
  String get monthlyPlan =>
      value(en: 'Monthly subscription', tr: 'Aylık abonelik');
  String perMonth(String price) =>
      value(en: '$price / month', tr: '$price / ay');
  String subscribeMonthly(String price) =>
      value(en: 'Subscribe · $price / month', tr: 'Abone Ol · $price / ay');
  String get renewalTerms => value(
    en: 'Payment is charged to your Apple Account at confirmation. Your subscription renews monthly unless cancelled at least 24 hours before the current period ends. Manage or cancel in your App Store account settings.',
    tr: 'Ödeme, onayladığında Apple Hesabından alınır. Dönem bitiminden en az 24 saat önce iptal etmezsen aboneliğin her ay yenilenir. App Store hesap ayarlarından yönetebilir veya iptal edebilirsin.',
  );
  String get premiumActive =>
      value(en: 'Premium is active', tr: 'Premium aktif');
  String get premiumActiveBody => value(
    en: 'Your library has no limit, and banner ads are removed.',
    tr: 'Kütüphanende sınır yok ve banner reklamlar kaldırıldı.',
  );
  String accessThrough(String date) =>
      value(en: 'Access through $date', tr: '$date tarihine kadar erişim');
  String renewsOn(String date) =>
      value(en: 'Renews on $date', tr: 'Yenilenme: $date');
  String get manageSubscription =>
      value(en: 'Manage Subscription', tr: 'Aboneliği Yönet');
  String get restorePurchases =>
      value(en: 'Restore Purchases', tr: 'Satın Alımları Geri Yükle');
  String get privacyPolicy =>
      value(en: 'Privacy Policy', tr: 'Gizlilik Politikası');
  String get subscriptionTerms =>
      value(en: 'Terms of Use (EULA)', tr: 'Kullanım Koşulları (EULA)');
  String get storeLoading => value(
    en: 'Getting the App Store price…',
    tr: 'App Store fiyatı alınıyor…',
  );
  String get accessChecking => value(
    en: 'Checking your subscription…',
    tr: 'Aboneliğin kontrol ediliyor…',
  );
  String get storeUnavailable => value(
    en: 'The App Store price is unavailable. Check your connection and try again.',
    tr: 'App Store fiyatı alınamadı. Bağlantını kontrol edip tekrar dene.',
  );
  String get accessCheckFailed => value(
    en: 'Your subscription could not be verified. Try again or restore your purchases.',
    tr: 'Aboneliğin doğrulanamadı. Tekrar dene veya satın alımlarını geri yükle.',
  );
  String get retryStore => value(en: 'Try Again', tr: 'Tekrar Dene');
  String get purchaseFailed => value(
    en: 'The purchase could not be completed. Please try again.',
    tr: 'Satın alma tamamlanamadı. Lütfen tekrar dene.',
  );
  String get purchasePending => value(
    en: 'Your purchase is awaiting Apple’s approval. Premium will open when it is confirmed.',
    tr: 'Satın alma Apple onayı bekliyor. Onaylandığında Premium açılacak.',
  );
  String get purchaseRestored => value(
    en: 'Your Premium subscription was restored.',
    tr: 'Premium aboneliğin geri yüklendi.',
  );
  String get nothingToRestore => value(
    en: 'No active Premium subscription was found for this Apple Account.',
    tr: 'Bu Apple Hesabında aktif Premium aboneliği bulunamadı.',
  );
  String get restoreFailed => value(
    en: 'Purchases could not be restored. Please try again.',
    tr: 'Satın alımlar geri yüklenemedi. Lütfen tekrar dene.',
  );
  String get linkFailed => value(
    en: 'The page could not be opened. Please try again.',
    tr: 'Sayfa açılamadı. Lütfen tekrar dene.',
  );
  String get iosPurchaseOnly => value(
    en: 'Premium subscriptions are available in the iOS app.',
    tr: 'Premium abonelik iOS uygulamasında kullanılabilir.',
  );
  String get libraryLimitTitle =>
      value(en: 'Your free library is full', tr: 'Ücretsiz kütüphanen doldu');
  String get libraryLimitBody => value(
    en: 'Keep up to 5 shows for free, or go Premium for an unlimited library and no ads. You can also remove a show to make space.',
    tr: 'Ücretsiz olarak 5 dizi saklayabilir veya sınırsız kütüphane ve reklamsız kullanım için Premium’a geçebilirsin. Yer açmak için bir dizi de kaldırabilirsin.',
  );
  String get existingLibrarySafe => value(
    en: 'Your saved shows and watch history stay on this device if your subscription ends. Adding new shows requires Premium when your library has 5 or more shows.',
    tr: 'Aboneliğin bittiğinde kayıtlı dizilerin ve izleme geçmişin cihazında kalır. Kütüphanende 5 veya daha fazla dizi varken yeni dizi eklemek için Premium gerekir.',
  );
  String freeLibraryUsage(int count) =>
      value(en: '$count / 5 shows · Free', tr: '$count / 5 dizi · Ücretsiz');
  String get seePremium => value(en: 'Explore Premium', tr: 'Premium’u Keşfet');
  String get librarySaveFailed => value(
    en: 'Your show could not be saved. Please try again.',
    tr: 'Dizi kaydedilemedi. Lütfen tekrar dene.',
  );
  String get advertisement => value(en: 'Advertisement', tr: 'Reklam');
}
