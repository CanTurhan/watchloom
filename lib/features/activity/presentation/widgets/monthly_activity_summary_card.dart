import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/activity/domain/entities/watch_activity_summary.dart';

class MonthlyActivitySummaryCard extends StatelessWidget {
  const MonthlyActivitySummaryCard({required this.summary, super.key});
  final WatchActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final tr = AppStrings.of(context).isTurkish;
    final duration = summary.duration;
    final components = <String>[
      if (duration.days > 0) '${duration.days} ${tr ? 'gün' : 'd'}',
      if (duration.hours > 0) '${duration.hours} ${tr ? 'sa' : 'h'}',
      if (duration.minutes > 0 || duration.isZero)
        '${duration.minutes} ${tr ? 'dk' : 'm'}',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF292143), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timelapse_rounded,
                  color: AppColors.accentSoft,
                  size: 22,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    tr ? 'Toplam izleme süresi' : 'Total watch time',
                    style: const TextStyle(
                      color: AppColors.accentSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              components.join(' '),
              key: const ValueKey('monthly-watch-duration'),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tr
                  ? '${summary.knownWatchMinutes} dakika · ${duration.totalHours} tam saat'
                  : '${summary.knownWatchMinutes} minutes · ${duration.totalHours} whole hours',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (summary.hasIncompleteDuration) ...[
              const SizedBox(height: 10),
              Text(
                tr
                    ? '${summary.unknownRuntimeCount} bölümün süresi bilinmediğinden toplama dahil edilmedi.'
                    : '${summary.unknownRuntimeCount} episodes have no known runtime and are excluded from watch time.',
                key: const ValueKey('monthly-unknown-runtime'),
                style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow =
                    constraints.maxWidth < 250 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final width = narrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 20) / 3;
                return Wrap(
                  spacing: 10,
                  runSpacing: 18,
                  children: [
                    _Metric(
                      width: width,
                      value: summary.episodeCount,
                      label: tr ? 'İzlenen bölüm' : 'Episodes watched',
                      icon: Icons.play_circle_outline_rounded,
                    ),
                    _Metric(
                      width: width,
                      value: summary.seriesCount,
                      label: tr ? 'Farklı dizi' : 'Distinct series',
                      icon: Icons.video_library_outlined,
                    ),
                    _Metric(
                      width: width,
                      value: summary.activeDayCount,
                      label: tr ? 'Aktif izleme günü' : 'Active watch days',
                      icon: Icons.event_available_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              tr
                  ? 'Dizi sayısı, bu ay en az bir bölümünü izlediğin farklı dizileri gösterir. Aktif günler takvim günleridir; süre içindeki günler 24 saattir.'
                  : 'Series are distinct titles with an episode watched this month. Active days are calendar days; days in the duration equal 24 hours.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
  });
  final double width;
  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (width > 180) ...[
          Icon(icon, size: 20, color: AppColors.accentSoft),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
