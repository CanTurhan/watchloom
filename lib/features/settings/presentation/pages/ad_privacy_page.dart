import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/legal/app_legal.dart';
import 'package:watchloom/core/localization/app_legal_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';

class AdPrivacyPage extends StatelessWidget {
  const AdPrivacyPage({this.closeAfterChoice = false, super.key});
  final bool closeAfterChoice;

  static Future<void> open(
    BuildContext context, {
    bool closeAfterChoice = false,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AdPrivacyPage(closeAfterChoice: closeAfterChoice),
    ),
  );

  Future<void> _choose(
    BuildContext context,
    AdPrivacyController controller,
    bool allowed,
  ) async {
    try {
      await controller.setAllowed(allowed);
      if (context.mounted && closeAfterChoice) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).adPrivacySaveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final controller = AppScope.of(context).adPrivacyController;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(strings.adPrivacyTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.accentSoft,
                      size: 42,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      strings.adPrivacySubtitle,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.adPrivacyBody,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (controller.hasDecision) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          controller.adsAllowed
                              ? strings.adsAllowedStatus
                              : strings.adsDeclinedStatus,
                          style: const TextStyle(
                            color: AppColors.accentSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton(
                      key: const Key('allow-limited-ads'),
                      onPressed: controller.isSaving
                          ? null
                          : () => _choose(context, controller, true),
                      child: Text(
                        strings.allowLimitedAds,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('decline-ads'),
                      onPressed: controller.isSaving
                          ? null
                          : () => _choose(context, controller, false),
                      child: Text(
                        strings.declineAds,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (controller.sdkStartedThisSession &&
                        !controller.adsAllowed) ...[
                      const SizedBox(height: 16),
                      Text(
                        strings.adSdkWithdrawal,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => LegalPage.openPrivacy(context),
                      child: Text(strings.privacyPolicy),
                    ),
                    TextButton(
                      onPressed: () =>
                          openLegalLink(context, AppLegal.yandexPrivacy),
                      child: Text(strings.providerPrivacy),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
