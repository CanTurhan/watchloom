import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_settings_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/settings/data/local_data_reset_service.dart';
import 'package:watchloom/features/settings/presentation/pages/notification_settings_page.dart';

class SettingsHubPage extends StatefulWidget {
  const SettingsHubPage({super.key});

  @override
  State<SettingsHubPage> createState() {
    return _SettingsHubPageState();
  }
}

class _SettingsHubPageState extends State<SettingsHubPage> {
  final LocalDataResetService _resetService = const LocalDataResetService();

  bool _clearingData = false;

  Future<void> _clearAllData() async {
    if (_clearingData) {
      return;
    }

    final strings = AppStrings.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 34,
          ),
          title: Text(strings.clearDataConfirmationTitle),
          content: Text(strings.clearDataConfirmationBody),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(strings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(strings.clearDataConfirmAction),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _clearingData = true;
    });

    try {
      await _resetService.clearAllWatchloomData();

      if (!mounted) {
        return;
      }

      final scope = AppScope.of(context);

      await scope.libraryController.load();
      await scope.activityController.load();

      if (!mounted) {
        return;
      }

      _showMessage(strings.clearDataSuccess, Icons.delete_sweep_rounded);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(strings.clearDataFailed, Icons.error_outline_rounded);
    } finally {
      if (mounted) {
        setState(() {
          _clearingData = false;
        });
      }
    }
  }

  void _showMessage(String message, IconData icon) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accentSoft, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _openInformationPage({
    required String title,
    required String body,
    required IconData icon,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _InformationPage(title: title, body: body, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: AppColors.accentSoft,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    strings.settingsSubtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            title: strings.notificationsSettingTitle,
            subtitle: strings.notificationsSettingSubtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.storage_rounded,
            title: strings.dataSourceTitle,
            subtitle: strings.dataSourceSubtitle,
            onTap: () {
              _openInformationPage(
                title: strings.dataSourceTitle,
                body: strings.dataSourceBody,
                icon: Icons.storage_rounded,
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: strings.privacyTitle,
            subtitle: strings.privacySubtitle,
            onTap: () {
              _openInformationPage(
                title: strings.privacyTitle,
                body: strings.privacyBody,
                icon: Icons.privacy_tip_outlined,
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: strings.termsTitle,
            subtitle: strings.termsSubtitle,
            onTap: () {
              _openInformationPage(
                title: strings.termsTitle,
                body: strings.termsBody,
                icon: Icons.description_outlined,
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            strings.localDataTitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: strings.clearAllData,
            subtitle: strings.clearAllDataSubtitle,
            destructive: true,
            trailing: _clearingData
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _clearingData ? null : _clearAllData,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? Colors.redAccent : AppColors.accentSoft;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: foreground, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: destructive
                            ? Colors.redAccent
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: destructive
                        ? Colors.redAccent
                        : AppColors.textSecondary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
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
                  child: Icon(icon, color: AppColors.accentSoft, size: 33),
                ),
                const SizedBox(height: 18),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.65,
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
