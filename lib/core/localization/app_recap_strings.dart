import 'app_strings.dart';
import 'app_activity_strings.dart';

DateTime moveRecapPeriod(DateTime date, int period, int delta) {
  if (period == 0) return DateTime(date.year, date.month, date.day + delta);
  final target = period == 2
      ? DateTime(date.year + delta, date.month)
      : DateTime(date.year, date.month + delta);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

extension AppRecapStrings on AppStrings {
  String recapPeriodLabel(DateTime selected, int period, DateTime now) {
    final day = DateTime(selected.year, selected.month, selected.day);
    final today = DateTime(now.year, now.month, now.day);
    if (period == 0) {
      if (day == today) return value(en: 'Today', tr: 'Bugün');
      if (day == DateTime(now.year, now.month, now.day - 1)) {
        return value(en: 'Yesterday', tr: 'Dün');
      }
      if (day == DateTime(now.year, now.month, now.day + 1)) {
        return value(en: 'Tomorrow', tr: 'Yarın');
      }
      return isTurkish
          ? '${day.day} ${monthName(day.month)} ${day.year}'
          : '${monthName(day.month)} ${day.day}, ${day.year}';
    }
    if (period == 1) {
      if (selected.year == now.year && selected.month == now.month) {
        return value(en: 'This month', tr: 'Bu ay');
      }
      final month = monthName(selected.month);
      return selected.year == now.year
          ? value(en: month, tr: '$month ayı')
          : '$month ${selected.year}';
    }
    return selected.year == now.year
        ? value(
            en: 'This year · ${selected.year}',
            tr: 'Bu yıl · ${selected.year}',
          )
        : '${selected.year}';
  }

  String recapResetLabel(int period) => period == 0
      ? value(en: 'Back to today', tr: 'Bugüne dön')
      : period == 1
      ? value(en: 'Back to this month', tr: 'Bu aya dön')
      : value(en: 'Back to this year', tr: 'Bu yıla dön');
}
