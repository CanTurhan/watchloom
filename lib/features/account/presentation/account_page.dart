import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_account_strings.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/account/data/sqlite_backup_store.dart';
import 'package:watchloom/features/account/presentation/account_session_controller.dart';
import 'package:watchloom/features/account/presentation/backup_controller.dart';
import 'package:watchloom/features/account/presentation/sign_in_page.dart';
import 'package:watchloom/features/premium/presentation/premium_page.dart';

class AccountTile extends StatelessWidget {
  const AccountTile({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).accountSession;
    if (session == null) return const SizedBox.shrink();
    final s = AppStrings.of(context);
    return ListenableBuilder(
      listenable: session.auth,
      builder: (context, _) {
        final user = session.auth.user;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Icon(
              user == null
                  ? Icons.account_circle_outlined
                  : Icons.cloud_done_outlined,
              color: AppColors.accentSoft,
              size: 30,
            ),
            title: Text(user == null ? s.signIn : s.accountTitle),
            subtitle: Text(
              user?.email ?? (user == null ? s.guestBody : 'Watchloom'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => user == null
                    ? SignInPage(auth: session.auth)
                    : AccountPage(session: session),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({required this.session, super.key});
  final AccountSessionController session;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _working = false;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionUpdated);
  }

  void _sessionUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionUpdated);
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(AppStrings.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _signOut() async {
    final s = AppStrings.of(context);
    setState(() {
      _working = true;
    });
    try {
      await widget.session.backup?.synchronize();
      final local = await SqliteBackupStore(widget.session.database).read();
      if (!mounted) return;
      final warning = local.state.dirty ? '\n\n${s.unsavedSignOut}' : '';
      if (await _confirm(s.signOut, '${s.signOutBody}$warning', s.signOut)) {
        await widget.session.auth.signOut();
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final s = AppStrings.of(context);
    final user = widget.session.auth.user;
    if (user == null) return;
    final passwordOnly = user.providerData.every(
      (p) => p.providerId == 'password',
    );
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(s.deleteAccount),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.deleteAccountBody),
              if (passwordOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: TextField(
                    controller: password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(labelText: s.passwordLabel),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialog, false);
              AppScope.of(context).premiumController.manage();
            },
            child: Text(s.manageSubscription),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(s.deleteAccountConfirm),
          ),
        ],
      ),
    );
    final value = password.text;
    // Dispose after the dialog transition has released its TextField.
    Future<void>.delayed(const Duration(seconds: 1), password.dispose);
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
    });
    try {
      final deleted = await widget.session.deleteAccount(password: value);
      if (!deleted) _message(s.deleteFailed);
    } catch (_) {
      _message(s.deleteFailed);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _resolve(bool useCloud) async {
    final s = AppStrings.of(context);
    final action = useCloud ? s.useCloud : s.useDevice;
    if (await _confirm(action, s.conflictConfirm, action)) {
      await widget.session.backup?.resolve(useCloud: useCloud);
    }
  }

  Future<void> _import() async {
    final s = AppStrings.of(context);
    if (!await _confirm(
      s.importGuestTitle,
      s.importGuestBody,
      s.importGuestTitle,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _working = true;
    });
    try {
      await widget.session.importGuest();
    } catch (_) {
      _message(s.importFailed);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _linkProvider({required bool apple}) async {
    final s = AppStrings.of(context);
    final name = apple ? 'Apple' : 'Google';
    final title = s.value(en: 'Link $name', tr: '$name hesabını bağla');
    if (!await _confirm(title, s.linkIdentityConsent, title)) return;
    if (apple) {
      await widget.session.auth.apple(link: true);
    } else {
      await widget.session.auth.google(link: true);
    }
  }

  String _status(
    AppStrings s,
    BackupController? backup,
  ) => switch (backup?.status) {
    BackupStatus.syncing => s.value(en: 'Backing up…', tr: 'Yedekleniyor…'),
    BackupStatus.pending => s.value(
      en: 'Changes waiting for backup',
      tr: 'Değişiklikler yedeklenmeyi bekliyor',
    ),
    BackupStatus.saved => s.value(
      en: 'Backup is up to date',
      tr: 'Yedek güncel',
    ),
    BackupStatus.conflict => s.backupConflict,
    BackupStatus.verificationRequired => s.emailVerify,
    BackupStatus.deletionPending => s.deletionPendingBody,
    BackupStatus.offline => s.value(
      en: 'Backup could not be completed. Your changes are kept on this device. Retry when online.',
      tr: 'Yedekleme tamamlanamadı. Değişikliklerin bu cihazda korunuyor. Çevrimiçiyken tekrar dene.',
    ),
    _ => s.value(en: 'Waiting for backup', tr: 'Yedekleme bekleniyor'),
  };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(title: Text(s.accountTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([session, session.auth, session.backup]),
        builder: (context, _) {
          final auth = session.auth;
          final user = auth.user;
          if (user == null) return const SizedBox.shrink();
          final backup = session.backup;
          final busy = _working || auth.busy;
          final providers = user.providerData.map((p) => p.providerId).toSet();
          if (session.deletionPending) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 44,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 18),
                Text(
                  s.deletionPendingTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (user.email != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(user.email!),
                  ),
                Text(
                  s.deletionPendingBody,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _delete,
                  child: Text(s.deleteAccountConfirm),
                ),
                TextButton(
                  onPressed: busy ? null : _signOut,
                  child: Text(s.signOut),
                ),
                const SizedBox(height: 12),
                Text(
                  s.premiumAccountNote,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      AppScope.of(context).premiumController.manage(),
                  child: Text(s.manageSubscription),
                ),
                if (auth.errorCode != null) Text(s.authError(auth.errorCode)),
                if (busy) const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.surfaceLight,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.accentSoft,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user.displayName?.trim().isNotEmpty == true
                                ? user.displayName!
                                : 'Watchloom',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (user.email != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: SelectableText(
                                user.email!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final provider in providers)
                                Chip(
                                  label: Text(switch (provider) {
                                    'apple.com' => 'Apple',
                                    'google.com' => 'Google',
                                    _ => s.emailLabel,
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!auth.canBackup)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.emailVerify),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await auth.resendVerification(
                                        s.languageCode,
                                      )) {
                                        _message(s.mailSent);
                                      }
                                    },
                              child: Text(s.resendEmail),
                            ),
                            FilledButton.tonal(
                              onPressed: busy ? null : auth.refreshUser,
                              child: Text(s.verifyCheck),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_outlined,
                                color: AppColors.accentSoft,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _status(s, backup),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.backupDisclosure,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          if (backup?.lastSaved != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                DateFormat.yMMMd(
                                  s.languageCode,
                                ).add_Hm().format(backup!.lastSaved!),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (backup?.status == BackupStatus.conflict) ...[
                            OutlinedButton(
                              onPressed: busy ? null : () => _resolve(true),
                              child: Text(s.useCloud),
                            ),
                            TextButton(
                              onPressed: busy ? null : () => _resolve(false),
                              child: Text(s.useDevice),
                            ),
                          ] else
                            FilledButton.tonalIcon(
                              onPressed:
                                  busy ||
                                      backup?.isBusy == true ||
                                      !auth.canBackup
                                  ? null
                                  : backup?.synchronize,
                              icon: backup?.isBusy == true
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              label: Text(s.backupNow),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (session.hasGuestData)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.importGuestTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.importGuestBody,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  busy ||
                                      session.library.entries.isNotEmpty ||
                                      backup?.status != BackupStatus.saved
                                  ? null
                                  : _import,
                              child: Text(s.importGuestTitle),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.value(
                              en: 'Sign-in methods',
                              tr: 'Giriş yöntemleri',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (!providers.contains('apple.com'))
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _linkProvider(apple: true),
                              icon: const Icon(Icons.apple),
                              label: Text(
                                s.value(
                                  en: 'Link Apple',
                                  tr: 'Apple hesabını bağla',
                                ),
                              ),
                            ),
                          if (!providers.contains('google.com'))
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _linkProvider(apple: false),
                              icon: const GoogleBrandIcon(),
                              label: Text(
                                s.value(
                                  en: 'Link Google',
                                  tr: 'Google hesabını bağla',
                                ),
                              ),
                            ),
                          Text(
                            s.premiumAccountNote,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => PremiumPage.open(context),
                            child: Text(s.restorePurchases),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (auth.errorCode != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        s.authError(auth.errorCode),
                        style: const TextStyle(color: AppColors.orange),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(s.signOut),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: busy ? null : _delete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    label: Text(
                      s.deleteAccount,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  if (busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
