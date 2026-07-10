import 'package:flutter/material.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    required this.showRepository,
    required this.libraryController,
    required this.activityController,
    required super.child,
    super.key,
  });

  final ShowRepository showRepository;
  final LibraryController libraryController;
  final WatchActivityController activityController;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();

    assert(scope != null, 'AppScope was not found in the widget tree.');

    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return showRepository != oldWidget.showRepository ||
        libraryController != oldWidget.libraryController ||
        activityController != oldWidget.activityController;
  }
}
