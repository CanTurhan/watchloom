import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_notification_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/notifications/upcoming_episode_notification_service.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() {
    return _NotificationSettingsPageState();
  }
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _enabled = false;
  bool _loading = true;
  bool _busy = false;
  int _scheduledCount = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final service = UpcomingEpisodeNotificationService.instance;

    final enabled = await service.isEnabled;
    final count = await service.scheduledCount;

    if (!mounted) {
      return;
    }

    setState(() {
      _enabled = enabled;
      _scheduledCount = count;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    final strings = AppStrings.of(context);

    try {
      final service = UpcomingEpisodeNotificationService.instance;

      if (!value) {
        await service.disable();

        if (!mounted) {
          return;
        }

        setState(() {
          _enabled = false;
          _scheduledCount = 0;
        });

        _showMessage(strings.notificationsTurnedOff);

        return;
      }

      final scope = AppScope.of(context);

      final result = await service.enableAndSync(
        entries: scope.libraryController.entries.toList(),
        isTurkish: Localizations.localeOf(context).languageCode == 'tr',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = result.permissionGranted;
        _scheduledCount = result.scheduledCount;
      });

      _showMessage(
        result.permissionGranted
            ? strings.notificationsScheduledMessage(result.scheduledCount)
            : strings.notificationPermissionDenied,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(strings.notificationSyncFailed);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshSchedule() async {
    if (_busy || !_enabled) {
      return;
    }

    setState(() {
      _busy = true;
    });

    final strings = AppStrings.of(context);

    try {
      final scope = AppScope.of(context);

      final count = await UpcomingEpisodeNotificationService.instance
          .syncIfEnabled(
            entries: scope.libraryController.entries.toList(),
            isTurkish: Localizations.localeOf(context).languageCode == 'tr',
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _scheduledCount = count;
      });

      _showMessage(strings.notificationsScheduledMessage(count));
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(strings.notificationSyncFailed);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _sendTestNotification() async {
    if (_busy || !_enabled) {
      return;
    }

    final strings = AppStrings.of(context);
    final entries = AppScope.of(context).libraryController.entries.toList();

    if (entries.isEmpty) {
      _showMessage(strings.testNotificationUnavailable);
      return;
    }

    LibraryEntry entry = entries.first;

    for (final candidate in entries) {
      if (candidate.status != LibraryStatus.completed &&
          candidate.status != LibraryStatus.dropped) {
        entry = candidate;
        break;
      }
    }

    setState(() {
      _busy = true;
    });

    try {
      final sent = await UpcomingEpisodeNotificationService.instance
          .showTestNotification(
            entry: entry,
            isTurkish: Localizations.localeOf(context).languageCode == 'tr',
          );

      if (!mounted) {
        return;
      }

      _showMessage(
        sent ? strings.testNotificationSent : strings.notificationSyncFailed,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(strings.notificationSyncFailed);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: AppColors.accentSoft,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.notificationSettingsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.accentSoft,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.notificationSettingsDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SwitchListTile(
                    value: _enabled,
                    onChanged: _busy ? null : _toggle,
                    title: Text(strings.enableUpcomingNotifications),
                    subtitle: Text(
                      _enabled
                          ? strings.notificationsEnabledStatus
                          : strings.notificationsDisabledStatus,
                    ),
                    secondary: Icon(
                      _enabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      color: _enabled
                          ? AppColors.accentSoft
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.accentSoft,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.scheduledNotifications,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _scheduledCount == 0
                                  ? strings.noScheduledNotifications
                                  : strings.notificationsScheduledMessage(
                                      _scheduledCount,
                                    ),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$_scheduledCount',
                        style: const TextStyle(
                          color: AppColors.accentSoft,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !_enabled || _busy ? null : _refreshSchedule,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(strings.refreshNotificationSchedule),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: !_enabled || _busy
                        ? null
                        : _sendTestNotification,
                    icon: const Icon(Icons.notification_add_outlined),
                    label: Text(strings.sendTestNotification),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  strings.localNotificationExplanation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }
}
