import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_activity_strings.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/settings/presentation/settings_page.dart';
import 'package:watchloom/features/account/presentation/account_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.localeController, super.key});

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final controller = AppScope.of(context).activityController;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.profile,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: strings.settings,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SettingsPage(localeController: localeController),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                strings.activityProfileDescription,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              const AccountTile(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.local_fire_department_rounded,
                      value: '${controller.currentDailyStreak}',
                      label: strings.dailyStreakLabel,
                      iconColor: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.calendar_month_rounded,
                      value: '${controller.currentMonthlyStreak}',
                      label: strings.monthlyStreakLabel,
                      iconColor: AppColors.accentSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatisticCard(
                icon: Icons.playlist_play_rounded,
                value: '${controller.totalEpisodes}',
                label: strings.activityTotalEpisodesLabel,
                iconColor: const Color(0xFF4ADE80),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.activityAchievementsTitle,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${controller.unlockedAchievements.length}/'
                    '${AchievementCatalog.codes.length}',
                    style: const TextStyle(
                      color: AppColors.accentSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...AchievementCatalog.codes.map(
                (code) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AchievementCard(
                    title: strings.achievementTitle(code),
                    description: strings.achievementDescription(code),
                    unlocked: controller.isAchievementUnlocked(code),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.settings_rounded,
                    color: AppColors.accentSoft,
                  ),
                  title: Text(strings.settings),
                  subtitle: Text(strings.activitySettingsDescription),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SettingsPage(localeController: localeController),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    height: 1.3,
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

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final String title;
  final String description;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.48,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(
                  alpha: unlocked ? 0.16 : 0.07,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                unlocked
                    ? Icons.emoji_events_rounded
                    : Icons.lock_outline_rounded,
                color: unlocked ? AppColors.yellow : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 13),
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
            Icon(
              unlocked
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: unlocked
                  ? const Color(0xFF4ADE80)
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
