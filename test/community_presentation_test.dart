import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/entities/watch_activity_summary.dart';
import 'package:watchloom/features/activity/presentation/widgets/monthly_activity_summary_card.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/presentation/community_page.dart';
import 'package:watchloom/features/community/presentation/community_profile_page.dart';
import 'package:watchloom/features/settings/presentation/pages/license_notices_page.dart';
import 'helpers/fake_community_repository.dart';

void main() {
  Future<void> harness(
    WidgetTester tester,
    Widget page, {
    String language = 'en',
    double scale = 1.8,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = const Size(320, 760);
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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(bottom: 34),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(
    WidgetTester tester,
    Finder target, {
    double delta = 180,
  }) async {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'tr']) {
    testWidgets(
      'monthly duration and active calendar days remain distinct at large text ($language)',
      (tester) async {
        final summary = WatchActivitySummary.fromLogs(
          month: DateTime(2026, 11),
          asOf: DateTime(2026, 11, 6),
          episodeLogs: [
            for (var index = 0; index < 3; index++)
              EpisodeWatchLog(
                showId: index == 2 ? 2 : 1,
                showName: 'Series',
                episodeId: index + 1,
                season: 1,
                episodeNumber: index + 1,
                watchedAt: DateTime(2026, 11, index == 2 ? 4 : 3),
                source: WatchLogSource.manualWatch,
                runtimeMinutes: index == 0
                    ? 1500
                    : index == 1
                    ? 1550
                    : null,
              ),
          ],
        );
        await harness(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: MonthlyActivitySummaryCard(summary: summary),
            ),
          ),
          language: language,
        );
        expect(
          find.text(language == 'tr' ? '2 gün 2 sa 50 dk' : '2 d 2 h 50 m'),
          findsOneWidget,
        );
        await scrollTo(
          tester,
          find.text(
            language == 'tr' ? 'Aktif izleme günü' : 'Active watch days',
          ),
        );
        expect(
          find.byKey(const ValueKey('monthly-unknown-runtime')),
          findsOneWidget,
        );
        expect(summary.activeDayCount, 2);
        expect(summary.seriesCount, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'identity has explicit name selection, no autofill and mandatory consent ($language)',
      (tester) async {
        final repository = FakeCommunityRepository()..profileValue = null;
        await harness(
          tester,
          CommunityProfilePage(
            repository: repository,
            viewerUid: 'owner',
            verified: true,
          ),
          language: language,
        );
        final handle = find.byKey(const ValueKey('community-handle'));
        await scrollTo(tester, handle);
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
        await tester.enterText(handle, 'seriesfan');
        await scrollTo(
          tester,
          find.byKey(const ValueKey('community-nickname')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('community-nickname')),
          'Moon Viewer',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        final nicknameOption = find
            .byType(RadioListTile<CommunityDisplayMode>)
            .last;
        await scrollTo(tester, nicknameOption);
        await tester.tap(nicknameOption);
        await tester.pumpAndSettle();
        await scrollTo(
          tester,
          find.byKey(const ValueKey('community-public-name-preview')),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('community-public-name-preview')),
              )
              .data,
          'Moon Viewer',
        );
        await scrollTo(
          tester,
          find.byKey(const ValueKey('community-save-identity')),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('community-save-identity')),
              )
              .onPressed,
          isNull,
        );
        final consentCheckbox = find.descendant(
          of: find.byKey(const ValueKey('community-terms-consent')),
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(consentCheckbox);
        await tester.pumpAndSettle();
        await tester.tap(consentCheckbox);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('community-save-identity')),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'comment composer survives keyboard and submits to pending, never approved ($language)',
      (tester) async {
        final repository = FakeCommunityRepository();
        await harness(
          tester,
          CommunityPage(
            contentKey: 'tvmaze:show:1',
            seriesName: 'A thoughtful series',
            repository: repository,
            viewerUid: 'owner',
            verified: true,
          ),
          language: language,
          keyboard: 240,
        );
        await scrollTo(
          tester,
          find.byKey(const ValueKey('community-write-comment')),
        );
        await tester.tap(find.byKey(const ValueKey('community-write-comment')));
        await tester.pumpAndSettle();
        final body = find.byKey(const ValueKey('community-comment-body'));
        await tester.enterText(
          body,
          'An excellent season with thoughtful characters.',
        );
        await tester.pumpAndSettle();
        final submit = find.byKey(const ValueKey('community-submit-comment'));
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(repository.approved, isEmpty);
        expect(
          repository.pending.single.status,
          CommunityCommentStatus.pending,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await scrollTo(
          tester,
          find.byKey(const ValueKey('community-status-submitted1')),
        );
        expect(
          find.text(
            language == 'tr'
                ? 'Onay bekliyor · sen ve moderatörler görebilir'
                : 'Awaiting moderation · visible to you and moderators',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  CommunityComment comment(
    String id, {
    String author = 'other',
    bool spoiler = false,
  }) => CommunityComment(
    id: id,
    contentKey: 'tvmaze:show:1',
    contentKind: CommunityContentKind.series,
    authorUid: author,
    authorName: '@seriesfan',
    body: 'The final scene changes everything.',
    status: CommunityCommentStatus.approved,
    createdAt: DateTime(2026, 11, 5),
    isSpoiler: spoiler,
  );

  testWidgets('approved feed survives a private-account read failure', (
    tester,
  ) async {
    final repository = FakeCommunityRepository()
      ..approved = [comment('approved')]
      ..privateReadFailure = const CommunityException(
        CommunityFailure.permissionDenied,
      );
    await harness(
      tester,
      CommunityPage(
        contentKey: 'tvmaze:show:1',
        seriesName: 'Series',
        repository: repository,
        viewerUid: 'owner',
        verified: true,
      ),
    );
    await scrollTo(
      tester,
      find.byKey(const ValueKey('community-comment-approved')),
    );
    expect(find.text('The final scene changes everything.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'spoilers stay hidden until chosen and blocked authors stay out of feed',
    (tester) async {
      final repository = FakeCommunityRepository()
        ..approved = [
          comment('spoiler', spoiler: true),
          comment('blocked', author: 'blocked-author'),
        ]
        ..blocks = {'blocked-author'};
      await harness(
        tester,
        CommunityPage(
          contentKey: 'tvmaze:show:1',
          seriesName: 'Series',
          repository: repository,
          viewerUid: 'owner',
          verified: true,
        ),
      );
      await scrollTo(
        tester,
        find.byKey(const ValueKey('reveal-spoiler-spoiler')),
      );
      expect(find.text('The final scene changes everything.'), findsNothing);
      expect(
        find.byKey(const ValueKey('community-comment-blocked')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('reveal-spoiler-spoiler')));
      await tester.pumpAndSettle();
      expect(find.text('The final scene changes everything.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed post retains draft and displays a readable error', (
    tester,
  ) async {
    final repository = FakeCommunityRepository()
      ..postFailure = const CommunityException(CommunityFailure.rateLimited);
    await harness(
      tester,
      CommunityPage(
        contentKey: 'tvmaze:show:1',
        seriesName: 'Series',
        repository: repository,
        viewerUid: 'owner',
        verified: true,
      ),
    );
    await scrollTo(
      tester,
      find.byKey(const ValueKey('community-write-comment')),
    );
    await tester.tap(find.byKey(const ValueKey('community-write-comment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('community-comment-body')),
      'Keep this draft for another attempt.',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('community-submit-comment')),
    );
    await tester.tap(find.byKey(const ValueKey('community-submit-comment')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('community-comment-body')),
          )
          .controller!
          .text,
      'Keep this draft for another attempt.',
    );
    expect(repository.pending, isEmpty);
    expect(
      find.text(
        'You are sending too quickly or reached the daily limit. Please try again later.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('report remains available while submissions are paused', (
    tester,
  ) async {
    final repository = FakeCommunityRepository()
      ..availabilityValue = const CommunityAvailability(
        enabled: false,
        moderationReady: false,
      )
      ..approved = [comment('reportable')];
    await harness(
      tester,
      CommunityPage(
        contentKey: 'tvmaze:show:1',
        seriesName: 'Series',
        repository: repository,
        viewerUid: 'owner',
        verified: true,
      ),
    );
    final menu = find.byType(PopupMenuButton<String>);
    await scrollTo(tester, menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harassment or threats'));
    await tester.pumpAndSettle();
    expect(repository.reports, [('reportable', CommunityReportReason.abuse)]);
    expect(find.byKey(const ValueKey('community-write-comment')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked accounts can be unblocked at large Turkish text', (
    tester,
  ) async {
    final repository = FakeCommunityRepository()
      ..blocks = {'blocked-random-account'};
    await harness(
      tester,
      CommunityProfilePage(
        repository: repository,
        viewerUid: 'owner',
        verified: true,
      ),
      language: 'tr',
    );
    final unblock = find.byKey(
      const ValueKey('community-unblock-blocked-random-account'),
    );
    await scrollTo(tester, unblock);
    await tester.tap(unblock);
    await tester.pumpAndSettle();
    expect(repository.blocks, isEmpty);
    expect(find.text('Henüz kimseyi engellemedin.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hosted notices retain a reachable offline alternative', (
    tester,
  ) async {
    await harness(tester, const LicenseNoticesPage());
    await scrollTo(
      tester,
      find.byKey(const ValueKey('offline-license-notices')),
    );
    expect(
      find.byKey(const ValueKey('hosted-license-notices')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('offline-license-notices')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
