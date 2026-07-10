import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';

extension AppActivityStrings on AppStrings {
  String get markNextEpisodeAction =>
      value(en: 'Mark next episode watched', tr: 'Sonraki bölümü izlendi yap');

  String get noNextEpisodeMessage => value(
    en: 'There is no aired episode after your current progress.',
    tr: 'Mevcut ilerlemeden sonra yayınlanmış bölüm bulunmuyor.',
  );

  String get episodeAlreadyLoggedMessage => value(
    en: 'This episode is already in your watch history.',
    tr: 'Bu bölüm izleme geçmişinde zaten kayıtlı.',
  );

  String get episodeLogFailedMessage => value(
    en: 'The episode could not be recorded.',
    tr: 'Bölüm kaydedilemedi.',
  );

  String episodeLoggedMessage(int season, int episode) {
    final seasonText = season.toString().padLeft(2, '0');
    final episodeText = episode.toString().padLeft(2, '0');

    return value(
      en: 'S$seasonText · E$episodeText recorded.',
      tr: 'S$seasonText · B$episodeText izlendi olarak kaydedildi.',
    );
  }

  String get watchTimeLabel => value(en: 'Watch time', tr: 'İzleme süresi');

  String get dailyStreakLabel =>
      value(en: 'Current daily streak', tr: 'Mevcut günlük seri');

  String get bestStreakLabel =>
      value(en: 'Best daily streak', tr: 'En iyi günlük seri');

  String get monthlyStreakLabel =>
      value(en: 'Monthly streak', tr: 'Aylık seri');

  String get dayUnit => value(en: 'days', tr: 'gün');

  String get monthUnit => value(en: 'months', tr: 'ay');

  String get recentActivityTitle =>
      value(en: 'Recent Activity', tr: 'Son Etkinlikler');

  String get noActivityMessage => value(
    en: 'No episodes have been recorded this month.',
    tr: 'Bu ay henüz izlenen bölüm kaydedilmedi.',
  );

  String get activityAchievementsTitle =>
      value(en: 'Achievements', tr: 'Başarımlar');

  String get achievementsThisMonthTitle =>
      value(en: 'Achievements This Month', tr: 'Bu Ay Açılan Başarımlar');

  String get noAchievementsThisMonth => value(
    en: 'No achievement has been unlocked this month.',
    tr: 'Bu ay henüz başarım açılmadı.',
  );

  String get activityTotalEpisodesLabel =>
      value(en: 'Total recorded episodes', tr: 'Toplam kaydedilen bölüm');

  String get activityProfileDescription => value(
    en: 'Track your viewing habits, streaks, and achievements.',
    tr: 'İzleme alışkanlıklarını, serilerini ve başarımlarını takip et.',
  );

  String get activitySettingsDescription => value(
    en: 'Language, legal information, data sources, and app details.',
    tr: 'Dil, yasal bilgiler, veri kaynakları ve uygulama detayları.',
  );

  String monthName(int month) {
    const englishMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    const turkishMonths = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    final index = month.clamp(1, 12).toInt() - 1;

    return isTurkish ? turkishMonths[index] : englishMonths[index];
  }

  String achievementTitle(String code) {
    switch (code) {
      case AchievementCatalog.firstEpisode:
        return value(en: 'Episode One', tr: 'İlk Bölüm');

      case AchievementCatalog.tenEpisodes:
        return value(en: 'Getting Started', tr: 'Başlangıç');

      case AchievementCatalog.fiftyEpisodes:
        return value(en: 'Episode Hunter', tr: 'Bölüm Avcısı');

      case AchievementCatalog.hundredEpisodes:
        return value(en: 'Century Club', tr: 'Yüzler Kulübü');

      case AchievementCatalog.threeDayStreak:
        return value(en: 'Three in a Row', tr: 'Üç Gün Üst Üste');

      case AchievementCatalog.sevenDayStreak:
        return value(en: 'Full Week', tr: 'Tam Bir Hafta');

      case AchievementCatalog.fourteenDayStreak:
        return value(en: 'Two Week Run', tr: 'İki Haftalık Seri');

      case AchievementCatalog.threeMonthStreak:
        return value(en: 'Monthly Habit', tr: 'Aylık Alışkanlık');

      case AchievementCatalog.sixMonthStreak:
        return value(en: 'Half-Year Journey', tr: 'Altı Aylık Yolculuk');

      case AchievementCatalog.twelveMonthStreak:
        return value(en: 'Year of Stories', tr: 'Dizilerle Bir Yıl');

      default:
        return code;
    }
  }

  String achievementDescription(String code) {
    switch (code) {
      case AchievementCatalog.firstEpisode:
        return value(
          en: 'Record your first episode.',
          tr: 'İlk bölümünü kaydet.',
        );

      case AchievementCatalog.tenEpisodes:
        return value(en: 'Record 10 episodes.', tr: '10 bölüm kaydet.');

      case AchievementCatalog.fiftyEpisodes:
        return value(en: 'Record 50 episodes.', tr: '50 bölüm kaydet.');

      case AchievementCatalog.hundredEpisodes:
        return value(en: 'Record 100 episodes.', tr: '100 bölüm kaydet.');

      case AchievementCatalog.threeDayStreak:
        return value(
          en: 'Watch on 3 consecutive days.',
          tr: '3 gün üst üste bölüm izle.',
        );

      case AchievementCatalog.sevenDayStreak:
        return value(
          en: 'Watch on 7 consecutive days.',
          tr: '7 gün üst üste bölüm izle.',
        );

      case AchievementCatalog.fourteenDayStreak:
        return value(
          en: 'Watch on 14 consecutive days.',
          tr: '14 gün üst üste bölüm izle.',
        );

      case AchievementCatalog.threeMonthStreak:
        return value(
          en: 'Record episodes in 3 consecutive months.',
          tr: '3 ay üst üste bölüm kaydet.',
        );

      case AchievementCatalog.sixMonthStreak:
        return value(
          en: 'Record episodes in 6 consecutive months.',
          tr: '6 ay üst üste bölüm kaydet.',
        );

      case AchievementCatalog.twelveMonthStreak:
        return value(
          en: 'Record episodes in 12 consecutive months.',
          tr: '12 ay üst üste bölüm kaydet.',
        );

      default:
        return '';
    }
  }
}
