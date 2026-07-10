import 'package:dio/dio.dart';
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

class AppDependencies {
  const AppDependencies._({
    required this.showRepository,
    required this.libraryController,
    required this.activityController,
  });

  final ShowRepository showRepository;
  final LibraryController libraryController;
  final WatchActivityController activityController;

  static Future<AppDependencies> create() async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.tvmaze.com',
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Watchloom/0.1.0 Flutter iOS',
        },
      ),
    );

    final showRepository = TvMazeShowRepository(TvMazeRemoteDataSource(dio));

    final watchloomDatabase = WatchloomDatabase();
    await watchloomDatabase.database;

    final libraryController = LibraryController(
      SqliteLibraryRepository(LibraryLocalDataSource(watchloomDatabase)),
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

    return AppDependencies._(
      showRepository: showRepository,
      libraryController: libraryController,
      activityController: activityController,
    );
  }
}
