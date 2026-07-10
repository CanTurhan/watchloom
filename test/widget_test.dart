import 'package:flutter_test/flutter_test.dart';
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

void main() {
  testWidgets('Watchloom opens on the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({'watchloom_language': 'en'});

    final localeController = await AppLocaleController.create();

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
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('WATCHLOOM'), findsOneWidget);

    expect(find.text('Your shows, remembered.'), findsOneWidget);
  });
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
