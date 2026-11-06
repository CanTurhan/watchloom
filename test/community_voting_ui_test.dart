import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/presentation/community_page.dart';
import 'package:watchloom/features/community/presentation/community_profile_page.dart';
import 'helpers/fake_community_repository.dart';

CommunityComment _comment(
  String id, {
  String author = 'other',
  int score = 0,
  String? parent,
  int day = 5,
  CommunityCommentStatus status = CommunityCommentStatus.approved,
}) => CommunityComment(
  id: id,
  contentKey: 'tvmaze:show:1',
  contentKind: CommunityContentKind.series,
  authorUid: author,
  authorName: '@fan',
  body: 'A thoughtful series discussion.',
  parentId: parent,
  status: status,
  createdAt: DateTime(2026, 11, day),
  upVotes: score > 0 ? score : 0,
  downVotes: score < 0 ? -score : 0,
  score: score,
);

void main() {
  Future<void> harness(
    WidgetTester tester,
    FakeCommunityRepository repository, {
    bool small = false,
    String language = 'en',
  }) async {
    tester.view.physicalSize = small
        ? const Size(320, 760)
        : const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(small ? 1.8 : 1)),
          child: child!,
        ),
        home: CommunityPage(
          contentKey: 'tvmaze:show:1',
          seriesName: 'Series',
          repository: repository,
          viewerUid: 'owner',
          verified: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'best first ranks roots and keeps replies threaded; newest is a real query',
    (tester) async {
      final repository = FakeCommunityRepository()
        ..approved = [
          _comment('new-low', score: 1, day: 6),
          _comment('old-best', score: 5, day: 4),
          _comment('reply', score: -1, parent: 'old-best', day: 5),
        ];
      await harness(tester, repository);
      expect(repository.sortRequests.last, CommunityCommentSort.best);
      final best = find.byKey(const ValueKey('community-comment-old-best'));
      final reply = find.byKey(const ValueKey('community-comment-reply'));
      final newest = find.byKey(const ValueKey('community-comment-new-low'));
      expect(tester.getTopLeft(best).dy, lessThan(tester.getTopLeft(reply).dy));
      expect(
        tester.getTopLeft(reply).dy,
        lessThan(tester.getTopLeft(newest).dy),
      );
      await tester.tap(find.byKey(const ValueKey('community-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Newest first').last);
      await tester.pumpAndSettle();
      expect(repository.sortRequests.last, CommunityCommentSort.newest);
      expect(
        tester.getTopLeft(newest).dy,
        lessThan(tester.getTopLeft(best).dy),
      );
      expect(tester.getTopLeft(best).dy, lessThan(tester.getTopLeft(reply).dy));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'same vote toggles off and opposite vote switches with acknowledged totals',
    (tester) async {
      final repository = FakeCommunityRepository()
        ..approved = [_comment('target')];
      await harness(tester, repository);
      final up = find.byKey(const ValueKey('community-vote-up-target'));
      final down = find.byKey(const ValueKey('community-vote-down-target'));
      for (final direction in [1, 1, -1, 1]) {
        await tester.tap(direction == 1 ? up : down);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(repository.voteRequests, [
        ('target', 1),
        ('target', 0),
        ('target', -1),
        ('target', 1),
      ]);
      expect(repository.votes['target'], 1);
      expect(find.text('Score: 1'), findsOneWidget);
      expect(repository.approved.single.downVotes, 0);
    },
  );
  testWidgets(
    'in-flight vote and brief cooldown prevent duplicate requests without optimistic counters',
    (tester) async {
      final gate = Completer<void>();
      final repository = FakeCommunityRepository()
        ..approved = [_comment('target'), _comment('other-target')]
        ..voteGate = gate.future;
      await harness(tester, repository);
      final up = find.byKey(const ValueKey('community-vote-up-target'));
      await tester.tap(up);
      await tester.pump();
      expect(repository.voteRequests.length, 1);
      expect(tester.widget<TextButton>(up).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('community-vote-up-other-target')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('community-score-target')))
            .data,
        'Score: 0',
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('community-score-target')))
            .data,
        'Score: 1',
      );
      expect(repository.voteRequests.length, 1);
      expect(tester.widget<TextButton>(up).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<TextButton>(up).onPressed, isNotNull);
    },
  );
  testWidgets(
    'failed and self votes do not change displayed score; pending has no votes',
    (tester) async {
      final repository = FakeCommunityRepository()
        ..approved = [_comment('other'), _comment('self', author: 'owner')]
        ..pending = [
          _comment(
            'pending',
            author: 'owner',
            status: CommunityCommentStatus.pending,
          ),
        ]
        ..voteFailure = const CommunityException(
          CommunityFailure.permissionDenied,
        );
      await harness(tester, repository);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('community-vote-up-self')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('community-vote-up-pending')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('community-vote-up-other')));
      await tester.pumpAndSettle();
      expect(repository.votes, isEmpty);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('community-score-other')))
            .data,
        'Score: 0',
      );
      expect(
        find.text(
          'Your vote could not be recorded. Wait a moment, refresh, or review your community consent.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('old consent requires a fresh explicit checkbox before voting', (
    tester,
  ) async {
    final repository = FakeCommunityRepository()
      ..approved = [_comment('other')]
      ..profileValue = const CommunityProfile(
        handle: 'fan',
        displayMode: CommunityDisplayMode.handle,
        acceptedPolicyVersion: '2026-11-05',
      );
    await harness(tester, repository);
    await tester.tap(find.byKey(const ValueKey('community-vote-up-other')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityProfilePage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('community-renew-consent')),
      findsOneWidget,
    );
    expect(repository.voteRequests, isEmpty);
  });
  for (final language in ['en', 'tr']) {
    testWidgets(
      'rank/vote controls remain accessible on 320px at180percent ($language)',
      (tester) async {
        final repository = FakeCommunityRepository()
          ..approved = [_comment('target', score: 1000000000)];
        await harness(tester, repository, small: true, language: language);
        final up = find.byKey(const ValueKey('community-vote-up-target'));
        await tester.scrollUntilVisible(
          up,
          180,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TextButton>(up).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
