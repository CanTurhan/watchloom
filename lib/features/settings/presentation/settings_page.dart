import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_settings_strings.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/features/premium/presentation/premium_page.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';
import 'package:watchloom/core/legal/app_legal.dart';
import 'package:watchloom/core/localization/app_legal_strings.dart';
import 'package:watchloom/features/settings/presentation/pages/ad_privacy_page.dart';
import 'package:watchloom/features/settings/presentation/widgets/clear_local_data_tile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.localeController, super.key});

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isTurkish = strings.isTurkish;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ListenableBuilder(
            listenable: AppScope.of(context).premiumController,
            builder: (context, _) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.accentSoft,
                ),
                title: Text(strings.premiumTitle),
                subtitle: Text(
                  AppScope.of(context).premiumController.hasAccess
                      ? strings.premiumActiveBody
                      : strings.unlimitedShowsBody,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => PremiumPage.open(context),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: strings.adPrivacyTitle,
              subtitle: strings.adPrivacySubtitle,
              onTap: () => AdPrivacyPage.open(context),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(strings.general),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.language_rounded,
                    color: AppColors.accentSoft,
                  ),
                  title: Text(strings.language),
                  subtitle: Text(
                    localeController.locale.languageCode == 'tr'
                        ? strings.turkish
                        : strings.english,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showLanguageSelector(context, strings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(strings.legal),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: strings.privacyPolicy,
                  onTap: () => _openTextPage(
                    context,
                    strings.privacyPolicy,
                    strings.privacyBody,
                    links: LegalPage.privacyLinks(strings),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: strings.termsOfUse,
                  onTap: () => _openTextPage(
                    context,
                    strings.termsOfUse,
                    strings.termsBody,
                    links: LegalPage.termsLinks(strings),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.storage_rounded,
                  title: strings.dataSources,
                  onTap: () => _openTextPage(
                    context,
                    strings.dataSources,
                    strings.dataSourceBody,
                    links: LegalPage.sourceLinks(strings),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.code_rounded,
                  title: strings.openSourceLicenses,
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Watchloom',
                      applicationVersion: '1.1.0',
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: strings.helpSupport,
                  onTap: () => _openTextPage(
                    context,
                    strings.helpSupport,
                    isTurkish ? _supportTr : _supportEn,
                    links: [
                      LegalLink(strings.contactSupport, AppLegal.contact),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: strings.about,
                  subtitle: '${strings.version} 1.1.0',
                  onTap: () => _openTextPage(
                    context,
                    strings.about,
                    isTurkish ? _aboutTr : _aboutEn,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(strings.localDataTitle),
          const Card(child: ClearLocalDataTile()),
        ],
      ),
    );
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    AppStrings strings,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        final currentLanguage = localeController.locale.languageCode;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(strings.english),
                  leading: const Text(
                    'EN',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: currentLanguage == 'en'
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accentSoft,
                        )
                      : null,
                  onTap: () async {
                    await localeController.setLanguage('en');

                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
                ListTile(
                  title: Text(strings.turkish),
                  leading: const Text(
                    'TR',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: currentLanguage == 'tr'
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accentSoft,
                        )
                      : null,
                  onTap: () async {
                    await localeController.setLanguage('tr');

                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTextPage(
    BuildContext context,
    String title,
    String body, {
    List<LegalLink> links = const [],
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, body: body, links: links),
      ),
    );
  }

  static const String _supportEn = '''
Watchloom support: https://canturhan.github.io/watchloom/support.html

Before reporting a problem, note the screen where it occurred, the steps that caused it and the device or iOS version being used.

For purchase issues, include the message shown by the App Store. Never share your Apple Account password or payment details.
''';

  static const String _supportTr = '''
Watchloom destek: https://canturhan.github.io/watchloom/support.html

Bir sorun bildirirken sorunun görüldüğü ekranı, sorunu oluşturan adımları ve kullanılan cihaz veya iOS sürümünü not edin.

Satın alma sorunlarında App Store mesajını ekleyin. Apple Hesabı parolanızı veya ödeme bilgilerinizi paylaşmayın.
''';

  static const String _aboutEn = '''
Watchloom helps users remember where they stopped, review the last watched episode, follow known upcoming releases and turn their monthly viewing activity into a shareable visual diary.

The application is designed to work without a user account or Firebase.
''';

  static const String _aboutTr = '''
Watchloom; kullanıcıların hangi bölümde kaldığını hatırlamasına, son izlenen bölümü gözden geçirmesine, açıklanmış gelecek yayınları takip etmesine ve aylık izleme geçmişini paylaşılabilir görsel bir günlüğe dönüştürmesine yardımcı olur.

Uygulama kullanıcı hesabı ve Firebase gerektirmeden çalışacak şekilde tasarlanmıştır.
''';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accentSoft,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accentSoft),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
