import 'package:flutter_test/flutter_test.dart';
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

LibraryEntry _entry(int id) => LibraryEntry(
  showId: id,
  name: 'Series $id',
  summary: '',
  genres: const [],
  status: LibraryStatus.watchlist,
  addedAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

EpisodeWatchLog _log(int id, String at, {int? runtime = 45}) => EpisodeWatchLog(
  id: id,
  showId: 1,
  showName: 'Series 1',
  episodeId: id,
  season: 1,
  episodeNumber: id,
  runtimeMinutes: runtime,
  watchedAt: DateTime.parse(at),
  source: WatchLogSource.manualWatch,
);

class _Library implements LibraryRepository {
  final entries = <int, LibraryEntry>{};
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
  _Activity(this.library);
  final _Library library;
  final logs = <EpisodeWatchLog>[];
  final achievements = <UnlockedAchievement>[];
  EpisodeWatchLog? lastRecorded;
  LibraryEntry? undoEntry;
  bool rejectRecord = false;
  @override
  Future<List<EpisodeWatchLog>> getWatchLogs() async => List.unmodifiable(logs);
  @override
  Future<List<UnlockedAchievement>> getUnlockedAchievements() async =>
      List.of(achievements);
  @override
  Future<bool> recordEpisode({
    required EpisodeWatchLog log,
    required LibraryEntry updatedLibraryEntry,
  }) async {
    if (rejectRecord) return false;
    if (logs.any(
      (saved) => saved.showId == log.showId && saved.episodeId == log.episodeId,
    )) {
      return false;
    }
    lastRecorded = log;
    logs.add(log);
    library.entries[log.showId] = updatedLibraryEntry;
    return true;
  }

  @override
  Future<EpisodeWatchLog?> undoLatestEpisode({
    required LibraryEntry currentLibraryEntry,
  }) async {
    undoEntry = currentLibraryEntry;
    final candidates =
        logs.where((log) => log.showId == currentLibraryEntry.showId).toList()
          ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    if (candidates.isEmpty) return null;
    logs.remove(candidates.first);
    return candidates.first;
  }

  @override
  Future<bool> unlockAchievement(UnlockedAchievement achievement) async {
    if (achievements.any((item) => item.code == achievement.code)) return false;
    achievements.add(achievement);
    return true;
  }
}

class _Shows implements ShowRepository {
  List<TvEpisode> episodes = const [];
  @override
  Future<List<TvEpisode>> getEpisodes(int showId) async => episodes;
  @override
  Future<TvShow> getShow(int showId) => throw UnimplementedError();
  @override
  Future<List<TvShow>> getShowsPage(int page) => throw UnimplementedError();
  @override
  Future<List<TvShow>> searchShows(String query) => throw UnimplementedError();
}

void main() {
  late _Library libraryRepository;
  late LibraryController library;
  late _Activity repository;
  late _Shows shows;
  late DateTime now;
  WatchActivityController controller({int timezoneHours = 0}) {
    final value = WatchActivityController(
      repository: repository,
      libraryController: library,
      showRepository: shows,
      now: () => now,
      toLocalDate: (date) => date.toUtc().add(Duration(hours: timezoneHours)),
    );
    addTearDown(value.dispose);
    return value;
  }

  setUp(() {
    now = DateTime.utc(2026, 11, 5, 20);
    libraryRepository = _Library()..entries[1] = _entry(1);
    library = LibraryController(libraryRepository);
    repository = _Activity(libraryRepository);
    shows = _Shows();
    addTearDown(library.dispose);
  });

  test(
    'legacy getters and summary share canonical history without changing it',
    () async {
      final first = _log(1, '2026-11-01T10:00:00Z');
      repository.logs.addAll([
        first,
        first,
        _log(2, '2026-11-02T10:00:00Z', runtime: -30),
        _log(3, '2026-11-06T10:00:00Z'),
        _log(4, '2026-10-31T10:00:00Z'),
      ]);
      final activity = controller();
      await activity.load();
      expect(activity.error, isNull);
      expect(activity.logs.length, 5);
      expect(repository.logs.length, 5);
      expect(activity.totalEpisodes, 3);
      expect(activity.monthEpisodeCount, 2);
      expect(activity.monthShowCount, 1);
      expect(activity.monthWatchMinutes, 45);
      expect(activity.currentMonthSummary.unknownRuntimeCount, 1);
      expect(activity.currentMonthSummary.activeDayCount, 2);
      expect(activity.logsForMonth(DateTime(2026, 10)).single.episodeId, 4);
    },
  );

  test('current month and achievements use the same local calendar', () async {
    now = DateTime.utc(2026, 12, 31, 23, 30);
    repository.logs.add(_log(1, '2026-12-31T23:00:00Z'));
    repository.achievements.addAll([
      UnlockedAchievement(
        code: AchievementCatalog.tenEpisodes,
        unlockedAt: DateTime.utc(2026, 12, 31, 23),
      ),
      UnlockedAchievement(
        code: AchievementCatalog.fiftyEpisodes,
        unlockedAt: DateTime.utc(2027, 1, 2),
      ),
    ]);
    final activity = controller(timezoneHours: 3);
    await activity.load();
    expect(activity.currentMonthSummary.year, 2027);
    expect(activity.currentMonthSummary.month, 1);
    expect(activity.monthEpisodeCount, 1);
    expect(activity.achievementsUnlockedThisMonth.map((a) => a.code), [
      AchievementCatalog.tenEpisodes,
      AchievementCatalog.firstEpisode,
    ]);
    expect(activity.unlockedAchievements.length, 3);
  });

  test('future events cannot grant episode or streak achievements', () async {
    repository.logs.addAll(
      List.generate(
        12,
        (index) => _log(
          index + 1,
          DateTime.utc(2026, 11, 6 + index).toIso8601String(),
        ),
      ),
    );
    final activity = controller();
    await activity.load();
    expect(activity.totalEpisodes, 0);
    expect(activity.currentDailyStreak, 0);
    expect(activity.bestDailyStreak, 0);
    expect(activity.currentMonthlyStreak, 0);
    expect(repository.achievements, isEmpty);
  });

  test(
    'undo uses newest event even when repository history is unordered',
    () async {
      repository.logs.addAll([
        _log(1, '2026-11-01T10:00:00Z'),
        _log(2, '2026-11-02T10:00:00Z'),
      ]);
      final activity = controller();
      await library.load();
      await activity.load();
      expect(activity.logs.first.episodeId, 2);
      expect(activity.canUndoLatest, isTrue);
      final result = await activity.undoLastEpisode();
      expect(result.status, UndoLatestEpisodeStatus.success);
      expect(result.log?.episodeId, 2);
      expect(activity.monthEpisodeCount, 1);
      expect(repository.logs.single.episodeId, 1);
      expect(repository.undoEntry?.showId, 1);
    },
  );

  for (final runtime in <int?>[null, 0, -45, 38]) {
    test(
      'record uses the real clock and normalizes runtime $runtime',
      () async {
        shows.episodes = [
          TvEpisode(
            id: 1,
            name: 'Episode 1',
            summary: '',
            season: 1,
            number: 1,
            airDate: '2026-11-01',
            runtime: runtime,
          ),
        ];
        final activity = controller();
        final result = await activity.markNextEpisode(_entry(1));
        expect(result.status, MarkNextEpisodeStatus.success);
        expect(repository.lastRecorded?.watchedAt, now);
        expect(
          repository.lastRecorded?.runtimeMinutes,
          runtime != null && runtime > 0 ? runtime : null,
        );
        expect(activity.monthWatchMinutes, runtime == 38 ? 38 : 0);
        expect(
          activity.currentMonthSummary.unknownRuntimeCount,
          runtime == 38 ? 0 : 1,
        );
        expect(library.findByShowId(1)?.lastEpisodeId, 1);
        expect(library.findByShowId(1)?.status, LibraryStatus.watching);
      },
    );
  }

  test('unreleased episodes do not create history or progress', () async {
    shows.episodes = const [
      TvEpisode(
        id: 1,
        name: 'Future episode',
        summary: '',
        season: 1,
        number: 1,
        airDate: '2026-11-06',
        runtime: 45,
      ),
    ];
    final activity = controller();
    final result = await activity.markNextEpisode(_entry(1));
    expect(result.status, MarkNextEpisodeStatus.noAvailableEpisode);
    expect(repository.logs, isEmpty);
    expect(libraryRepository.entries[1]?.hasProgress, isFalse);
  });

  test(
    'rejected stale writes refresh the library without claiming a duplicate',
    () async {
      repository.rejectRecord = true;
      libraryRepository.entries[1] = _entry(1).copyWith(
        status: LibraryStatus.paused,
        lastSeason: 3,
        lastEpisode: 4,
        lastEpisodeId: 304,
      );
      shows.episodes = const [
        TvEpisode(id: 1, name: 'Episode', summary: '', season: 1, number: 1),
      ];
      final activity = controller();
      final result = await activity.markNextEpisode(_entry(1));
      expect(result.status, MarkNextEpisodeStatus.failed);
      expect(activity.logs, isEmpty);
      expect(library.findByShowId(1)?.lastEpisodeId, 304);
      expect(library.findByShowId(1)?.status, LibraryStatus.paused);
    },
  );

  test(
    'a genuine duplicate stays distinguishable from a stale request',
    () async {
      repository.logs.add(_log(1, '2026-11-01T10:00:00Z'));
      shows.episodes = const [
        TvEpisode(id: 1, name: 'Episode', summary: '', season: 1, number: 1),
      ];
      final activity = controller();
      final result = await activity.markNextEpisode(_entry(1));
      expect(result.status, MarkNextEpisodeStatus.alreadyRecorded);
      expect(activity.monthEpisodeCount, 1);
      expect(repository.logs.length, 1);
    },
  );
}
