// Standalone visual QA. Synthetic data, mocked native services, no Firebase or
// StoreKit calls. Never use this entry point for a release build.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart'
    show LiveWidgetController, TestDefaultBinaryMessengerBinding, find;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/features/account/presentation/account_session_controller.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/repositories/activity_repository.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/presentation/community_page.dart';
import 'package:watchloom/features/community/presentation/community_profile_page.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';
import 'package:watchloom/features/library/domain/repositories/library_repository.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/premium/data/subscription_repository.dart';
import 'package:watchloom/features/premium/domain/subscription.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:watchloom/features/settings/presentation/settings_page.dart';
import 'package:watchloom/features/shell/presentation/main_shell.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';

import '../test/helpers/fake_community_repository.dart';

class _PreviewBinding extends WidgetsFlutterBinding
    with TestDefaultBinaryMessengerBinding {
  Size size = const Size(390, 844);
  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) =>
      ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: 1,
      );

  void resize(Size value) {
    size = value;
    for (final view in renderViews) {
      view.configuration = createViewConfigurationFor(view);
    }
    scheduleFrame();
  }
}

class _Library implements LibraryRepository {
  final entries = <int, LibraryEntry>{
    for (var id = 1; id <= 3; id++)
      id: LibraryEntry(
        showId: id,
        name: ['Northbound', 'A Quiet Orbit', 'City of Signals'][id - 1],
        summary: 'A synthetic series used only for interface previews.',
        genres: const ['Drama'],
        status: LibraryStatus.watching,
        addedAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 11, 5),
        lastSeason: 1,
        lastEpisode: 4,
      ),
  };
  @override
  Future<List<LibraryEntry>> getEntries() async => entries.values.toList();
  @override
  Future<LibraryEntry?> getEntry(int showId) async => entries[showId];
  @override
  Future<void> saveEntry(LibraryEntry entry) async =>
      entries[entry.showId] = entry;
  @override
  Future<void> deleteEntry(int showId) async => entries.remove(showId);
}

class _Activity implements ActivityRepository {
  final achievements = <UnlockedAchievement>[];
  final logs = <EpisodeWatchLog>[
    for (var index = 0; index < 40; index++)
      EpisodeWatchLog(
        id: index + 1,
        showId: index % 3 + 1,
        showName: ['Northbound', 'A Quiet Orbit', 'City of Signals'][index % 3],
        episodeId: index + 1000,
        season: 1,
        episodeNumber: index + 1,
        watchedAt: DateTime(2026, 11, index % 5 + 1, 10 + index % 10),
        runtimeMinutes: index < 3 ? null : 45,
        source: WatchLogSource.manualWatch,
      ),
    for (var month = 9; month <= 10; month++)
      EpisodeWatchLog(
        id: month + 100,
        showId: 1,
        showName: 'Northbound',
        episodeId: month + 2000,
        season: 1,
        episodeNumber: 1,
        watchedAt: DateTime(2026, month, 1, 12),
        runtimeMinutes: 45,
        source: WatchLogSource.manualWatch,
      ),
  ];
  @override
  Future<List<EpisodeWatchLog>> getWatchLogs() async => List.of(logs);
  @override
  Future<List<UnlockedAchievement>> getUnlockedAchievements() async =>
      List.of(achievements);
  @override
  Future<bool> unlockAchievement(UnlockedAchievement value) async {
    if (achievements.any((saved) => saved.code == value.code)) return false;
    achievements.add(value);
    return true;
  }

  @override
  Future<bool> recordEpisode({
    required EpisodeWatchLog log,
    required LibraryEntry updatedLibraryEntry,
  }) async => throw UnsupportedError('Read-only preview');
  @override
  Future<EpisodeWatchLog?> undoLatestEpisode({
    required LibraryEntry currentLibraryEntry,
  }) async => throw UnsupportedError('Read-only preview');
}

class _Shows implements ShowRepository {
  _Shows(this.library);
  final _Library library;
  @override
  Future<TvShow> getShow(int showId) async =>
      library.entries[showId]!.toTvShow();
  @override
  Future<List<TvShow>> getShowsPage(int page) async =>
      library.entries.values.map((entry) => entry.toTvShow()).toList();
  @override
  Future<List<TvShow>> searchShows(String query) => getShowsPage(0);
  @override
  Future<List<TvEpisode>> getEpisodes(int showId) async => const [];
}

class _Subscriptions implements SubscriptionRepository {
  @override
  bool get isSupported => true;
  @override
  Stream<String> get updates => const Stream.empty();
  @override
  Future<PremiumEntitlement> readEntitlement() async =>
      const PremiumEntitlement();
  @override
  Future<PremiumProduct> readProduct() async =>
      const PremiumProduct(displayPrice: r'$0.99', currencyCode: 'USD');
  @override
  Future<PurchaseOutcome> purchase() async =>
      throw UnsupportedError('No purchases in preview');
  @override
  Future<PremiumEntitlement> restore() => readEntitlement();
  @override
  Future<void> manage() async {}
  @override
  Future<void> openPrivacy() async {}
  @override
  Future<void> openTerms() async {}
}

FakeCommunityRepository _community() {
  CommunityComment comment({
    required String id,
    required String author,
    required String text,
    String? parent,
    bool spoiler = false,
    CommunityCommentStatus status = CommunityCommentStatus.approved,
  }) => CommunityComment(
    id: id,
    contentKey: 'tvmaze:show:3',
    contentKind: CommunityContentKind.series,
    authorUid: 'synthetic_$author',
    authorName: '@$author',
    body: text,
    parentId: parent,
    status: status,
    createdAt: DateTime(2026, 11, 5, 20),
    isSpoiler: spoiler,
  );
  return FakeCommunityRepository()
    ..profileValue = const CommunityProfile(
      handle: 'frames_in_moonlight',
      nickname: 'Bir Bölüm Daha',
      displayMode: CommunityDisplayMode.nickname,
    )
    ..approved = [
      comment(
        id: 'first',
        author: 'quiet_viewer',
        text:
            'The quiet scene at the station said more than the finale. '
            'The pacing gave every character room to breathe.',
      ),
      comment(
        id: 'reply',
        author: 'orbit_reader',
        text: 'The sound design made that moment work so well.',
        parent: 'first',
      ),
      comment(
        id: 'spoiler',
        author: 'night_frame',
        text: 'A synthetic spoiler used to verify the reveal control.',
        spoiler: true,
      ),
    ]
    ..pending = [
      comment(
        id: 'pending',
        author: 'preview_viewer',
        text: 'Bu bölümün sakin anlatımını ve müziklerini çok sevdim.',
        status: CommunityCommentStatus.pending,
      ),
    ];
}

Future<void> main() async {
  final timeout = Timer(const Duration(seconds: 100), () {
    stderr.writeln('Preview timeout');
    exit(1);
  });
  final issues = <Map<String, String>>[];
  var current = 'setup';
  try {
    final binding = _PreviewBinding();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final driver = LiveWidgetController(binding);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'getNotificationAppLaunchDetails'
          ? {'notificationLaunchedApp': false}
          : true,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'Europe/Istanbul',
    );
    // This is a standalone test harness; disk preferences must stay untouched.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'watchloom_language': 'tr',
      AdPrivacyController.preferenceKey: '{"allowed":false}',
    });
    final preferences = await SharedPreferences.getInstance();
    final locale = await AppLocaleController.create();
    final libraryRepository = _Library();
    final library = LibraryController(libraryRepository);
    final shows = _Shows(libraryRepository);
    final activity = WatchActivityController(
      repository: _Activity(),
      libraryController: library,
      showRepository: shows,
      now: () => DateTime(2026, 11, 6, 20),
    );
    final premium = SubscriptionController(_Subscriptions());
    final privacy = AdPrivacyController(preferences);
    final auth = AuthController.guestOnly();
    final session = AccountSessionController(
      auth: auth,
      showRepository: shows,
      accessPolicy: const LibraryAccessPolicy.free(),
      guestDatabase: WatchloomDatabase(),
      library: library,
      activity: activity,
    );
    await library.load();
    await activity.load();
    await premium.initialize();
    FlutterError.onError = (details) {
      issues.add({'screen': current, 'error': details.exceptionAsString()});
      stderr.writeln('PREVIEW $current: $details');
    };
    final boundaryKey = GlobalKey();
    var navigator = GlobalKey<NavigatorState>();
    final output = Directory('build/previews')..createSync(recursive: true);

    Future<void> mount(
      Size size,
      double scale, {
      Widget? page,
      int? tab,
    }) async {
      binding.resize(size);
      navigator = GlobalKey<NavigatorState>();
      runApp(
        AppScope(
          showRepository: shows,
          libraryController: library,
          activityController: activity,
          premiumController: premium,
          adPrivacyController: privacy,
          accountSession: session,
          child: MaterialApp(
            key: UniqueKey(),
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            locale: locale.locale,
            supportedLocales: const [Locale('tr'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: EdgeInsets.only(
                  top: size.width == 320 ? 20 : 44,
                  bottom: size.width == 320 ? 0 : 34,
                ),
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: boundaryKey, child: child!),
            ),
            home: MainShell(localeController: locale),
          ),
        ),
      );
      await driver.pump(const Duration(milliseconds: 180));
      if (page != null) {
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute(builder: (_) => page),
          ),
        );
      } else if (tab != null) {
        await driver.tap(find.byType(NavigationDestination).at(tab));
      }
      // iOS page transitions must finish before a PNG is treated as evidence.
      await driver.pump(const Duration(milliseconds: 650));
    }

    Future<void> capture(String name) async {
      await driver.pump(const Duration(milliseconds: 100));
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File(
        '${output.path}/$name.png',
      ).writeAsBytesSync(png.buffer.asUint8List());
      image.dispose();
      stdout.writeln('Preview: $name');
    }

    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 1.8),
    ]) {
      final suffix = '${size.width.toInt()}-${(scale * 100).toInt()}';
      for (final (name, tab) in [
        ('home', 0),
        ('library', 1),
        ('search', 2),
        ('profile', 4),
        ('month', 3),
      ]) {
        current = '$name-$suffix';
        await mount(size, scale, tab: tab);
        if (tab == 2) {
          final field =
              find.byType(TextField).evaluate().single.widget as TextField;
          field.controller!.text = 'Orbit';
          field.onSubmitted?.call('Orbit');
          await driver.pump(const Duration(milliseconds: 650));
        }
        await capture(current);
        if (tab == 0 || tab == 1 || tab == 2 || tab == 3) {
          await driver.drag(
            find.byType(Scrollable).first,
            const Offset(0, -330),
          );
          await driver.pump(const Duration(milliseconds: 300));
          await capture('$current-lower');
        }
      }
      current = 'settings-$suffix';
      await mount(size, scale, page: SettingsPage(localeController: locale));
      await capture(current);
      await driver.drag(find.byType(ListView).last, const Offset(0, -460));
      await driver.pump(const Duration(milliseconds: 200));
      await capture('$current-lower');

      current = 'community-profile-$suffix';
      await mount(
        size,
        scale,
        page: CommunityProfilePage(
          repository: _community(),
          viewerUid: 'synthetic_preview_viewer',
          verified: true,
        ),
      );
      await capture(current);
      await driver.drag(find.byType(ListView).last, const Offset(0, -600));
      await driver.pump(const Duration(milliseconds: 200));
      await capture('$current-lower');

      current = 'community-feed-$suffix';
      await mount(
        size,
        scale,
        page: CommunityPage(
          contentKey: 'tvmaze:show:3',
          seriesName: 'City of Signals',
          repository: _community(),
          viewerUid: 'synthetic_preview_viewer',
          verified: true,
        ),
      );
      await capture(current);
      final write = find.byKey(const ValueKey('community-write-comment'));
      // A large-text feed can lazily build the write action below the viewport.
      for (var step = 0; step < 12 && write.evaluate().isEmpty; step++) {
        await driver.drag(find.byType(ListView).last, const Offset(0, -240));
        await driver.pump(const Duration(milliseconds: 160));
      }
      await driver.ensureVisible(write);
      await driver.pump(const Duration(milliseconds: 150));
      await driver.tap(write);
      await driver.pump(const Duration(milliseconds: 650));
      current = 'community-composer-$suffix';
      final field = find.byKey(const ValueKey('community-comment-body'));
      if (field.evaluate().isEmpty) throw StateError('Composer did not open');
      (field.evaluate().single.widget as TextField).controller!.text =
          'Karakterlerin gelişimini ve bölümün sakin anlatımını sevdim.';
      await capture(current);
      await driver.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -520),
      );
      await driver.pump(const Duration(milliseconds: 300));
      await capture('$current-lower');
      navigator.currentState!.pop();
      await driver.pump(const Duration(milliseconds: 650));
      await driver.drag(find.byType(ListView).last, const Offset(0, -650));
      await driver.pump(const Duration(milliseconds: 300));
      await capture('community-feed-$suffix-lower');
    }
    File(
      '${output.path}/preview-issues.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(issues));
    stdout.writeln(
      'Visual previews complete: ${issues.length} Flutter issues.',
    );
    timeout.cancel();
    session.dispose();
    auth.dispose();
    activity.dispose();
    library.dispose();
    premium.dispose();
    privacy.dispose();
    locale.dispose();
    exit(issues.isEmpty ? 0 : 2);
  } catch (error, stack) {
    final output = Directory('build/previews')..createSync(recursive: true);
    File('${output.path}/preview-issues.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert([
        ...issues,
        {'screen': current, 'harnessError': '$error'},
      ]),
    );
    stderr.writeln('$error\n$stack');
    timeout.cancel();
    exit(1);
  }
}
