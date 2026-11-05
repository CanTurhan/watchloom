import 'package:flutter/material.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/core/legal/app_legal.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_legal_strings.dart';
import 'package:watchloom/core/localization/app_settings_strings.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalLink {
  const LegalLink(this.label, this.address);
  final String label;
  final String address;
}

Future<void> openLegalLink(BuildContext context, String address) async {
  try {
    if (await launchUrl(
      Uri.parse(address),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // Keep the policy readable offline even if no browser/mail app is available.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).linkFailed)));
  }
}

class LegalPage extends StatelessWidget {
  const LegalPage({
    required this.title,
    required this.body,
    this.links = const [],
    super.key,
  });

  final String title;
  final String body;
  final List<LegalLink> links;

  static Future<void> openPrivacy(BuildContext context) {
    final strings = AppStrings.of(context);
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LegalPage(
          title: strings.privacyPolicy,
          body: strings.privacyBody,
          links: privacyLinks(strings),
        ),
      ),
    );
  }

  static List<LegalLink> privacyLinks(AppStrings strings) => [
    const LegalLink('Google / Firebase', AppLegal.firebasePrivacy),
    LegalLink(strings.onlinePrivacy, AppLegal.privacy),
    LegalLink(strings.providerPrivacy, AppLegal.yandexPrivacy),
    LegalLink(strings.privacyRequest, AppLegal.contact),
  ];

  static List<LegalLink> termsLinks(AppStrings strings) => [
    LegalLink(strings.subscriptionTerms, AppLegal.appleEula),
    LegalLink(strings.refundSupport, AppLegal.appleRefund),
  ];

  static List<LegalLink> sourceLinks(AppStrings strings) => [
    const LegalLink('TVmaze', AppLegal.tvmaze),
    LegalLink(strings.contentLicense, AppLegal.tvmazeLicense),
    LegalLink(strings.sourceAndLicense, AppLegal.tvmazeApi),
  ];

  static Future<void> openAdReport(BuildContext context) {
    final strings = AppStrings.of(context);
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LegalPage(
          title: strings.reportAd,
          body: strings.reportAdBody,
          links: [LegalLink(strings.contactSupport, AppLegal.contact)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.65,
                ),
              ),
              if (links.isNotEmpty) const SizedBox(height: 20),
              for (final link in links)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => openLegalLink(context, link.address),
                    icon: Icon(
                      link.address.startsWith('mailto:')
                          ? Icons.mail_outline
                          : Icons.open_in_new_rounded,
                    ),
                    label: Text(link.label, textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
