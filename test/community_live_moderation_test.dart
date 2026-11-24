import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_repository.dart';
import 'package:watchloom/features/community/presentation/community_page.dart';
import 'package:watchloom/features/community/presentation/community_strings.dart';
import 'helpers/fake_community_repository.dart';

const pending = CommunityComment(
  id: '12345678901234567890',
  contentKey: 'tvmaze:show:123',
  contentKind: CommunityContentKind.series,
  authorUid: 'owner',
  authorName: '@viewer',
  body: 'A submitted thought',
  status: CommunityCommentStatus.pending,
  createdAt: null,
);

class _LiveRepository extends FakeCommunityRepository
    implements CommunityModerationUpdates {
  final updates = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> moderationUpdates({required String contentKey}) =>
      updates.stream;
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _LiveRepository repository, {
    String uid = 'owner',
  }) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CommunityPage(
          contentKey: 'tvmaze:show:123',
          seriesName: 'Friends',
          repository: repository,
          viewerUid: uid,
          verified: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'server rejection and later approval refresh without Worker HTTP or a refresh tap',
    (tester) async {
      final repository = _LiveRepository()..pending = [pending];
      addTearDown(repository.updates.close);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, repository);
      expect(repository.updates.hasListener, true);
      repository.pending = [
        const CommunityComment(
          id: '12345678901234567890',
          contentKey: 'tvmaze:show:123',
          contentKind: CommunityContentKind.series,
          authorUid: 'owner',
          authorName: '@viewer',
          body: 'A submitted thought',
          status: CommunityCommentStatus.rejected,
          moderationReason: 'abuse',
          createdAt: null,
        ),
      ];
      repository.updates.add(null);
      await tester.pumpAndSettle();
      expect(
        find.text(CommunityStrings.forLanguage('en').rejection('abuse')),
        findsOneWidget,
      );
      repository.pending = [];
      repository.approved = [
        const CommunityComment(
          id: '12345678901234567890',
          contentKey: 'tvmaze:show:123',
          contentKind: CommunityContentKind.series,
          authorUid: 'owner',
          authorName: '@viewer',
          body: 'Revised and approved',
          status: CommunityCommentStatus.approved,
          createdAt: null,
        ),
      ];
      repository.updates.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Revised and approved'), findsOneWidget);
      expect(
        find.text(CommunityStrings.forLanguage('en').rejection('abuse')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(repository.updates.hasListener, false);
    },
  );

  testWidgets(
    'account switch detaches old private updates and listener errors remain safe',
    (tester) async {
      final old = _LiveRepository()..pending = [pending];
      final next = _LiveRepository();
      addTearDown(old.updates.close);
      addTearDown(next.updates.close);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, old);
      await open(tester, next, uid: 'new-owner');
      expect(old.updates.hasListener, false);
      expect(next.updates.hasListener, true);
      old.updates.add(null);
      await tester.pumpAndSettle();
      expect(find.text('A submitted thought'), findsNothing);
      next.updates.addError(StateError('private-provider-detail'));
      await tester.pump();
      expect(next.updates.hasListener, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
