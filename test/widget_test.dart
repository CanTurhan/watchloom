import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/theme/app_theme.dart';
import 'package:watchloom/core/monetization/watchloom_banner.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/core/monetization/ad_privacy_gate.dart';
import 'package:watchloom/features/settings/presentation/pages/ad_privacy_page.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';
import 'package:watchloom/features/settings/presentation/widgets/clear_local_data_tile.dart';
import 'package:watchloom/features/premium/domain/subscription.dart';
import 'package:watchloom/features/premium/presentation/premium_page.dart';
import 'package:watchloom/features/library/presentation/widgets/library_edit_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchloom/app/watchloom_app.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/domain/repositories/activity_repository.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/domain/repositories/library_repository.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:watchloom/features/profile/presentation/profile_page.dart';
import 'package:watchloom/features/settings/presentation/settings_page.dart';
import 'helpers/fake_subscription_repository.dart';

void main() {
  testWidgets('Watchloom opens on the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({'watchloom_language': 'en'});

    final localeController = await AppLocaleController.create();
    final adPrivacy = AdPrivacyController(
      await SharedPreferences.getInstance(),
    );
    addTearDown(adPrivacy.dispose);
    final subscriptionRepository = FakeSubscriptionRepository();
    final premium = SubscriptionController(subscriptionRepository);
    addTearDown(() async {
      premium.dispose();
      await subscriptionRepository.close();
    });

    final libraryRepository = _FakeLibraryRepository();

    final libraryController = LibraryController(libraryRepository);

    await libraryController.load();

    final showRepository = _FakeShowRepository();

    final activityController = WatchActivityController(
      repository: _FakeActivityRepository(libraryRepository),
      libraryController: libraryController,
      showRepository: showRepository,
    );

    await activityController.load();

    await tester.pumpWidget(
      WatchloomApp(
        localeController: localeController,
        showRepository: showRepository,
        libraryController: libraryController,
        activityController: activityController,
        premiumController: premium,
        adPrivacyController: adPrivacy,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('WATCHLOOM'), findsOneWidget);

    expect(find.text('Your shows, remembered.'), findsOneWidget);
  });

  Future<void> premiumHarness(
    WidgetTester tester,
    SubscriptionController premium, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    LibraryController? libraryController,
    AdPrivacyController? adPrivacyController,
    Widget home = const PremiumPage(libraryLimitReached: true),
  }) async {
    final adPrivacy =
        adPrivacyController ??
        AdPrivacyController(await SharedPreferences.getInstance());
    addTearDown(adPrivacy.dispose);
    final repository = _FakeLibraryRepository();
    final library = libraryController ?? LibraryController(repository);
    final shows = _FakeShowRepository();
    final activity = WatchActivityController(
      repository: _FakeActivityRepository(repository),
      libraryController: library,
      showRepository: shows,
    );
    addTearDown(library.dispose);
    addTearDown(activity.dispose);
    await tester.pumpWidget(
      AppScope(
        showRepository: shows,
        libraryController: library,
        activityController: activity,
        premiumController: premium,
        adPrivacyController: adPrivacy,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'tr']) {
    testWidgets(
      'profile has a single settings entry and one complete settings flow ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'watchloom_language': language,
        });
        final locale = await AppLocaleController.create();
        addTearDown(locale.dispose);
        final store = FakeSubscriptionRepository();
        final premium = SubscriptionController(store);
        addTearDown(() async {
          premium.dispose();
          await store.close();
        });
        await premiumHarness(
          tester,
          premium,
          locale: Locale(language),
          textScale: 1.8,
          home: ProfilePage(localeController: locale),
        );
        expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('profile-settings')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(
          find.text(language == 'tr' ? 'Dil' : 'Language'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byIcon(Icons.notifications_outlined),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byIcon(Icons.code_rounded),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byIcon(Icons.code_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'monthly Premium uses the Apple price with large text ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = FakeSubscriptionRepository()
          ..product = const PremiumProduct(
            displayPrice: '₺39,99',
            currencyCode: 'TRY',
          );
        final premium = SubscriptionController(store);
        addTearDown(() async {
          premium.dispose();
          await store.close();
        });
        await premium.initialize();
        await premiumHarness(
          tester,
          premium,
          locale: Locale(language),
          textScale: 2,
        );
        await tester.ensureVisible(find.byKey(const Key('monthly-price')));
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'tr' ? '₺39,99 / ay' : '₺39,99 / month'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('restore-purchases')));
        await tester.tap(find.byKey(const Key('restore-purchases')));
        await tester.pumpAndSettle();
        expect(store.restoreCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing Store price disables checkout and offers retry', (
    tester,
  ) async {
    final store = FakeSubscriptionRepository()
      ..productError = StateError('missing');
    final premium = SubscriptionController(store);
    addTearDown(() async {
      premium.dispose();
      await store.close();
    });
    await premium.initialize();
    await premiumHarness(tester, premium);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('subscribe-monthly')))
          .onPressed,
      isNull,
    );
    expect(find.text('Try Again'), findsOneWidget);
    expect(store.purchaseCount, 0);
  });

  testWidgets(
    'sixth show opens Premium; cancelling leaves the library unchanged',
    (tester) async {
      final store = FakeSubscriptionRepository();
      final premium = SubscriptionController(store);
      addTearDown(() async {
        premium.dispose();
        await store.close();
      });
      await premium.initialize();
      final repository = _FakeLibraryRepository();
      for (var id = 1; id <= 5; id++) {
        await repository.saveEntry(
          LibraryEntry(
            showId: id,
            name: 'Show $id',
            summary: '',
            genres: const [],
            status: LibraryStatus.watchlist,
            addedAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
      }
      final library = LibraryController(repository);
      await library.load();
      await premiumHarness(
        tester,
        premium,
        libraryController: library,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => LibraryEditSheet.open(
                context,
                const TvShow(
                  id: 6,
                  name: 'Sixth show',
                  summary: '',
                  genres: [],
                ),
              ),
              child: const Text('Add show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add show'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumPage), findsOneWidget);
      expect(find.byType(LibraryEditSheet), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(library.entries.length, 5);
      expect(library.findByShowId(6), isNull);
      expect(store.purchaseCount, 0);
    },
  );

  testWidgets(
    'editing an existing show above the cap preserves favorites and notes',
    (tester) async {
      final store = FakeSubscriptionRepository();
      final premium = SubscriptionController(store);
      addTearDown(() async {
        premium.dispose();
        await store.close();
      });
      await premium.initialize();
      final repository = _FakeLibraryRepository();
      for (var id = 1; id <= 7; id++) {
        await repository.saveEntry(
          LibraryEntry(
            showId: id,
            name: 'Show $id',
            summary: '',
            genres: const [],
            status: LibraryStatus.watchlist,
            isFavorite: true,
            personalNote: 'My note',
            addedAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
      }
      final library = LibraryController(repository);
      await library.load();
      await premiumHarness(
        tester,
        premium,
        libraryController: library,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => LibraryEditSheet.open(
                context,
                const TvShow(id: 1, name: 'Show 1', summary: '', genres: []),
              ),
              child: const Text('Edit show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit show'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumPage), findsNothing);
      expect(find.byType(LibraryEditSheet), findsOneWidget);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.entries.length, 7);
      expect(library.findByShowId(1)?.isFavorite, isTrue);
      expect(library.findByShowId(1)?.personalNote, 'My note');
    },
  );

  testWidgets('free users can refuse advertising and the app remains usable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final privacy = AdPrivacyController(await SharedPreferences.getInstance());
    final store = FakeSubscriptionRepository();
    final premium = SubscriptionController(store);
    addTearDown(() async {
      premium.dispose();
      await store.close();
    });
    await premium.initialize();
    await premiumHarness(
      tester,
      premium,
      adPrivacyController: privacy,
      home: AdPrivacyGate(
        premium: premium,
        privacy: privacy,
        child: const Scaffold(body: Text('Free library remains available')),
      ),
    );
    expect(find.byType(AdPrivacyPage), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('decline-ads')));
    await tester.tap(find.byKey(const Key('decline-ads')));
    await tester.pumpAndSettle();
    expect(privacy.adsAllowed, isFalse);
    expect(find.text('Free library remains available'), findsOneWidget);
    await premium.refreshEntitlement();
    await tester.pumpAndSettle();
    expect(find.byType(AdPrivacyPage), findsNothing);
    expect(premium.hasAccess, isFalse);
  });

  testWidgets(
    'the privacy policy opens in the app without a network connection',
    (tester) async {
      final store = FakeSubscriptionRepository();
      final premium = SubscriptionController(store);
      addTearDown(() async {
        premium.dispose();
        await store.close();
      });
      await premium.initialize();
      await premiumHarness(tester, premium);
      final privacyButton = find.widgetWithText(TextButton, 'Privacy Policy');
      await tester.ensureVisible(privacyButton);
      await tester.tap(privacyButton);
      await tester.pumpAndSettle();
      expect(find.byType(LegalPage), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      final page = tester.widget<LegalPage>(find.byType(LegalPage));
      expect(page.body, contains('Yunus Can Turhan'));
      expect(page.body, contains('Retention and deletion'));
      expect(page.links, isNotEmpty);
    },
  );

  testWidgets('clearing local watch data warns that Apple billing continues', (
    tester,
  ) async {
    final store = FakeSubscriptionRepository();
    final premium = SubscriptionController(store);
    addTearDown(() async {
      premium.dispose();
      await store.close();
    });
    await premium.initialize();
    await premiumHarness(
      tester,
      premium,
      home: const Scaffold(body: ClearLocalDataTile()),
    );
    await tester.tap(find.text('Clear Watch Data'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('does not cancel your Apple subscription'),
      findsOneWidget,
    );
    expect(find.text('Manage Subscription'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'an undecided privacy choice never constructs an advertising widget',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final privacy = AdPrivacyController(
        await SharedPreferences.getInstance(),
      );
      final store = FakeSubscriptionRepository();
      final premium = SubscriptionController(store);
      addTearDown(() async {
        premium.dispose();
        privacy.dispose();
        await store.close();
      });
      await premium.initialize();
      var adConstructions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WatchloomBannerSlot(
            controller: premium,
            privacyController: privacy,
            adBuilder: (_) {
              adConstructions++;
              return const Text('Limited ad');
            },
          ),
        ),
      );
      expect(adConstructions, 0);
      await privacy.setAllowed(true);
      await tester.pumpAndSettle();
      expect(find.text('Limited ad'), findsOneWidget);
      await privacy.setAllowed(false);
      await tester.pumpAndSettle();
      expect(find.text('Limited ad'), findsNothing);
    },
  );

  testWidgets(
    'banner is removed on upgrade and while another route covers it',
    (tester) async {
      final store = FakeSubscriptionRepository();
      SharedPreferences.setMockInitialValues({});
      final adPrivacy = AdPrivacyController(
        await SharedPreferences.getInstance(),
      );
      await adPrivacy.setAllowed(true);
      addTearDown(adPrivacy.dispose);
      final premium = SubscriptionController(store);
      addTearDown(store.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  WatchloomBannerSlot(
                    controller: premium,
                    privacyController: adPrivacy,
                    adBuilder: (_) => const Text('Test banner'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(body: Text('Details')),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Test banner'), findsNothing);
      await premium.initialize();
      await tester.pumpAndSettle();
      expect(find.text('Test banner'), findsOneWidget);
      await adPrivacy.setAllowed(false);
      await tester.pumpAndSettle();
      expect(find.text('Test banner'), findsNothing);
      await adPrivacy.setAllowed(true);
      await tester.pumpAndSettle();
      expect(find.text('Test banner'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Test banner', skipOffstage: false), findsNothing);
      final context = tester.element(find.text('Details'));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.text('Test banner'), findsOneWidget);
      store.entitlement = PremiumEntitlement(
        status: PremiumStatus.subscribed,
        accessUntil: DateTime.now().add(const Duration(days: 30)),
      );
      await premium.refreshEntitlement();
      await tester.pumpAndSettle();
      expect(find.text('Test banner'), findsNothing);
      premium.dispose();
    },
  );
}

class _FakeShowRepository implements ShowRepository {
  @override
  Future<TvShow> getShow(int showId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TvEpisode>> getEpisodes(int showId) async {
    return const [];
  }

  @override
  Future<List<TvShow>> getShowsPage(int page) async {
    return const [];
  }

  @override
  Future<List<TvShow>> searchShows(String query) async {
    return const [];
  }
}

class _FakeLibraryRepository implements LibraryRepository {
  final List<LibraryEntry> _entries = [];

  @override
  Future<void> deleteEntry(int showId) async {
    _entries.removeWhere((entry) => entry.showId == showId);
  }

  @override
  Future<List<LibraryEntry>> getEntries() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<LibraryEntry?> getEntry(int showId) async {
    for (final entry in _entries) {
      if (entry.showId == showId) {
        return entry;
      }
    }

    return null;
  }

  @override
  Future<void> saveEntry(LibraryEntry entry) async {
    _entries.removeWhere((currentEntry) => currentEntry.showId == entry.showId);

    _entries.add(entry);
  }
}

class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository(this._libraryRepository);

  final _FakeLibraryRepository _libraryRepository;

  final List<EpisodeWatchLog> _logs = [];
  final List<UnlockedAchievement> _achievements = [];

  @override
  Future<List<EpisodeWatchLog>> getWatchLogs() async {
    return List.unmodifiable(_logs);
  }

  @override
  Future<List<UnlockedAchievement>> getUnlockedAchievements() async {
    return List.unmodifiable(_achievements);
  }

  @override
  Future<bool> recordEpisode({
    required EpisodeWatchLog log,
    required LibraryEntry updatedLibraryEntry,
  }) async {
    final alreadyExists = _logs.any(
      (currentLog) =>
          currentLog.showId == log.showId &&
          currentLog.episodeId == log.episodeId,
    );

    if (alreadyExists) {
      return false;
    }

    _logs.add(log);

    await _libraryRepository.saveEntry(updatedLibraryEntry);

    return true;
  }

  @override
  Future<EpisodeWatchLog?> undoLatestEpisode({
    required LibraryEntry currentLibraryEntry,
  }) async {
    if (_logs.isEmpty) {
      return null;
    }

    final latestLog = _logs.first;
    _logs.removeAt(0);

    await _libraryRepository.saveEntry(
      LibraryEntry(
        showId: currentLibraryEntry.showId,
        name: currentLibraryEntry.name,
        summary: currentLibraryEntry.summary,
        genres: currentLibraryEntry.genres,
        status: latestLog.previousStatus ?? currentLibraryEntry.status,
        imageMedium: currentLibraryEntry.imageMedium,
        imageOriginal: currentLibraryEntry.imageOriginal,
        ratingAverage: currentLibraryEntry.ratingAverage,
        channelName: currentLibraryEntry.channelName,
        premiered: currentLibraryEntry.premiered,
        tvMazeUrl: currentLibraryEntry.tvMazeUrl,
        lastSeason: latestLog.previousSeason,
        lastEpisode: latestLog.previousEpisodeNumber,
        lastEpisodeId: latestLog.previousEpisodeId,
        addedAt: currentLibraryEntry.addedAt,
        updatedAt: DateTime.now(),
      ),
    );

    return latestLog;
  }

  @override
  Future<bool> unlockAchievement(UnlockedAchievement achievement) async {
    final alreadyExists = _achievements.any(
      (currentAchievement) => currentAchievement.code == achievement.code,
    );

    if (alreadyExists) {
      return false;
    }

    _achievements.add(achievement);
    return true;
  }
}
