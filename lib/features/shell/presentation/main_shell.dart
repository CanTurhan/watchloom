import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_locale_controller.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/activity/presentation/pages/my_month_page.dart';
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
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scope = AppScope.of(context);

    final pages = <Widget>[
      HomePage(showRepository: scope.showRepository),
      const LibraryPage(),
      ShowSearchPage(showRepository: scope.showRepository),
      const MyMonthPage(),
      ProfilePage(localeController: widget.localeController),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
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
