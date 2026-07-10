import 'package:watchloom/core/localization/app_strings.dart';

extension AppNotificationStrings on AppStrings {
  String get notificationSettingsTitle =>
      value(en: 'Episode Notifications', tr: 'Bölüm Bildirimleri');

  String get notificationSettingsDescription => value(
    en: 'Get a reminder before announced episodes of shows in your library are released.',
    tr: 'Kütüphanendeki dizilerin yayın tarihi açıklanan bölümleri çıkmadan önce hatırlatma al.',
  );

  String get enableUpcomingNotifications => value(
    en: 'Upcoming episode notifications',
    tr: 'Yaklaşan bölüm bildirimleri',
  );

  String get notificationsEnabledStatus =>
      value(en: 'Notifications are enabled', tr: 'Bildirimler açık');

  String get notificationsDisabledStatus =>
      value(en: 'Notifications are disabled', tr: 'Bildirimler kapalı');

  String get scheduledNotifications =>
      value(en: 'Scheduled notifications', tr: 'Planlanan bildirimler');

  String get noScheduledNotifications => value(
    en: 'No announced upcoming episodes were found.',
    tr: 'Yayın tarihi açıklanmış yaklaşan bölüm bulunamadı.',
  );

  String get refreshNotificationSchedule =>
      value(en: 'Refresh Schedule', tr: 'Bildirimleri Yenile');

  String get notificationPermissionDenied => value(
    en: 'Notification permission was not granted.',
    tr: 'Bildirim izni verilmedi.',
  );

  String notificationsScheduledMessage(int count) {
    return value(
      en: '$count episode notification(s) scheduled.',
      tr: '$count bölüm bildirimi planlandı.',
    );
  }

  String get notificationsTurnedOff => value(
    en: 'Episode notifications were disabled.',
    tr: 'Bölüm bildirimleri kapatıldı.',
  );

  String get notificationSyncFailed => value(
    en: 'The notification schedule could not be updated.',
    tr: 'Bildirim planı güncellenemedi.',
  );

  String get localNotificationExplanation => value(
    en: 'Watchloom schedules notifications on this device. Open the app occasionally so newly announced episode dates can be discovered.',
    tr: 'Watchloom bildirimleri bu cihazda planlar. Yeni açıklanan bölüm tarihlerinin bulunabilmesi için uygulamayı ara sıra aç.',
  );

  String get openNotificationSettings =>
      value(en: 'Notifications', tr: 'Bildirimler');

  String get sendTestNotification =>
      value(en: 'Send Test Notification', tr: 'Test Bildirimi Gönder');

  String get testNotificationSent => value(
    en: 'Test notification sent. Tap it to open the show.',
    tr: 'Test bildirimi gönderildi. Diziyi açmak için bildirime dokun.',
  );

  String get testNotificationUnavailable => value(
    en: 'Add a show to your library before sending a test notification.',
    tr: 'Test bildirimi göndermeden önce kütüphanene bir dizi ekle.',
  );

  String get reminderTimingTitle =>
      value(en: 'Reminder Time', tr: 'Hatırlatma Zamanı');

  String get reminderTimingSubtitle => value(
    en: 'Choose when Watchloom should remind you before an episode.',
    tr: 'Watchloom’un yeni bölümden ne kadar önce hatırlatacağını seç.',
  );

  String get reminderOneDayBefore =>
      value(en: '1 day before', tr: '1 gün önce');

  String get reminderThreeHoursBefore =>
      value(en: '3 hours before', tr: '3 saat önce');

  String get reminderOneHourBefore =>
      value(en: '1 hour before', tr: '1 saat önce');

  String get reminderAtAirTime =>
      value(en: 'At release time', tr: 'Yayın saatinde');

  String get reminderTimingUpdated =>
      value(en: 'Reminder time updated.', tr: 'Hatırlatma zamanı güncellendi.');
}
