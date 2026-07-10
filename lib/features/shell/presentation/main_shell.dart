import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/localization/app_story_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/activity/presentation/pages/my_month_page.dart';
import 'package:watchloom/features/activity/presentation/services/month_story_service.dart';
import 'package:watchloom/features/home/presentation/home_page.dart';
import 'package:watchloom/features/library/presentation/pages/library_page.dart';
import 'package:watchloom/features/profile/presentation/profile_page.dart';
import 'package:watchloom/features/shows/presentation/show_search_page.dart';

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

  int _selectedIndex = 0;
  bool _isSharingStory = false;

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
      floatingActionButton: _selectedIndex == 3
          ? FloatingActionButton.extended(
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
            )
          : null,
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
