import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/presentation/community_page.dart';
import 'package:watchloom/features/community/presentation/community_profile_page.dart';

import 'helpers/fake_community_repository.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: page,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  CommunityPage feed(
    _LiveAuth auth,
    _BoundRepository repository, {
    bool capturedVerification = false,
    Map<String?, _BoundRepository>? repositories,
  }) => CommunityPage(
    contentKey: 'tvmaze:show:1',
    seriesName: 'Series',
    repository: repository,
    viewerUid: repository.uid,
    verified: capturedVerification,
    auth: auth,
    repositoryForUser: repositories == null ? null : (uid) => repositories[uid],
  );

  CommunityProfilePage profile(
    _LiveAuth auth,
    _BoundRepository repository, {
    bool capturedVerification = false,
    Map<String?, _BoundRepository>? repositories,
  }) => CommunityProfilePage(
    repository: repository,
    viewerUid: repository.uid,
    verified: capturedVerification,
    auth: auth,
    repositoryForUser: repositories == null ? null : (uid) => repositories[uid],
  );

  for (final provider in ['apple.com', 'google.com', 'password']) {
    testWidgets(
      'same-UID $provider refresh loads private feed only after live trust resolves',
      (tester) async {
        final auth = _LiveAuth(uid: 'owner', provider: provider);
        final repository = _BoundRepository('owner')
          ..pending = [_pending('owner-private', 'owner')];
        await pumpPage(tester, feed(auth, repository));
        expect(
          find.byKey(const ValueKey('community-comment-owner-private')),
          findsNothing,
        );
        expect(repository.privateReads, 0);
        auth.publish(
          uid: 'owner',
          emailVerified: provider == 'password',
          provider: provider,
          providerResolved: true,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('community-comment-owner-private')),
          findsOneWidget,
        );
        expect(repository.privateReads, 3);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
      },
    );

    testWidgets(
      'live $provider trust enables profile and feed despite stale opening snapshot',
      (tester) async {
        final auth = _LiveAuth(
          uid: 'owner',
          emailVerified: provider == 'password',
          provider: provider,
          providerResolved: true,
        );
        final repository = _BoundRepository('owner')
          ..pending = [_pending('owner-private', 'owner')];
        await pumpPage(tester, profile(auth, repository));
        expect(find.byKey(const ValueKey('community-handle')), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('community-handle')),
              )
              .controller!
              .text,
          'owner_handle',
        );
        expect(find.text('Private Account Name'), findsNothing);
        expect(find.text('private@example.com'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        expect(auth.listenerCount, 0);
        await pumpPage(tester, feed(auth, repository));
        expect(
          find.byKey(const ValueKey('community-comment-owner-private')),
          findsOneWidget,
        );
        expect(repository.profileReads, 2);
        await tester.pumpWidget(const SizedBox());
        expect(auth.listenerCount, 0);
        auth.dispose();
      },
    );
  }

  for (final provider in ['apple.com', 'google.com', 'password']) {
    testWidgets(
      'same-UID $provider verification refresh enables an already open identity form',
      (tester) async {
        final auth = _LiveAuth(uid: 'owner', provider: provider);
        final repository = _BoundRepository('owner')..profileValue = null;
        await pumpPage(tester, profile(auth, repository));
        expect(find.byKey(const ValueKey('community-handle')), findsNothing);
        expect(repository.profileReads, 0);
        auth.publish(
          uid: 'owner',
          emailVerified: provider == 'password',
          provider: provider,
          providerResolved: true,
        );
        await tester.pumpAndSettle();
        final handle = find.byKey(const ValueKey('community-handle'));
        expect(handle, findsOneWidget);
        expect(tester.widget<TextFormField>(handle).controller!.text, isEmpty);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('community-nickname')),
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(repository.profileReads, 1);
        expect(find.text('Private Account Name'), findsNothing);
        expect(find.text('private@example.com'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        expect(auth.listenerCount, 0);
        auth.dispose();
      },
    );
  }

  testWidgets(
    'email verification while another account route is open is reflected on return',
    (tester) async {
      final auth = _LiveAuth(uid: 'owner', provider: 'password');
      final repository = _BoundRepository('owner')..profileValue = null;
      await pumpPage(tester, profile(auth, repository));
      final navigator = Navigator.of(
        tester.element(find.byType(CommunityProfilePage)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Account verification')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      auth.publish(uid: 'owner', emailVerified: true, provider: 'password');
      await tester.pumpAndSettle();
      expect(find.text('Account verification'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('community-handle')), findsOneWidget);
      expect(repository.profileReads, 1);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets(
    'same-UID trust loss removes pending content and blocks before any refresh completes',
    (tester) async {
      final auth = _LiveAuth(uid: 'owner', emailVerified: true);
      final repository = _BoundRepository('owner')
        ..pending = [_pending('owner-private', 'owner')];
      await pumpPage(tester, feed(auth, repository));
      expect(
        find.byKey(const ValueKey('community-comment-owner-private')),
        findsOneWidget,
      );
      auth.publish(uid: 'owner', emailVerified: false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-comment-owner-private')),
        findsNothing,
      );
      expect(find.text('Posting as: @owner_handle'), findsNothing);
      expect(repository.privateReads, 3);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets(
    'sign-out and a different UID never reuse an injected owner repository',
    (tester) async {
      final auth = _LiveAuth(uid: 'owner', emailVerified: true);
      final repository = _BoundRepository('owner')
        ..pending = [_pending('owner-private', 'owner')];
      await pumpPage(tester, feed(auth, repository));
      expect(
        find.byKey(const ValueKey('community-comment-owner-private')),
        findsOneWidget,
      );
      final initialReads = repository.privateReads;
      auth.publish(uid: null);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-comment-owner-private')),
        findsNothing,
      );
      auth.publish(uid: 'different', emailVerified: true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-comment-owner-private')),
        findsNothing,
      );
      expect(repository.privateReads, initialReads);
      expect(
        find.text('Your account changed. Reopen community to continue safely.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('community-write-comment')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      expect(auth.listenerCount, 0);
      auth.dispose();
    },
  );

  testWidgets(
    'UID factory rebinds feed and discards a late previous-account response',
    (tester) async {
      final auth = _LiveAuth(uid: 'owner', emailVerified: true);
      final slow = _BoundRepository('owner')
        ..profileGate = Completer<CommunityProfile?>()
        ..pendingGate = Completer<List<CommunityComment>>();
      final next = _BoundRepository('next')
        ..pending = [_pending('next-private', 'next')];
      final guest = _BoundRepository(null)..profileValue = null;
      await pumpPage(
        tester,
        feed(
          auth,
          slow,
          repositories: {'owner': slow, 'next': next, null: guest},
        ),
      );
      auth.publish(uid: 'next', emailVerified: true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-comment-next-private')),
        findsOneWidget,
      );
      slow.profileGate!.complete(
        const CommunityProfile(
          handle: 'old_handle',
          displayMode: CommunityDisplayMode.handle,
        ),
      );
      slow.pendingGate!.complete([_pending('old-late-private', 'owner')]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-comment-old-late-private')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('community-comment-next-private')),
        findsOneWidget,
      );
      expect(next.profileReads, 1);
      expect(slow.profileReads, 1);
      auth.publish(uid: null);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-comment-next-private')),
        findsNothing,
      );
      expect(guest.privateReads, 0);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets(
    'identity clears old names, consent and blocks and ignores a late profile read',
    (tester) async {
      final auth = _LiveAuth(uid: 'owner', emailVerified: true);
      final slow = _BoundRepository('owner')
        ..profileGate = Completer<CommunityProfile?>();
      final next = _BoundRepository('next')..profileValue = null;
      await pumpPage(
        tester,
        profile(auth, slow, repositories: {'owner': slow, 'next': next}),
      );
      auth.publish(uid: 'next', emailVerified: true);
      await tester.pumpAndSettle();
      slow.profileGate!.complete(
        const CommunityProfile(
          handle: 'old_handle',
          nickname: 'Old nickname',
          displayMode: CommunityDisplayMode.nickname,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('community-handle')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('community-nickname')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Old nickname'), findsNothing);
      auth.publish(uid: 'next', emailVerified: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('community-handle')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(auth.listenerCount, 0);
      auth.dispose();
    },
  );

  testWidgets('an open private draft is discarded when the account changes', (
    tester,
  ) async {
    final auth = _LiveAuth(uid: 'owner', emailVerified: true);
    final old = _BoundRepository('owner');
    final next = _BoundRepository('next');
    await pumpPage(
      tester,
      feed(auth, old, repositories: {'owner': old, 'next': next}),
    );
    await tester.tap(find.byKey(const ValueKey('community-write-comment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('community-comment-body')),
      'A private unsent draft from the previous account.',
    );
    auth.publish(uid: 'next', emailVerified: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-comment-body')), findsNothing);
    expect(
      find.text('A private unsent draft from the previous account.'),
      findsNothing,
    );
    expect(old.posted, 0);
    expect(next.posted, 0);
    await tester.pumpWidget(const SizedBox());
    expect(auth.listenerCount, 0);
    auth.dispose();
  });

  testWidgets(
    'private vote choices are cleared before a different user can vote',
    (tester) async {
      final auth = _LiveAuth(uid: 'owner', emailVerified: true);
      final shared = CommunityComment(
        id: 'shared-comment',
        contentKey: 'tvmaze:show:1',
        contentKind: CommunityContentKind.series,
        authorUid: 'other',
        authorName: '@other',
        body: 'A public comment.',
        status: CommunityCommentStatus.approved,
        createdAt: DateTime(2026, 11, 6),
        upVotes: 1,
        score: 1,
      );
      final old = _BoundRepository('owner')
        ..approved = [shared]
        ..votes = {'shared-comment': 1};
      final next = _BoundRepository('next')..approved = [shared];
      await pumpPage(
        tester,
        feed(auth, old, repositories: {'owner': old, 'next': next}),
      );
      auth.publish(uid: 'next', emailVerified: true);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('community-vote-up-shared-comment')),
      );
      await tester.pumpAndSettle();
      expect(next.voteRequests, [('shared-comment', 1)]);
      expect(old.voteRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  for (final pageKind in ['feed', 'identity']) {
    testWidgets(
      '$pageKind rejects an unchanged repository relabeled with a new snapshot UID',
      (tester) async {
        final repository = _BoundRepository('owner')
          ..pending = [_pending('owner-private', 'owner')];
        Widget page(String uid) => pageKind == 'feed'
            ? CommunityPage(
                contentKey: 'tvmaze:show:1',
                seriesName: 'Series',
                repository: repository,
                viewerUid: uid,
                verified: true,
              )
            : CommunityProfilePage(
                repository: repository,
                viewerUid: uid,
                verified: true,
              );
        await pumpPage(tester, page('owner'));
        final initialReads = repository.privateReads;
        await pumpPage(tester, page('different'));
        expect(repository.privateReads, initialReads);
        expect(
          find.byKey(const ValueKey('community-comment-owner-private')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('community-handle')), findsNothing);
        expect(
          find.text(
            'Your account changed. Reopen community to continue safely.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$pageKind cancels stale reads and detaches its live auth listener on disposal',
      (tester) async {
        final auth = _LiveAuth(uid: 'owner', emailVerified: true);
        final repository = _BoundRepository('owner')
          ..profileGate = Completer<CommunityProfile?>();
        await pumpPage(
          tester,
          pageKind == 'feed'
              ? feed(auth, repository)
              : profile(auth, repository),
        );
        expect(auth.listenerCount, 1);
        await tester.pumpWidget(const SizedBox());
        expect(auth.listenerCount, 0);
        repository.profileGate!.complete(
          const CommunityProfile(
            handle: 'too_late',
            displayMode: CommunityDisplayMode.handle,
          ),
        );
        auth.publish(uid: null);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        auth.dispose();
      },
    );
  }
}

CommunityComment _pending(String id, String uid) => CommunityComment(
  id: id,
  contentKey: 'tvmaze:show:1',
  contentKind: CommunityContentKind.series,
  authorUid: uid,
  authorName: '@${uid}_handle',
  body: '$uid private pending comment',
  status: CommunityCommentStatus.pending,
  createdAt: DateTime(2026, 11, 6),
);

class _BoundRepository extends FakeCommunityRepository {
  _BoundRepository(this.uid) {
    profileValue = uid == null
        ? null
        : CommunityProfile(
            handle: '${uid}_handle',
            displayMode: CommunityDisplayMode.handle,
          );
  }
  final String? uid;
  int profileReads = 0;
  int pendingReads = 0;
  int blockReads = 0;
  int get privateReads => profileReads + pendingReads + blockReads;
  Completer<CommunityProfile?>? profileGate;
  Completer<List<CommunityComment>>? pendingGate;
  @override
  Future<CommunityProfile?> profile() async {
    profileReads++;
    if (profileGate != null) return profileGate!.future;
    return profileValue;
  }

  @override
  Future<List<CommunityComment>> pendingComments({
    required String contentKey,
  }) async {
    pendingReads++;
    if (pendingGate != null) return pendingGate!.future;
    return List.of(pending);
  }

  @override
  Future<Set<String>> blockedUsers() async {
    blockReads++;
    return Set.of(blocks);
  }
}

/// The UI consumes AuthController's resolved identity/trust contract. This fake
/// emits provider-token and verification updates without real Firebase traffic;
/// provider credential exchange still needs the existing real-device checks.
class _LiveAuth extends ChangeNotifier implements AuthController {
  _LiveAuth({
    String? uid,
    bool emailVerified = false,
    String provider = 'password',
    bool providerResolved = false,
  }) {
    _assign(uid, emailVerified, provider, providerResolved);
  }
  User? _user;
  bool _trusted = false;
  int listenerCount = 0;
  @override
  User? get user => _user;
  @override
  bool get canBackup => _user != null && _trusted;
  @override
  FirebaseAuth? get auth => null;
  @override
  bool get available => true;
  @override
  bool get busy => false;
  @override
  String? get errorCode => null;
  void _assign(String? uid, bool verified, String provider, bool resolved) {
    _user = uid == null ? null : _User(uid, verified);
    _trusted =
        verified ||
        (resolved && ['apple.com', 'google.com'].contains(provider));
  }

  void publish({
    required String? uid,
    bool emailVerified = false,
    String provider = 'password',
    bool providerResolved = false,
  }) {
    _assign(uid, emailVerified, provider, providerResolved);
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid, this.emailVerified);
  @override
  final String uid;
  @override
  final bool emailVerified;
  @override
  String get displayName => 'Private Account Name';
  @override
  String get email => 'private@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
