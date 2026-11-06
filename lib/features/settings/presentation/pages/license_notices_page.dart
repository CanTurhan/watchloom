import 'package:flutter/material.dart';
import 'package:watchloom/core/legal/app_legal.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';

/// Hosted notices are convenient to browse; a complete bundled copy remains
/// available without a connection, including native SDK acknowledgements.
class LicenseNoticesPage extends StatelessWidget {
  const LicenseNoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final tr = strings.isTurkish;
    return Scaffold(
      appBar: AppBar(title: Text(strings.openSourceLicenses)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.code_rounded, color: AppColors.accentSoft, size: 40),
          const SizedBox(height: 20),
          Text(
            tr ? 'Birlikte geliştirilen yazılımlar' : 'Built with shared work',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            tr
                ? 'Watchloom’da kullanılan açık kaynak yazılımların ve yerel SDK’ların lisanslarını ve telif bildirimlerini inceleyebilirsin.'
                : 'Explore the licenses and copyright notices for the open source software and native SDKs used in Watchloom.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            key: const ValueKey('hosted-license-notices'),
            onPressed: () => openLegalLink(context, AppLegal.licenses),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(
              tr ? 'GitHub’da lisansları aç' : 'Open licenses on GitHub',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('offline-license-notices'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Watchloom',
              applicationVersion: '1.2.0',
            ),
            icon: const Icon(Icons.offline_pin_outlined),
            label: Text(
              tr
                  ? 'Uygulamadaki çevrimdışı kopya'
                  : 'Read the bundled offline copy',
            ),
          ),
        ],
      ),
    );
  }
}
