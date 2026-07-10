import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/monetization/pro_access_controller.dart';
import 'package:watchloom/core/theme/app_colors.dart';

class WatchloomProPage extends StatefulWidget {
  const WatchloomProPage({super.key});

  @override
  State<WatchloomProPage> createState() {
    return _WatchloomProPageState();
  }
}

class _WatchloomProPageState extends State<WatchloomProPage> {
  final ProAccessController _controller = ProAccessController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.initialize());
  }

  Future<void> _purchase() async {
    final strings = AppStrings.of(context);

    final started = await _controller.purchase();

    if (!mounted) {
      return;
    }

    _showMessage(
      started
          ? strings.purchaseStarted
          : _controller.storeAvailable
          ? strings.purchaseUnavailable
          : strings.storeUnavailable,
    );
  }

  Future<void> _restore() async {
    final strings = AppStrings.of(context);

    final restored = await _controller.restorePurchases();

    if (!mounted) {
      return;
    }

    _showMessage(restored ? strings.purchaseRestored : strings.purchaseFailed);
  }

  void _showMessage(String message) {
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
              child: const Icon(
                Icons.workspace_premium_rounded,
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
      appBar: AppBar(title: Text(strings.watchloomProTitle)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final isBusy = _controller.isPurchasing || _controller.isRestoring;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(27),
                      ),
                      child: Icon(
                        _controller.isPro
                            ? Icons.verified_rounded
                            : Icons.workspace_premium_rounded,
                        color: AppColors.accentSoft,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _controller.isPro
                          ? strings.watchloomProActive
                          : strings.watchloomProTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _controller.isPro
                          ? strings.watchloomProActiveDescription
                          : strings.watchloomProDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        strings.oneTimePurchase,
                        style: const TextStyle(
                          color: AppColors.accentSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_controller.isPro) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: isBusy || _controller.product == null
                      ? null
                      : _purchase,
                  icon: _controller.isPurchasing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.remove_circle_outline_rounded),
                  label: Text(
                    _controller.localizedPrice == null
                        ? strings.purchaseUnavailable
                        : strings.buyWatchloomPro(_controller.localizedPrice!),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: isBusy ? null : _restore,
                icon: _controller.isRestoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label: Text(strings.restorePurchases),
              ),
              if (_controller.lastError != null) ...[
                const SizedBox(height: 18),
                Text(
                  strings.purchaseFailed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
