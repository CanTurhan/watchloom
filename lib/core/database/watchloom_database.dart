import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class WatchloomDatabase {
  Database? _database;

  Future<Database> get database async {
    final existingDatabase = _database;

    if (existingDatabase != null) {
      return existingDatabase;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, 'watchloom.db');

    final openedDatabase = await openDatabase(
      databasePath,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await _createLibraryTables(database);
        await _createActivityTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createActivityTables(database);
        }
      },
    );

    _database = openedDatabase;
    return openedDatabase;
  }

  Future<void> _createLibraryTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS library_entries (
        show_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT '',
        genres_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL,
        image_medium TEXT,
        image_original TEXT,
        rating_average REAL,
        channel_name TEXT,
        premiered TEXT,
        tvmaze_url TEXT,
        last_season INTEGER,
        last_episode INTEGER,
        last_episode_id INTEGER,
        added_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS library_status_index
      ON library_entries(status)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS library_updated_at_index
      ON library_entries(updated_at)
    ''');
  }

  Future<void> _createActivityTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS episode_watch_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        show_id INTEGER NOT NULL,
        show_name TEXT NOT NULL,
        episode_id INTEGER NOT NULL,
        season INTEGER NOT NULL,
        episode_number INTEGER NOT NULL,
        runtime_minutes INTEGER,
        watched_at TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual_watch',
        UNIQUE(show_id, episode_id)
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS watch_logs_date_index
      ON episode_watch_logs(watched_at)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS watch_logs_show_index
      ON episode_watch_logs(show_id)
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS unlocked_achievements (
        code TEXT PRIMARY KEY,
        unlocked_at TEXT NOT NULL
      )
    ''');
  }
}
