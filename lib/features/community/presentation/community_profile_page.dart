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
    this.repositoryForUser,
    super.key,
  });
  final CommunityRepository? repository;
  final String? viewerUid;
  final bool verified;
  final AuthController? auth;
  final CommunityRepository? Function(String? uid)? repositoryForUser;

  static Future<bool?> open(BuildContext context) {
    final auth = AppScope.of(context).accountSession?.auth;
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          repository: communityRepositoryFor(context),
          viewerUid: auth?.user?.uid,
          verified: auth?.canBackup ?? false,
          auth: auth,
          repositoryForUser: (_) => communityRepositoryFor(context),
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
  CommunityRepository? _repository;
  String? _repositoryUid;
  String? _viewerUid;
  bool _verified = false;
  int _revision = 0;
  int _loadTicket = 0;
  bool _disposed = false;

  String? get _liveUid =>
      widget.auth == null ? widget.viewerUid : widget.auth!.user?.uid;
  bool get _liveVerified =>
      _liveUid != null && (widget.auth?.canBackup ?? widget.verified);
  bool get _canParticipate =>
      _viewerUid != null &&
      _verified &&
      _repository != null &&
      _repositoryUid == _viewerUid;
  bool _currentSession(int revision) =>
      mounted && !_disposed && revision == _revision;

  @override
  void initState() {
    super.initState();
    _viewerUid = _liveUid;
    _verified = _liveVerified;
    _repository = widget.repository;
    _repositoryUid = widget.viewerUid;
    _bindRepository(suppliedBinding: true);
    widget.auth?.addListener(_authChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant CommunityProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final authChanged = oldWidget.auth != widget.auth;
    if (authChanged) {
      oldWidget.auth?.removeListener(_authChanged);
      widget.auth?.addListener(_authChanged);
    }
    final suppliedBinding = oldWidget.repository != widget.repository;
    final snapshotChanged =
        oldWidget.viewerUid != widget.viewerUid ||
        oldWidget.verified != widget.verified;
    _refreshSession(
      force: authChanged || suppliedBinding || snapshotChanged,
      suppliedBinding: suppliedBinding,
      authControllerChanged: authChanged,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _loadTicket++;
    widget.auth?.removeListener(_authChanged);
    _handle.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _bindRepository({
    required bool suppliedBinding,
    bool authControllerChanged = false,
  }) {
    if (suppliedBinding && widget.viewerUid == _viewerUid) {
      _repository = widget.repository;
      _repositoryUid = widget.viewerUid;
      return;
    }
    if (widget.repositoryForUser != null) {
      try {
        _repository = widget.repositoryForUser!(_viewerUid);
        _repositoryUid = _viewerUid;
      } catch (_) {
        _repository = null;
      }
    } else if (_repositoryUid != _viewerUid || authControllerChanged) {
      _repository = null;
    }
  }

  void _authChanged() => _refreshSession();

  bool _refreshSession({
    bool force = false,
    bool suppliedBinding = false,
    bool authControllerChanged = false,
  }) {
    if (_disposed) return false;
    final uid = _liveUid, verified = _liveVerified;
    if (!force && uid == _viewerUid && verified == _verified) return false;
    _revision++;
    _loadTicket++;
    _viewerUid = uid;
    _verified = verified;
    _profile = null;
    _blocks = {};
    _handle.clear();
    _nickname.clear();
    _mode = CommunityDisplayMode.handle;
    _consent = false;
    _error = null;
    _busy = false;
    _bindRepository(
      suppliedBinding: suppliedBinding,
      authControllerChanged: authControllerChanged,
    );
    _load();
    return true;
  }

  Future<void> _manageAccount() async {
    final session = AppScope.of(context).accountSession;
    if (session == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AccountPage(session: session)),
    );
    if (!mounted) return;
    final changed = _refreshSession();
    if (!changed && _canParticipate) await _load();
  }

  Future<void> _load() async {
    final repository = _repository;
    final revision = _revision;
    final ticket = ++_loadTicket;
    if (!_canParticipate || repository == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        repository.profile(),
        repository.blockedUsers(),
      ]);
      if (!_currentSession(revision) || ticket != _loadTicket) return;
      final profile = results[0] as CommunityProfile?;
      setState(() {
        _profile = profile;
        _blocks = results[1] as Set<String>;
        _handle.text = profile?.handle ?? '';
        _nickname.text = profile?.nickname ?? '';
        _mode = profile?.displayMode ?? CommunityDisplayMode.handle;
      });
    } catch (error) {
      if (_currentSession(revision) && ticket == _loadTicket) {
        setState(() => _error = CommunityStrings.of(context).failure(error));
      }
    } finally {
      if (_currentSession(revision) && ticket == _loadTicket) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final s = CommunityStrings.of(context);
    final revision = _revision, repository = _repository;
    if (_busy ||
        !_canParticipate ||
        repository == null ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
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
      await repository.saveProfile(
        handle: _handle.text,
        nickname: _nickname.text,
        displayMode: _mode,
        acceptedTerms: true,
      );
      if (mounted && _currentSession(revision)) Navigator.of(context).pop(true);
    } catch (error) {
      if (_currentSession(revision)) setState(() => _error = s.failure(error));
    } finally {
      if (_currentSession(revision)) setState(() => _busy = false);
    }
  }

  Future<void> _unblock(String uid) async {
    final revision = _revision, repository = _repository;
    if (!_canParticipate || repository == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.unblockUser(uid);
      if (_currentSession(revision)) setState(() => _blocks.remove(uid));
    } catch (error) {
      if (_currentSession(revision)) {
        setState(() => _error = CommunityStrings.of(context).failure(error));
      }
    } finally {
      if (_currentSession(revision)) setState(() => _busy = false);
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
                if (_repository == null)
                  Text(
                    widget.repository == null
                        ? s.unavailableDevice
                        : s.text(
                            'Your account changed. Reopen community to continue safely.',
                            'Hesabın değişti. Güvenle devam etmek için topluluğu yeniden aç.',
                          ),
                  )
                else if (_viewerUid == null)
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
                else if (!_verified) ...[
                  Text(s.verification),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _manageAccount,
                    child: Text(s.manageAccount),
                  ),
                ] else ...[
                  if (_profile != null && !_profile!.acceptedTerms)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        s.renewConsent,
                        key: const ValueKey('community-renew-consent'),
                        style: const TextStyle(
                          color: AppColors.accentSoft,
                          height: 1.5,
                        ),
                      ),
                    ),
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
