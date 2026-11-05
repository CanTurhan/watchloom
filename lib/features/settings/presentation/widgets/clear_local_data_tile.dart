import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/core/localization/app_settings_strings.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/settings/data/local_data_reset_service.dart';

class ClearLocalDataTile extends StatefulWidget {
  const ClearLocalDataTile({super.key});
  @override
  State<ClearLocalDataTile> createState() => _ClearLocalDataTileState();
}

class _ClearLocalDataTileState extends State<ClearLocalDataTile> {
  bool _clearing = false;

  Future<void> _clear() async {
    if (_clearing) return;
    final strings = AppStrings.of(context);
    final scope = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
        title: Text(strings.clearDataConfirmationTitle),
        content: Text(strings.clearDataConfirmationBody),
        actions: [
          if (scope.premiumController.isSupported)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
                scope.premiumController.manage();
              },
              child: Text(strings.manageSubscription),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.clearDataConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    var succeeded = false;
    try {
      await const LocalDataResetService().clearAllWatchloomData();
      await scope.libraryController.load();
      await scope.activityController.load();
      succeeded = true;
    } catch (_) {
      // A failure is shown locally; it never attempts to change Apple billing.
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              succeeded ? strings.clearDataSuccess : strings.clearDataFailed,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListTile(
      leading: const Icon(
        Icons.delete_forever_rounded,
        color: Colors.redAccent,
      ),
      title: Text(
        strings.clearAllData,
        style: const TextStyle(color: Colors.redAccent),
      ),
      subtitle: Text(strings.clearAllDataSubtitle),
      trailing: _clearing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _clearing ? null : _clear,
    );
  }
}
