import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

extension AppLibraryStrings on AppStrings {
  String get addToLibrary =>
      value(en: 'Add to Library', tr: 'Kütüphaneye Ekle');

  String get editLibraryEntry =>
      value(en: 'Edit Library Entry', tr: 'Kütüphane Kaydını Düzenle');

  String get save => value(en: 'Save', tr: 'Kaydet');

  String get cancel => value(en: 'Cancel', tr: 'İptal');

  String get remove => value(en: 'Remove', tr: 'Kaldır');

  String get libraryStatus =>
      value(en: 'Library status', tr: 'Kütüphane durumu');

  String get progress => value(en: 'Watch progress', tr: 'İzleme ilerlemesi');

  String get trackProgress =>
      value(en: 'Set last watched episode', tr: 'Son izlenen bölümü belirle');

  String get season => value(en: 'Season', tr: 'Sezon');

  String get episode => value(en: 'Episode', tr: 'Bölüm');

  String get loadingEpisodes =>
      value(en: 'Loading episodes…', tr: 'Bölümler yükleniyor…');

  String get noEpisodes => value(
    en: 'No episode information is available.',
    tr: 'Bölüm bilgisi bulunmuyor.',
  );

  String get couldNotLoadEpisodes =>
      value(en: 'Episodes could not be loaded.', tr: 'Bölümler yüklenemedi.');

  String get savedToLibrary =>
      value(en: 'Library entry saved.', tr: 'Kütüphane kaydı kaydedildi.');

  String get emptyLibraryTitle =>
      value(en: 'Your library is empty', tr: 'Kütüphanen boş');

  String get emptyLibraryDescription => value(
    en: 'Search for a show and add it to your library.',
    tr: 'Bir dizi ara ve kütüphanene ekle.',
  );

  String get searchAndAdd => value(en: 'Search and Add', tr: 'Ara ve Ekle');

  String get all => value(en: 'All', tr: 'Tümü');

  String get notStarted => value(en: 'Not started', tr: 'Başlanmadı');

  String get removeFromLibrary =>
      value(en: 'Remove from Library', tr: 'Kütüphaneden Kaldır');

  String get removeConfirmation => value(
    en: 'Remove this show from your library?',
    tr: 'Bu dizi kütüphaneden kaldırılsın mı?',
  );

  String get showRemoved => value(
    en: 'Show removed from library.',
    tr: 'Dizi kütüphaneden kaldırıldı.',
  );

  String statusName(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.watching:
        return value(en: 'Watching', tr: 'İzleniyor');
      case LibraryStatus.watchlist:
        return value(en: 'Watchlist', tr: 'İzleme Listesi');
      case LibraryStatus.completed:
        return value(en: 'Completed', tr: 'Tamamlandı');
      case LibraryStatus.paused:
        return value(en: 'Paused', tr: 'Bekletiliyor');
      case LibraryStatus.dropped:
        return value(en: 'Dropped', tr: 'Bırakıldı');
    }
  }
}
