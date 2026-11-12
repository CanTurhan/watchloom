import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';

abstract interface class ProgressLibraryRepository {
  Future<void> saveProgress(LibraryEntry entry, List<TvEpisode> episodes);
}

abstract interface class LibraryRepository {
  Future<List<LibraryEntry>> getEntries();

  Future<LibraryEntry?> getEntry(int showId);

  Future<void> saveEntry(LibraryEntry entry);

  Future<void> deleteEntry(int showId);
}
