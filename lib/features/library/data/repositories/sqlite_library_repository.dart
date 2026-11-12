import 'package:watchloom/features/library/data/datasources/library_local_data_source.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/domain/repositories/library_repository.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';

class SqliteLibraryRepository
    implements LibraryRepository, ProgressLibraryRepository {
  const SqliteLibraryRepository(this._localDataSource);

  final LibraryLocalDataSource _localDataSource;

  @override
  Future<void> saveProgress(LibraryEntry entry, List<TvEpisode> episodes) =>
      _localDataSource.saveEntry(entry.toMap(), episodes: episodes);

  @override
  Future<List<LibraryEntry>> getEntries() async {
    final rows = await _localDataSource.getEntries();

    return rows.map(LibraryEntry.fromMap).toList(growable: false);
  }

  @override
  Future<LibraryEntry?> getEntry(int showId) async {
    final row = await _localDataSource.getEntry(showId);

    if (row == null) {
      return null;
    }

    return LibraryEntry.fromMap(row);
  }

  @override
  Future<void> saveEntry(LibraryEntry entry) {
    return _localDataSource.saveEntry(entry.toMap());
  }

  @override
  Future<void> deleteEntry(int showId) {
    return _localDataSource.deleteEntry(showId);
  }
}
