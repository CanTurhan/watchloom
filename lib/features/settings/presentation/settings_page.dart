import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';

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
                    isTurkish ? _privacyPolicyTr : _privacyPolicyEn,
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: strings.termsOfUse,
                  onTap: () => _openTextPage(
                    context,
                    strings.termsOfUse,
                    isTurkish ? _termsTr : _termsEn,
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.storage_rounded,
                  title: strings.dataSources,
                  onTap: () => _openTextPage(
                    context,
                    strings.dataSources,
                    isTurkish ? _dataSourcesTr : _dataSourcesEn,
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
                      applicationVersion: '0.1.0',
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
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: strings.about,
                  subtitle: '${strings.version} 0.1.0',
                  onTap: () => _openTextPage(
                    context,
                    strings.about,
                    isTurkish ? _aboutTr : _aboutEn,
                  ),
                ),
              ],
            ),
          ),
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

  void _openTextPage(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, body: body),
      ),
    );
  }

  static const String _privacyPolicyEn = '''
Watchloom does not require an account.

Language preferences and, when implemented, watch history, notes, streaks and achievements are stored locally on the device.

Watchloom does not currently sell personal data or provide user information to advertisers.

When TV metadata features are enabled, searches and metadata requests may be sent to the selected third-party data provider. That provider may process standard network information required to answer the request.

Deleting the app may remove locally stored Watchloom data unless a backup feature is used.

This policy will be updated before the public App Store release when advertising, analytics, purchases and external data integrations are finalized.
''';

  static const String _privacyPolicyTr = '''
Watchloom kullanmak için hesap oluşturulması gerekmez.

Dil tercihi ve ileride eklenecek izleme geçmişi, notlar, seriler ve başarımlar cihaz üzerinde yerel olarak saklanır.

Watchloom şu anda kişisel verileri satmaz ve kullanıcı bilgilerini reklamverenlerle paylaşmaz.

Dizi verisi özellikleri etkinleştirildiğinde arama ve içerik istekleri seçilen üçüncü taraf veri sağlayıcısına gönderilebilir. Bu sağlayıcı, isteği yanıtlamak için gerekli standart ağ bilgilerini işleyebilir.

Bir yedekleme kullanılmadığı takdirde uygulamanın silinmesi cihazda saklanan Watchloom verilerini de silebilir.

Reklam, analiz, satın alma ve harici veri bağlantıları kesinleştiğinde bu politika App Store yayını öncesinde güncellenecektir.
''';

  static const String _termsEn = '''
Watchloom is a personal television tracking and journaling application.

Information about shows, episodes and release dates may be incomplete, delayed or changed by third-party data providers and broadcasters.

Upcoming episode dates are informational and should not be treated as guaranteed release schedules.

Users are responsible for the notes and content they enter into the application.

Watchloom may change, remove or add features during development. The current build is a development version and is not a final commercial release.
''';

  static const String _termsTr = '''
Watchloom kişisel dizi takibi ve izleme günlüğü uygulamasıdır.

Diziler, bölümler ve yayın tarihleri hakkındaki bilgiler üçüncü taraf veri sağlayıcıları veya yayıncılar nedeniyle eksik, gecikmeli ya da değişmiş olabilir.

Gelecek bölüm tarihleri yalnızca bilgilendirme amaçlıdır ve kesin yayın garantisi olarak kabul edilmemelidir.

Kullanıcılar uygulamaya ekledikleri notlardan ve içeriklerden sorumludur.

Watchloom geliştirme süresince özellik ekleyebilir, kaldırabilir veya değiştirebilir. Mevcut sürüm geliştirme sürümüdür ve nihai ticari yayın değildir.
''';

  static const String _dataSourcesEn = '''
Watchloom plans to use TVMaze for television show, season, episode, image and schedule metadata.

TVMaze attribution and the required source links will be included in the final application.

User-created notes, watch progress, ratings, streaks and achievements belong to the local Watchloom database and are not supplied by TVMaze.

Release dates are displayed only when the data provider has a known date. Watchloom will not invent an unknown release date.
''';

  static const String _dataSourcesTr = '''
Watchloom; dizi, sezon, bölüm, görsel ve yayın takvimi verileri için TVMaze kullanmayı planlamaktadır.

Nihai uygulamada gerekli TVMaze kaynak gösterimi ve bağlantıları bulunacaktır.

Kullanıcının oluşturduğu notlar, izleme ilerlemesi, puanlar, seriler ve başarımlar Watchloom'un yerel veritabanına aittir ve TVMaze tarafından sağlanmaz.

Yayın tarihleri yalnızca veri sağlayıcısında bilinen bir tarih bulunduğunda gösterilir. Watchloom bilinmeyen bir yayın tarihi üretmez.
''';

  static const String _supportEn = '''
Watchloom is currently in development.

Before reporting a problem, note the screen where it occurred, the steps that caused it and the device or iOS version being used.

A permanent support address and support website will be added before App Store publication.
''';

  static const String _supportTr = '''
Watchloom şu anda geliştirme aşamasındadır.

Bir sorun bildirirken sorunun görüldüğü ekranı, sorunu oluşturan adımları ve kullanılan cihaz veya iOS sürümünü not edin.

Kalıcı destek e-posta adresi ve destek sitesi App Store yayını öncesinde eklenecektir.
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
