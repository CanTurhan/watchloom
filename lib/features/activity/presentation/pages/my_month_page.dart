import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_activity_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_story_strings.dart';
import 'package:watchloom/core/localization/app_recap_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/core/widgets/app_page_header.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/presentation/widgets/monthly_activity_summary_card.dart';

class MyMonthPage extends StatefulWidget {
  const MyMonthPage({this.onShare, this.isSharing = false, super.key});
  final VoidCallback? onShare;
  final bool isSharing;

  @override
  State<MyMonthPage> createState() => _MyMonthPageState();
}

class _MyMonthPageState extends State<MyMonthPage> {
  int _period = 1;
  DateTime _date = DateTime.now();

  void _move(int delta) =>
      setState(() => _date = moveRecapPeriod(_date, _period, delta));

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final controller = AppScope.of(context).activityController;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          final start = switch (_period) {
            0 => DateTime(_date.year, _date.month, _date.day),
            2 => DateTime(_date.year),
            _ => DateTime(_date.year, _date.month),
          };
          final end = switch (_period) {
            0 => DateTime(start.year, start.month, start.day + 1),
            2 => DateTime(start.year + 1),
            _ => DateTime(start.year, start.month + 1),
          };
          final summary = controller.summaryForRange(start, end);
          final monthLogs = summary.logs;
          final achievements = controller.unlockedAchievements.where((
            achievement,
          ) {
            final local = achievement.unlockedAt.toLocal();
            final date = DateTime(local.year, local.month, local.day);
            return !date.isBefore(start) &&
                date.isBefore(end) &&
                !achievement.unlockedAt.isAfter(DateTime.now());
          }).toList();

          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                AppPageHeader(
                  title: _period == 0
                      ? strings.value(en: 'My Day', tr: 'Günüm')
                      : _period == 2
                      ? strings.value(en: 'My Year', tr: 'Yılım')
                      : strings.myMonth,
                  action:
                      _period != 1 ||
                          _date.year != DateTime.now().year ||
                          _date.month != DateTime.now().month ||
                          (widget.onShare == null && !widget.isSharing)
                      ? null
                      : IconButton.filledTonal(
                          tooltip: strings.shareMonthStory,
                          onPressed: widget.onShare,
                          icon: widget.isSharing
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.ios_share_rounded),
                        ),
                  eyebrow: _period == 2
                      ? '${summary.year}'
                      : _period == 0
                      ? '${start.day} ${strings.monthName(start.month)} ${start.year}'
                      : '${strings.monthName(summary.month)} ${summary.year}',
                  subtitle: strings.isTurkish
                      ? 'Dizi ve film izleme etkinliklerin.'
                      : 'Your series and movie viewing activity.',
                ),
                const SizedBox(height: 24),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(strings.value(en: 'Daily', tr: 'Günlük')),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(strings.value(en: 'Monthly', tr: 'Aylık')),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(strings.value(en: 'Yearly', tr: 'Yıllık')),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (values) =>
                      setState(() => _period = values.single),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: strings.value(
                        en: 'Previous period',
                        tr: 'Önceki dönem',
                      ),
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Tooltip(
                        message: strings.recapResetLabel(_period),
                        child: TextButton(
                          key: const ValueKey('recap-period-label'),
                          onPressed: () =>
                              setState(() => _date = DateTime.now()),
                          child: Text(
                            strings.recapPeriodLabel(
                              _date,
                              _period,
                              DateTime.now(),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: strings.value(
                        en: 'Next period',
                        tr: 'Sonraki dönem',
                      ),
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                GestureDetector(
                  key: const ValueKey('recap-swipe-period'),
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() > 150) _move(velocity < 0 ? 1 : -1);
                  },
                  child: MonthlyActivitySummaryCard(summary: summary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StreakCard(
                        icon: Icons.local_fire_department_rounded,
                        value: controller.currentDailyStreak,
                        suffix: strings.dayUnit,
                        label: strings.dailyStreakLabel,
                        iconColor: AppColors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StreakCard(
                        icon: Icons.calendar_month_rounded,
                        value: controller.currentMonthlyStreak,
                        suffix: strings.monthUnit,
                        label: strings.monthlyStreakLabel,
                        iconColor: AppColors.accentSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _WideStreakCard(
                  icon: Icons.workspace_premium_rounded,
                  value: controller.bestDailyStreak,
                  suffix: strings.dayUnit,
                  label: strings.bestStreakLabel,
                ),
                const SizedBox(height: 28),
                Text(
                  _period == 1
                      ? strings.achievementsThisMonthTitle
                      : strings.value(
                          en: 'Achievements in this period',
                          tr: 'Bu dönemdeki başarımlar',
                        ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (achievements.isEmpty)
                  _EmptyCard(
                    icon: Icons.emoji_events_outlined,
                    text: strings.value(
                      en: 'No achievements in this period.',
                      tr: 'Bu dönemde açılan başarım yok.',
                    ),
                  )
                else
                  ...achievements.map(
                    (achievement) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AchievementCard(
                        title: strings.achievementTitle(achievement.code),
                        description: strings.achievementDescription(
                          achievement.code,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  strings.recentActivityTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (monthLogs.isEmpty)
                  _EmptyCard(
                    icon: Icons.history_rounded,
                    text: strings.value(
                      en: 'No viewing activity in this period.',
                      tr: 'Bu dönemde izleme kaydı yok.',
                    ),
                  )
                else
                  ...monthLogs
                      .take(30)
                      .map(
                        (log) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActivityCard(log: log),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.icon,
    required this.value,
    required this.suffix,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final int value;
  final String suffix;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 145),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 24),
          Text(
            '$value $suffix',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _WideStreakCard extends StatelessWidget {
  const _WideStreakCard({
    required this.icon,
    required this.value,
    required this.suffix,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String suffix;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: AppColors.yellow),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '$value $suffix',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.log});

  final EpisodeWatchLog log;

  @override
  Widget build(BuildContext context) {
    final date = log.watchedAt.toLocal();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF4ADE80)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.showName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  log.episodeCode,
                  style: const TextStyle(
                    color: AppColors.accentSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.yellow),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
