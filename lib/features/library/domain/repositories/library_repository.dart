import 'package:watchloom/features/library/domain/entities/library_entry.dart';

abstract interface class LibraryRepository {
  Future<List<LibraryEntry>> getEntries();

  Future<LibraryEntry?> getEntry(int showId);

  Future<void> saveEntry(LibraryEntry entry);

  Future<void> deleteEntry(int showId);
}
