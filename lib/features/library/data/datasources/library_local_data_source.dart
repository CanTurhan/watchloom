import 'package:sqflite/sqflite.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';

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

  Future<void> saveEntry(Map<String, Object?> entry) async {
    final database = await _watchloomDatabase.database;

    await database.transaction((transaction) async {
      final existing = await transaction.query(
        'library_entries',
        columns: ['show_id'],
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
