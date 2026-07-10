import 'package:sqflite/sqflite.dart';
import 'package:watchloom/core/database/watchloom_database.dart';

class LibraryLocalDataSource {
  const LibraryLocalDataSource(this._watchloomDatabase);

  final WatchloomDatabase _watchloomDatabase;

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

  Future<void> saveEntry(Map<String, Object?> entry) async {
    final database = await _watchloomDatabase.database;

    await database.insert(
      'library_entries',
      entry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEntry(int showId) async {
    final database = await _watchloomDatabase.database;

    await database.delete(
      'library_entries',
      where: 'show_id = ?',
      whereArgs: [showId],
    );
  }
}
