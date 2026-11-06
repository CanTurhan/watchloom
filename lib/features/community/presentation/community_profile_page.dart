import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/legal/app_legal.dart';
import 'package:watchloom/core/legal/community_policy.dart' as legal;
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/account/presentation/account_page.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/account/presentation/sign_in_page.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_policy.dart';
import 'package:watchloom/features/community/domain/community_repository.dart';
import 'package:watchloom/features/community/presentation/community_access.dart';
import 'package:watchloom/features/community/presentation/community_strings.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';

Future<void> openCommunityGuidelines(BuildContext context) {
  final s = CommunityStrings.of(context);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LegalPage(
        title: s.guidelines,
        body: s.tr
            ? legal.CommunityPolicy.termsTr
            : legal.CommunityPolicy.termsEn,
        links: [
          LegalLink(s.guidelines, AppLegal.community),
          LegalLink(s.support, AppLegal.contact),
        ],
      ),
    ),
  );
}

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({
    required this.repository,
    required this.viewerUid,
    required this.verified,
    this.auth,
    super.key,
  });
  final CommunityRepository? repository;
  final String? viewerUid;
  final bool verified;
  final AuthController? auth;

  static Future<bool?> open(BuildContext context) {
    final auth = AppScope.of(context).accountSession?.auth;
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          repository: communityRepositoryFor(context),
          viewerUid: auth?.user?.uid,
          verified: auth?.canBackup ?? false,
          auth: auth,
        ),
      ),
    );
  }

  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage> {
  final _form = GlobalKey<FormState>();
  final _handle = TextEditingController();
  final _nickname = TextEditingController();
  CommunityDisplayMode _mode = CommunityDisplayMode.handle;
  CommunityProfile? _profile;
  Set<String> _blocks = {};
  bool _loading = true;
  bool _busy = false;
  bool _consent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _handle.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.repository == null ||
        widget.viewerUid == null ||
        !widget.verified) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        widget.repository!.profile(),
        widget.repository!.blockedUsers(),
      ]);
      if (!mounted) return;
      final profile = results[0] as CommunityProfile?;
      setState(() {
        _profile = profile;
        _blocks = results[1] as Set<String>;
        _handle.text = profile?.handle ?? '';
        _nickname.text = profile?.nickname ?? '';
        _mode = profile?.displayMode ?? CommunityDisplayMode.handle;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = CommunityStrings.of(context).failure(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final s = CommunityStrings.of(context);
    if (_busy || !_form.currentState!.validate()) return;
    if (!_consent) {
      setState(() => _error = s.acceptTerms);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      CommunityPolicy.identity(
        handle: _handle.text,
        nickname: _nickname.text,
        displayMode: _mode,
      );
      await widget.repository!.saveProfile(
        handle: _handle.text,
        nickname: _nickname.text,
        displayMode: _mode,
        acceptedTerms: true,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = s.failure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unblock(String uid) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository!.unblockUser(uid);
      if (mounted) setState(() => _blocks.remove(uid));
    } catch (error) {
      if (mounted) {
        setState(() => _error = CommunityStrings.of(context).failure(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = CommunityStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.publicIdentity)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: AppColors.accentSoft,
                  size: 38,
                ),
                const SizedBox(height: 20),
                Text(
                  s.identityBody,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s.tr
                      ? 'Ad değişiklikleri yeni gönderilere uygulanır. Eski yorumlar, gönderildikleri sıradaki adı korur; istersen kendi yorumlarını silebilirsin.'
                      : 'Name changes apply to new submissions. Existing comments keep the name used when they were submitted; you can delete your own comments.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.repository == null)
                  Text(s.unavailableDevice)
                else if (widget.viewerUid == null)
                  FilledButton.icon(
                    onPressed: widget.auth == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SignInPage(auth: widget.auth!),
                            ),
                          ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(s.signIn),
                  )
                else if (!widget.verified) ...[
                  Text(s.verification),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountPage(
                          session: AppScope.of(context).accountSession!,
                        ),
                      ),
                    ),
                    child: Text(s.manageAccount),
                  ),
                ] else ...[
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_profile == null)
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: Text(s.retry),
                      ),
                  ],
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const ValueKey('community-handle'),
                          controller: _handle,
                          readOnly: _profile != null,
                          enabled: !_busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                          maxLength: 20,
                          decoration: InputDecoration(
                            labelText: s.handle,
                            prefixText: '@',
                            helperText: s.handleHelp,
                            helperMaxLines: 4,
                            suffixIcon: _profile != null
                                ? const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) =>
                              RegExp(r'^[a-z][a-z0-9_]{2,19}$').hasMatch(
                                CommunityPolicy.normalizeHandle(value ?? ''),
                              )
                              ? null
                              : s.handleHelp,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          key: const ValueKey('community-nickname'),
                          controller: _nickname,
                          enabled: !_busy,
                          maxLength: 24,
                          decoration: InputDecoration(
                            labelText: s.nickname,
                            helperText: s.nicknameHelp,
                            helperMaxLines: 3,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) =>
                              _mode == CommunityDisplayMode.nickname &&
                                  (value?.trim().length ?? 0) < 3
                              ? s.nicknameHelp
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          s.displayAs,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        RadioGroup<CommunityDisplayMode>(
                          groupValue: _mode,
                          onChanged: (value) {
                            if (!_busy && value != null) {
                              setState(() => _mode = value);
                            }
                          },
                          child: Column(
                            children: [
                              RadioListTile<CommunityDisplayMode>(
                                value: CommunityDisplayMode.handle,
                                title: Text(s.handle),
                                subtitle: Text(
                                  _handle.text.isEmpty
                                      ? '@username'
                                      : '@${CommunityPolicy.normalizeHandle(_handle.text)}',
                                ),
                              ),
                              RadioListTile<CommunityDisplayMode>(
                                value: CommunityDisplayMode.nickname,
                                title: Text(s.nickname),
                                subtitle: Text(
                                  _nickname.text.trim().isEmpty
                                      ? s.nicknameHelp
                                      : _nickname.text.trim(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.preview,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _mode == CommunityDisplayMode.nickname
                                      ? (_nickname.text.trim().isEmpty
                                            ? s.nickname
                                            : _nickname.text.trim())
                                      : (_handle.text.isEmpty
                                            ? '@username'
                                            : '@${CommunityPolicy.normalizeHandle(_handle.text)}'),
                                  key: const ValueKey(
                                    'community-public-name-preview',
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          key: const ValueKey('community-terms-consent'),
                          value: _consent,
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => _consent = value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            s.acceptTerms,
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                        TextButton(
                          onPressed: () => openCommunityGuidelines(context),
                          child: Text(s.guidelines),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('community-save-identity'),
                          onPressed: _busy || !_consent ? null : _save,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(s.save),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    s.blockedAccounts,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.blockedPrivacy,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_blocks.isEmpty)
                    Text(
                      s.noBlocks,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  for (final uid in (_blocks.toList()..sort()))
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.block_rounded),
                        title: Text(
                          '${s.tr ? 'Hesap' : 'Account'} · ${uid.length > 6 ? uid.substring(uid.length - 6) : uid}',
                        ),
                        trailing: IconButton.filledTonal(
                          key: ValueKey('community-unblock-$uid'),
                          tooltip: s.unblock,
                          onPressed: _busy ? null : () => _unblock(uid),
                          icon: const Icon(Icons.person_remove_outlined),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => openLegalLink(context, AppLegal.contact),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: Text(s.support),
                ),
              ],
            ),
    );
  }
}
