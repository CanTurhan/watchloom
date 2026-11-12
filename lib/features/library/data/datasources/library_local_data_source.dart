import 'package:sqflite/sqflite.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';

class LibraryLocalDataSource {
  const LibraryLocalDataSource(
    this._watchloomDatabase, {
    this.accessPolicy = const LibraryAccessPolicy.free(),
  });

  final WatchloomDatabase _watchloomDatabase;
  final LibraryAccessPolicy accessPolicy;

  Future<List<Map<String, Object?>>> getEntries() async {
    final database = await _watchloomDatabase.database;

    return database.query('library_entries', orderBy: 'updated_at DESC');
  }

  Future<Map<String, Object?>?> getEntry(int showId) async {
    final database = await _watchloomDatabase.database;

    final results = await database.query(
      'library_entries',
      where: 'show_id = ?',
      whereArgs: [showId],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return results.first;
  }

  Future<void> saveEntry(
    Map<String, Object?> entry, {
    List<TvEpisode>? episodes,
  }) async {
    final database = await _watchloomDatabase.database;

    await database.transaction((transaction) async {
      final existing = await transaction.query(
        'library_entries',
        where: 'show_id = ?',
        whereArgs: [entry['show_id']],
        limit: 1,
      );
      final count =
          Sqflite.firstIntValue(
            await transaction.rawQuery('SELECT COUNT(*) FROM library_entries'),
          ) ??
          0;
      accessPolicy.checkSave(
        alreadySaved: existing.isNotEmpty,
        entryCount: count,
      );
      if (episodes != null) {
        final ordered =
            episodes.where((e) => e.season != null && e.number != null).toList()
              ..sort((a, b) {
                final season = a.season!.compareTo(b.season!);
                return season != 0 ? season : a.number!.compareTo(b.number!);
              });
        int position(Map<String, Object?> row) => ordered.indexWhere(
          (e) =>
              e.id == row['last_episode_id'] ||
              (e.season == row['last_season'] &&
                  e.number == row['last_episode']),
        );
        final previous = existing.isEmpty ? null : existing.single;
        var start = previous == null ? -1 : position(previous);
        if (start < 0 &&
            previous?['last_season'] is int &&
            previous?['last_episode'] is int) {
          start = ordered.lastIndexWhere(
            (episode) =>
                episode.season! < (previous!['last_season'] as int) ||
                (episode.season == previous['last_season'] &&
                    episode.number! <= (previous['last_episode'] as int)),
          );
        }
        final end = position(entry);
        if (entry['last_episode_id'] != null && end < 0) {
          throw StateError('selected-episode-unavailable');
        }
        // Rewinding is an explicit correction: remove only events after the
        // selected progress. Existing earlier watch dates remain untouched.
        for (
          var index = end + 1;
          end < start && index < ordered.length;
          index++
        ) {
          await transaction.delete(
            'episode_watch_logs',
            where: 'show_id = ? AND episode_id = ?',
            whereArgs: [entry['show_id'], ordered[index].id],
          );
        }
        var previousState = previous;
        for (var index = start + 1; index <= end; index++) {
          final episode = ordered[index];
          final release = DateTime.tryParse(episode.airDate ?? '');
          final now = DateTime.parse(entry['updated_at'] as String).toLocal();
          if (release != null &&
              DateTime(
                release.year,
                release.month,
                release.day,
              ).isAfter(DateTime(now.year, now.month, now.day))) {
            throw StateError('episode-not-released');
          }
          await transaction.insert('episode_watch_logs', {
            'show_id': entry['show_id'],
            'show_name': entry['name'],
            'episode_id': episode.id,
            'season': episode.season,
            'episode_number': episode.number,
            'runtime_minutes': episode.runtime != null && episode.runtime! > 0
                ? episode.runtime
                : (entry['runtime_minutes'] is int &&
                          (entry['runtime_minutes'] as int) > 0
                      ? entry['runtime_minutes']
                      : null),
            'watched_at': entry['updated_at'],
            'source': 'manual_watch',
            'previous_status': previousState?['status'] ?? 'watchlist',
            'previous_season': previousState?['last_season'],
            'previous_episode_number': previousState?['last_episode'],
            'previous_episode_id': previousState?['last_episode_id'],
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          previousState = {
            ...entry,
            'last_season': episode.season,
            'last_episode': episode.number,
            'last_episode_id': episode.id,
          };
        }
      }
      await transaction.insert(
        'library_entries',
        entry,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _watchloomDatabase.didChange();
  }

  Future<void> deleteEntry(int showId) async {
    final database = await _watchloomDatabase.database;

    await database.delete(
      'library_entries',
      where: 'show_id = ?',
      whereArgs: [showId],
    );
    _watchloomDatabase.didChange();
  }
}
