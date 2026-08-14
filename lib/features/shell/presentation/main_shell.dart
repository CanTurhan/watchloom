import 'package:watchloom/core/localization/app_settings_strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/localization/app_story_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/notifications/upcoming_episode_notification_service.dart';
import 'package:watchloom/features/activity/presentation/pages/my_month_page.dart';
import 'package:watchloom/features/activity/presentation/services/month_story_service.dart';
import 'package:watchloom/features/home/presentation/home_page.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/library/presentation/pages/library_page.dart';
import 'package:watchloom/features/profile/presentation/profile_page.dart';
import 'package:watchloom/features/shows/presentation/show_detail_page.dart';
import 'package:watchloom/features/shows/presentation/show_search_page.dart';
import 'package:watchloom/features/settings/presentation/pages/settings_hub_page.dart';
import 'package:watchloom/core/monetization/watchloom_banner.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.localeController, super.key});

  final AppLocaleController localeController;

  @override
  State<MainShell> createState() {
    return _MainShellState();
  }
}

class _MainShellState extends State<MainShell> {
  final MonthStoryService _monthStoryService = MonthStoryService();

  StreamSubscription<int>? _notificationTapSubscription;

  LibraryController? _observedLibraryController;
  Timer? _notificationSyncTimer;

  int _selectedIndex = 0;
  bool _isSharingStory = false;
  bool _notificationBootstrapStarted = false;
  bool _openingNotificationShow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final scope = AppScope.of(context);

    _observeLibrary(scope.libraryController);

    if (_notificationBootstrapStarted) {
      _scheduleNotificationSync();
      return;
    }

    _notificationBootstrapStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_initializeNotificationIntegration());
    });
  }

  void _observeLibrary(LibraryController controller) {
    if (identical(controller, _observedLibraryController)) {
      return;
    }

    _observedLibraryController?.removeListener(_handleLibraryChanged);

    _observedLibraryController = controller;

    controller.addListener(_handleLibraryChanged);
  }

  void _handleLibraryChanged() {
    final controller = _observedLibraryController;

    if (!mounted || controller == null || controller.isLoading) {
      return;
    }

    _scheduleNotificationSync();
  }

  void _scheduleNotificationSync() {
    _notificationSyncTimer?.cancel();

    _notificationSyncTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }

      unawaited(_syncNotificationsSilently());
    });
  }

  Future<void> _initializeNotificationIntegration() async {
    final service = UpcomingEpisodeNotificationService.instance;

    await service.initialize();

    if (!mounted) {
      return;
    }

    _notificationTapSubscription ??= service.showOpenRequests.listen(
      _queueNotificationShowOpen,
    );

    final pendingShowId = service.takePendingShowId();

    if (pendingShowId != null) {
      _queueNotificationShowOpen(pendingShowId);
    }

    await _syncNotificationsSilently();
  }

  Future<void> _syncNotificationsSilently() async {
    if (!mounted) {
      return;
    }

    final scope = AppScope.of(context);

    try {
      await UpcomingEpisodeNotificationService.instance.syncIfEnabled(
        entries: scope.libraryController.entries.toList(),
        isTurkish: Localizations.localeOf(context).languageCode == 'tr',
      );
    } catch (_) {
      // Arka plan eşitleme hataları kullanıcı
      // deneyimini kesintiye uğratmaz.
    }
  }

  void _queueNotificationShowOpen(int showId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_openShowFromNotification(showId));
    });
  }

  Future<void> _openShowFromNotification(int showId) async {
    if (_openingNotificationShow || !mounted) {
      return;
    }

    _openingNotificationShow = true;

    try {
      final scope = AppScope.of(context);

      var entry = scope.libraryController.findByShowId(showId);

      if (entry == null) {
        await scope.libraryController.load();

        if (!mounted) {
          return;
        }

        entry = scope.libraryController.findByShowId(showId);
      }

      if (entry == null || !mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShowDetailPage(
            showRepository: scope.showRepository,
            initialShow: entry!.toTvShow(),
          ),
        ),
      );
    } finally {
      _openingNotificationShow = false;
    }
  }

  @override
  void dispose() {
    _notificationSyncTimer?.cancel();

    _observedLibraryController?.removeListener(_handleLibraryChanged);

    final subscription = _notificationTapSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    super.dispose();
  }

  Future<void> _shareMonthStory() async {
    if (_isSharingStory) {
      return;
    }

    setState(() {
      _isSharingStory = true;
    });

    final strings = AppStrings.of(context);
    final scope = AppScope.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    final sharePositionOrigin = Rect.fromLTWH(
      screenSize.width / 2,
      screenSize.height - 100,
      1,
      1,
    );

    try {
      await _monthStoryService.createAndShare(
        strings: strings,
        controller: scope.activityController,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.storyShareFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _isSharingStory = false;
        });
      }
    }
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsHubPage()));
  }

  Widget? _buildFloatingActionButton(AppStrings strings) {
    if (_selectedIndex == 3) {
      return FloatingActionButton.extended(
        heroTag: 'month-story-share',
        onPressed: _isSharingStory ? null : _shareMonthStory,
        icon: _isSharingStory
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.ios_share_rounded),
        label: Text(strings.shareMonthStory),
      );
    }

    if (_selectedIndex == 4) {
      return FloatingActionButton.extended(
        heroTag: 'notification-settings',
        onPressed: _openSettings,
        icon: const Icon(Icons.notifications_rounded),
        label: Text(strings.settingsTitle),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scope = AppScope.of(context);

    final pages = <Widget>[
      const HomePage(),
      const LibraryPage(),
      ShowSearchPage(showRepository: scope.showRepository),
      const MyMonthPage(),
      ProfilePage(localeController: widget.localeController),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: _buildFloatingActionButton(strings),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WatchloomBanner(),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: strings.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.video_library_outlined),
                selectedIcon: const Icon(Icons.video_library_rounded),
                label: strings.library,
              ),
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore_rounded),
                label: strings.discover,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month_rounded),
                label: strings.myMonth,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: strings.profile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
