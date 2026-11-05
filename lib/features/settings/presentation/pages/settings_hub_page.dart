import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_settings_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/features/premium/presentation/premium_page.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';
import 'package:watchloom/core/localization/app_legal_strings.dart';
import 'package:watchloom/features/settings/presentation/pages/ad_privacy_page.dart';
import 'package:watchloom/features/settings/presentation/widgets/clear_local_data_tile.dart';
import 'package:watchloom/features/account/presentation/account_page.dart';
import 'package:watchloom/features/settings/presentation/pages/notification_settings_page.dart';

class SettingsHubPage extends StatefulWidget {
  const SettingsHubPage({super.key});

  @override
  State<SettingsHubPage> createState() {
    return _SettingsHubPageState();
  }
}

class _SettingsHubPageState extends State<SettingsHubPage> {
  void _openInformationPage({
    required String title,
    required String body,
    List<LegalLink> links = const [],
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, body: body, links: links),
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
          const AccountTile(),
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
          ListenableBuilder(
            listenable: AppScope.of(context).premiumController,
            builder: (context, _) => _SettingsTile(
              icon: Icons.auto_awesome_rounded,
              title: strings.premiumTitle,
              subtitle: AppScope.of(context).premiumController.hasAccess
                  ? strings.premiumActiveBody
                  : strings.unlimitedShowsBody,
              onTap: () => PremiumPage.open(context),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: strings.adPrivacyTitle,
            subtitle: strings.adPrivacySubtitle,
            onTap: () => AdPrivacyPage.open(context),
          ),
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
                links: LegalPage.sourceLinks(strings),
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
                links: LegalPage.privacyLinks(strings),
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
                links: LegalPage.termsLinks(strings),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.code_rounded,
            title: strings.openSourceLicenses,
            subtitle: strings.licenseAcknowledgements,
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Watchloom',
              applicationVersion: '1.1.0',
            ),
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
          const Card(child: ClearLocalDataTile()),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.accentSoft;

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
                        color: AppColors.textPrimary,
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
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
