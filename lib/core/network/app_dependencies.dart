import 'package:dio/dio.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchloom/core/monetization/ad_privacy_controller.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';
import 'package:watchloom/features/premium/data/subscription_repository.dart';
import 'package:watchloom/features/premium/presentation/subscription_controller.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/features/activity/data/datasources/activity_local_data_source.dart';
import 'package:watchloom/features/activity/data/repositories/sqlite_activity_repository.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/data/datasources/library_local_data_source.dart';
import 'package:watchloom/features/library/data/repositories/sqlite_library_repository.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/data/datasources/tvmaze_remote_data_source.dart';
import 'package:watchloom/features/shows/data/repositories/tvmaze_show_repository.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/account/presentation/account_session_controller.dart';

class AppDependencies {
  const AppDependencies._({
    required this.showRepository,
    required this.libraryController,
    required this.activityController,
    required this.premiumController,
    required this.adPrivacyController,
    required this.accountSession,
  });

  final ShowRepository showRepository;
  final LibraryController libraryController;
  final WatchActivityController activityController;
  final SubscriptionController premiumController;
  final AdPrivacyController adPrivacyController;
  final AccountSessionController accountSession;

  static Future<AppDependencies> create() async {
    final adPrivacy = AdPrivacyController(
      await SharedPreferences.getInstance(),
    );
    final premium = SubscriptionController(StoreKitSubscriptionRepository());
    unawaited(premium.initialize());
    final accessPolicy = LibraryAccessPolicy(
      hasPremium: () => premium.hasAccess,
    );
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.tvmaze.com',
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Watchloom/1.1.0 Flutter iOS',
        },
      ),
    );

    final showRepository = TvMazeShowRepository(TvMazeRemoteDataSource(dio));

    final watchloomDatabase = WatchloomDatabase();
    await watchloomDatabase.database;

    final libraryController = LibraryController(
      SqliteLibraryRepository(
        LibraryLocalDataSource(watchloomDatabase, accessPolicy: accessPolicy),
      ),
      accessPolicy: accessPolicy,
    );

    await libraryController.load();

    final activityController = WatchActivityController(
      repository: SqliteActivityRepository(
        ActivityLocalDataSource(watchloomDatabase),
      ),
      libraryController: libraryController,
      showRepository: showRepository,
    );

    await activityController.load();

    final auth = await AuthController.create();
    final accountSession = AccountSessionController(
      auth: auth,
      showRepository: showRepository,
      accessPolicy: accessPolicy,
      guestDatabase: watchloomDatabase,
      library: libraryController,
      activity: activityController,
    );
    await accountSession.initialize();

    return AppDependencies._(
      showRepository: showRepository,
      libraryController: libraryController,
      activityController: activityController,
      premiumController: premium,
      adPrivacyController: adPrivacy,
      accountSession: accountSession,
    );
  }
}
