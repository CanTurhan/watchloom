import 'package:flutter/material.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/features/account/presentation/account_session_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    required this.showRepository,
    required this.libraryController,
    required this.activityController,
    required this.premiumController,
    required this.adPrivacyController,
    required super.child,
    this.accountSession,
    super.key,
  });

  final ShowRepository showRepository;
  final LibraryController libraryController;
  final WatchActivityController activityController;
  final SubscriptionController premiumController;
  final AdPrivacyController adPrivacyController;
  final AccountSessionController? accountSession;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();

    assert(scope != null, 'AppScope was not found in the widget tree.');

    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return showRepository != oldWidget.showRepository ||
        libraryController != oldWidget.libraryController ||
        activityController != oldWidget.activityController ||
        premiumController != oldWidget.premiumController ||
        adPrivacyController != oldWidget.adPrivacyController ||
        accountSession != oldWidget.accountSession;
  }
}
