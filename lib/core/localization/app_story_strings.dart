import 'package:watchloom/core/localization/app_strings.dart';

extension AppStoryStrings on AppStrings {
  String get shareMonthStory => value(en: 'Share Story', tr: 'Story Paylaş');

  String get storyShareFailed => value(
    en: 'The Story image could not be created.',
    tr: 'Story görseli oluşturulamadı.',
  );

  String get storyCurrentStreak =>
      value(en: 'CURRENT STREAK', tr: 'GÜNCEL SERİ');

  String get storyBestStreak => value(en: 'BEST STREAK', tr: 'EN İYİ SERİ');

  String get storyMonthlyStreak =>
      value(en: 'MONTHLY STREAK', tr: 'AYLIK SERİ');

  String get storyRecentActivity =>
      value(en: 'RECENTLY WATCHED', tr: 'SON İZLENENLER');

  String get storyAchievements => value(en: 'ACHIEVEMENTS', tr: 'BAŞARIMLAR');

  String get storyNoAchievements => value(
    en: 'No achievements unlocked this month',
    tr: 'Bu ay henüz başarım açılmadı',
  );

  String get storyNoActivity => value(
    en: 'No episodes recorded this month',
    tr: 'Bu ay henüz bölüm kaydedilmedi',
  );

  String get madeWithWatchloom =>
      value(en: 'Made with Watchloom', tr: 'Watchloom ile oluşturuldu');
}
