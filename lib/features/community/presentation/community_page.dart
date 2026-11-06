import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/legal/app_legal.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/core/widgets/app_page_header.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_policy.dart';
import 'package:watchloom/features/community/domain/community_repository.dart';
import 'package:watchloom/features/community/presentation/community_access.dart';
import 'package:watchloom/features/community/presentation/community_profile_page.dart';
import 'package:watchloom/features/community/presentation/community_strings.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({
    required this.contentKey,
    required this.seriesName,
    required this.repository,
    this.viewerUid,
    this.verified = false,
    this.auth,
    this.repositoryForUser,
    super.key,
  });
  final String contentKey;
  final String seriesName;
  final CommunityRepository? repository;
  final String? viewerUid;
  final bool verified;
  final AuthController? auth;

  /// Each repository is bound to one UID. A live account change needs a new
  /// instance; injected repositories without a factory fail closed instead.
  final CommunityRepository? Function(String? uid)? repositoryForUser;

  static Future<void> open(
    BuildContext context, {
    required int showId,
    required String seriesName,
  }) {
    final auth = AppScope.of(context).accountSession?.auth;
    final repository = communityRepositoryFor(context);
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CommunityPage(
          contentKey: 'tvmaze:show:$showId',
          seriesName: seriesName,
          repository: repository,
          viewerUid: auth?.user?.uid,
          verified: auth?.canBackup ?? false,
          auth: auth,
          repositoryForUser: (_) => communityRepositoryFor(context),
        ),
      ),
    );
  }

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<CommunityComment> _comments = [];
  List<CommunityComment> _pending = [];
  Set<String> _blocks = {};
  final Set<String> _revealed = {};
  CommunityProfile? _profile;
  CommunityAvailability? _availability;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _loadTicket = 0;
  final _sessionRevision = ValueNotifier<int>(0);
  CommunityRepository? _repository;
  String? _repositoryUid;
  String? _viewerUid;
  bool _verified = false;
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
      mounted && !_disposed && _sessionRevision.value == revision;

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
  void didUpdateWidget(covariant CommunityPage oldWidget) {
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
    final contentChanged = oldWidget.contentKey != widget.contentKey;
    _refreshSession(
      force:
          authChanged || suppliedBinding || snapshotChanged || contentChanged,
      suppliedBinding: suppliedBinding,
      authControllerChanged: authChanged,
      contentChanged: contentChanged,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _loadTicket++;
    widget.auth?.removeListener(_authChanged);
    _sessionRevision.dispose();
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

  void _refreshSession({
    bool force = false,
    bool suppliedBinding = false,
    bool authControllerChanged = false,
    bool contentChanged = false,
  }) {
    if (_disposed) return;
    final uid = _liveUid, verified = _liveVerified;
    if (!force && uid == _viewerUid && verified == _verified) return;
    _loadTicket++;
    _viewerUid = uid;
    _verified = verified;
    _profile = null;
    _pending = [];
    _blocks = {};
    _revealed.clear();
    _busy = false;
    _error = null;
    if (contentChanged) {
      _comments = [];
      _availability = null;
    }
    _bindRepository(
      suppliedBinding: suppliedBinding,
      authControllerChanged: authControllerChanged,
    );
    _sessionRevision.value++;
    _load();
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      setState(() => _loading = false);
      return;
    }
    final ticket = ++_loadTicket;
    final revision = _sessionRevision.value;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final owner = _canParticipate;
      final errors = <Object>[];
      Future<T?> request<T>(Future<T> Function() read) async {
        try {
          return await read();
        } catch (error) {
          errors.add(error);
          return null;
        }
      }

      final results = await Future.wait<Object?>([
        request(repository.availability),
        request(() => repository.comments(contentKey: widget.contentKey)),
        if (owner) request<CommunityProfile?>(repository.profile),
        if (owner)
          request(
            () => repository.pendingComments(contentKey: widget.contentKey),
          ),
        if (owner) request(repository.blockedUsers),
      ]);
      if (!_currentSession(revision) || ticket != _loadTicket) return;
      setState(() {
        _availability = results[0] as CommunityAvailability?;
        if (results[1] != null) {
          _comments = results[1] as List<CommunityComment>;
        }
        if (owner) {
          _profile = results[2] as CommunityProfile?;
          if (results[3] != null) {
            _pending = results[3] as List<CommunityComment>;
          }
          if (results[4] != null) _blocks = results[4] as Set<String>;
        }
        if (errors.isNotEmpty) {
          final s = CommunityStrings.of(context);
          _error = results[1] != null
              ? s.text(
                  'Some community options could not refresh. You can still read approved comments. Try again before participating.',
                  'Bazı topluluk seçenekleri yenilenemedi. Onaylı yorumları okuyabilirsin. Katılmadan önce tekrar dene.',
                )
              : s.failure(errors.first);
        }
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

  Future<bool> _ensureIdentity({bool edit = false}) async {
    final revision = _sessionRevision.value;
    if (!edit && _canParticipate && _profile != null) {
      return true;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          repository: _repository,
          viewerUid: _viewerUid,
          verified: _verified,
          auth: widget.auth,
          repositoryForUser: widget.repositoryForUser,
        ),
      ),
    );
    if (!mounted) return false;
    if (changed == true || edit) await _load();
    return _currentSession(revision) && _profile != null && _canParticipate;
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(value), showCloseIcon: true));
  }

  Future<void> _compose([CommunityComment? parent]) async {
    final revision = _sessionRevision.value;
    if (_busy || !await _ensureIdentity() || !mounted) return;
    if (!_currentSession(revision) || !_canParticipate) return;
    final repository = _repository!;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CommentComposer(
        publicName: _profile!.publicName,
        parent: parent,
        sessionRevision: _sessionRevision,
        sessionCurrent: () =>
            _currentSession(revision) &&
            _canParticipate &&
            identical(repository, _repository),
        submit: (body, spoiler) async {
          if (!_currentSession(revision) ||
              !_canParticipate ||
              !identical(repository, _repository)) {
            throw const CommunityException(
              CommunityFailure.verificationRequired,
            );
          }
          await repository.post(
            contentKey: widget.contentKey,
            body: body,
            parentId: parent?.id,
            isSpoiler: spoiler,
          );
        },
      ),
    );
    if (result == true && mounted && _currentSession(revision)) {
      _message(CommunityStrings.of(context).sent);
      await _load();
    }
  }

  Future<bool> _confirm(String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(CommunityStrings.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _delete(CommunityComment comment) async {
    final revision = _sessionRevision.value;
    final s = CommunityStrings.of(context);
    if (_busy || !await _confirm(s.deleteConfirm, s.delete) || !mounted) return;
    if (!_currentSession(revision) || !_canParticipate) return;
    await _act(() => _repository!.deleteComment(comment.id), s.deleted);
  }

  Future<void> _block(CommunityComment comment) async {
    final revision = _sessionRevision.value;
    if (_busy || !await _ensureIdentity() || !mounted) return;
    final s = CommunityStrings.of(context);
    if (!await _confirm(s.blockConfirm, s.block) || !mounted) return;
    if (!_currentSession(revision) || !_canParticipate) return;
    await _act(() => _repository!.blockUser(comment.authorUid), s.blocked);
  }

  Future<void> _report(CommunityComment comment) async {
    final revision = _sessionRevision.value;
    if (_busy || !await _ensureIdentity() || !mounted) return;
    final s = CommunityStrings.of(context);
    final reason = await showModalBottomSheet<CommunityReportReason>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                s.reportTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final reason in CommunityReportReason.values)
              ListTile(
                title: Text(s.reason(reason)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, reason),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    if (!_currentSession(revision) || !_canParticipate) return;
    await _act(
      () => _repository!.report(commentId: comment.id, reason: reason),
      s.reportSent,
    );
  }

  Future<void> _act(Future<void> Function() operation, String success) async {
    if (!_canParticipate) return;
    final revision = _sessionRevision.value;
    setState(() => _busy = true);
    try {
      await operation();
      if (_currentSession(revision)) {
        _message(success);
        await _load();
      }
    } catch (error) {
      if (mounted && _currentSession(revision)) {
        _message(CommunityStrings.of(context).failure(error));
      }
    } finally {
      if (_currentSession(revision)) setState(() => _busy = false);
    }
  }

  List<CommunityComment> get _visible {
    final visible = _comments
        .where((comment) => !_blocks.contains(comment.authorUid))
        .toList();
    final roots = visible.where((comment) => comment.parentId == null).toList();
    final rootIds = roots.map((comment) => comment.id).toSet();
    return [
      for (final root in roots) ...[
        root,
        ...(visible.where((comment) => comment.parentId == root.id).toList()
          ..sort(
            (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
              b.createdAt ?? DateTime(0),
            ),
          )),
      ],
      ...visible.where(
        (comment) =>
            comment.parentId != null && !rootIds.contains(comment.parentId),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = CommunityStrings.of(context);
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          IconButton(
            tooltip: s.publicIdentity,
            onPressed: _busy ? null : () => _ensureIdentity(edit: true),
            icon: const Icon(Icons.badge_outlined),
          ),
          IconButton(
            tooltip: s.refresh,
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            AppPageHeader(
              title: widget.seriesName,
              subtitle: s.subtitle,
              eyebrow: s.tr ? 'TOPLULUK' : 'COMMUNITY',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 21,
                          color: AppColors.accentSoft,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.moderation,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => openCommunityGuidelines(context),
                      child: Text(s.guidelines),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_repository == null)
              Text(
                widget.repository == null
                    ? s.unavailableDevice
                    : s.text(
                        'Your account changed. Reopen community to continue safely.',
                        'Hesabın değişti. Güvenle devam etmek için topluluğu yeniden aç.',
                      ),
              )
            else ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
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
                TextButton(
                  onPressed: _loading ? null : _load,
                  child: Text(s.retry),
                ),
              ],
              if (!_loading && _availability?.canPost != true && _error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    s.paused,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              if (_availability?.canPost == true)
                FilledButton.icon(
                  key: const ValueKey('community-write-comment'),
                  onPressed: _busy || _loading ? null : _compose,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(_viewerUid == null ? s.signIn : s.write),
                ),
              if (_profile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: _busy ? null : () => _ensureIdentity(edit: true),
                    child: Text(
                      '${s.tr ? 'Görünen adın' : 'Posting as'}: ${_profile!.publicName}',
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              AppSectionHeading(s.recent),
              if (!_loading && visible.isEmpty && _error == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.accentSoft,
                          size: 32,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.empty,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.emptyBody,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              for (final comment in visible)
                Padding(
                  padding: EdgeInsets.only(
                    left: comment.parentId == null ? 0 : 18,
                    bottom: 12,
                  ),
                  child: _commentCard(comment, s),
                ),
              if (_comments.length >= 50)
                Text(
                  s.pageLimit,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              if (_pending.isNotEmpty) ...[
                const SizedBox(height: 24),
                AppSectionHeading(s.pendingTitle),
                for (final comment in _pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _commentCard(comment, s),
                  ),
              ],
            ],
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => openLegalLink(context, AppLegal.contact),
              icon: const Icon(Icons.support_agent_rounded),
              label: Text(s.support),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentCard(CommunityComment comment, CommunityStrings s) {
    final own = comment.authorUid == _viewerUid;
    final approved = comment.status == CommunityCommentStatus.approved;
    final hiddenSpoiler =
        approved && comment.isSpoiler && !_revealed.contains(comment.id);
    return Card(
      key: ValueKey('community-comment-${comment.id}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.16),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.accentSoft,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (comment.createdAt != null)
                        Text(
                          DateFormat.yMMMd(
                            s.tr ? 'tr' : 'en',
                          ).add_Hm().format(comment.createdAt!.toLocal()),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: s.more,
                  enabled: !_busy,
                  onSelected: (value) {
                    switch (value) {
                      case 'delete':
                        _delete(comment);
                      case 'report':
                        _report(comment);
                      case 'block':
                        _block(comment);
                    }
                  },
                  itemBuilder: (_) => [
                    if (own)
                      PopupMenuItem(value: 'delete', child: Text(s.delete)),
                    if (!own && approved) ...[
                      PopupMenuItem(value: 'report', child: Text(s.report)),
                      PopupMenuItem(value: 'block', child: Text(s.block)),
                    ],
                  ],
                ),
              ],
            ),
            if (!approved) ...[
              const SizedBox(height: 12),
              Text(
                comment.status == CommunityCommentStatus.pending
                    ? s.pending
                    : s.rejected,
                key: ValueKey('community-status-${comment.id}'),
                style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (comment.parentId != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.replyContext,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (hiddenSpoiler)
              OutlinedButton.icon(
                key: ValueKey('reveal-spoiler-${comment.id}'),
                onPressed: () => setState(() => _revealed.add(comment.id)),
                icon: const Icon(Icons.visibility_off_outlined),
                label: Text(s.revealSpoiler),
              )
            else ...[
              SelectableText(comment.body, style: const TextStyle(height: 1.6)),
              if (approved && comment.isSpoiler)
                TextButton(
                  onPressed: () => setState(() => _revealed.remove(comment.id)),
                  child: Text(s.hideSpoiler),
                ),
            ],
            if (approved &&
                comment.parentId == null &&
                _availability?.canPost == true)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _compose(comment),
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: Text(s.reply),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({
    required this.publicName,
    required this.submit,
    required this.sessionRevision,
    required this.sessionCurrent,
    this.parent,
  });
  final String publicName;
  final CommunityComment? parent;
  final Future<void> Function(String body, bool spoiler) submit;
  final Listenable sessionRevision;
  final bool Function() sessionCurrent;
  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _text = TextEditingController();
  bool _spoiler = false;
  bool _busy = false;
  bool _cancelled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.sessionRevision.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted || widget.sessionCurrent() || _cancelled) return;
    _text.clear();
    setState(() => _cancelled = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    widget.sessionRevision.removeListener(_sessionChanged);
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _cancelled || !widget.sessionCurrent()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = CommunityPolicy.body(_text.text);
      await widget.submit(body, _spoiler);
      if (mounted && widget.sessionCurrent()) Navigator.pop(context, true);
    } catch (error) {
      if (mounted && widget.sessionCurrent()) {
        setState(() => _error = CommunityStrings.of(context).failure(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = CommunityStrings.of(context);
    if (_cancelled || !widget.sessionCurrent()) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: PopScope(
        canPop: !_busy,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.parent == null ? s.write : s.reply,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.publicName,
                  style: const TextStyle(
                    color: AppColors.accentSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.parent != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${s.reply}: ${widget.parent!.authorName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('community-comment-body'),
                  controller: _text,
                  enabled: !_busy,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: CommunityPolicy.maxBodyLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: s.commentHint),
                ),
                CheckboxListTile(
                  value: _spoiler,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _spoiler = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.spoiler),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                Text(
                  s.moderation,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('community-submit-comment'),
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(s.submit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
