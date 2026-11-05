import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class WatchloomDatabase {
  WatchloomDatabase({this.userId});

  /// The original database always remains the guest library. A session never
  /// changes its owner, including writes that finish after signing out.
  final String? userId;
  final changes = ValueNotifier<int>(0);
  static String fileNameFor(String? uid) => uid == null
      ? 'watchloom.db'
      : 'watchloom_account_${sha256.convert(utf8.encode(uid))}.db';
  void didChange() => changes.value++;
  Database? _database;
  bool _erased = false;

  Future<Database> get database async {
    if (_erased) throw StateError('deleted-account-database');
    final existingDatabase = _database;

    if (existingDatabase != null) {
      return existingDatabase;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, fileNameFor(userId));

    final openedDatabase = await openDatabase(
      databasePath,
      version: 5,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await _createLibraryTables(database);
        await _createActivityTables(database);
        await _createBackupMetadata(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createActivityTables(database);
        }

        if (oldVersion < 3) {
          await _ensureWatchHistoryColumns(database);
        }

        if (oldVersion < 4) {
          await _ensureLibraryPersonalColumns(database);
        }
        if (oldVersion < 5) await _createBackupMetadata(database);
      },
    );

    _database = openedDatabase;
    return openedDatabase;
  }

  Future<void> erase() async {
    _erased = true;
    await _database?.close();
    _database = null;
    await deleteDatabase(
      path.join(await getDatabasesPath(), fileNameFor(userId)),
    );
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
        is_favorite INTEGER NOT NULL DEFAULT 0,
        personal_note TEXT NOT NULL DEFAULT '',
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
        previous_status TEXT,
        previous_season INTEGER,
        previous_episode_number INTEGER,
        previous_episode_id INTEGER,
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

  Future<void> _ensureWatchHistoryColumns(Database database) async {
    final columns = await database.rawQuery(
      'PRAGMA table_info(episode_watch_logs)',
    );

    final columnNames = columns
        .map((column) => column['name']?.toString())
        .whereType<String>()
        .toSet();

    if (!columnNames.contains('previous_status')) {
      await database.execute(
        'ALTER TABLE episode_watch_logs '
        'ADD COLUMN previous_status TEXT',
      );
    }

    if (!columnNames.contains('previous_season')) {
      await database.execute(
        'ALTER TABLE episode_watch_logs '
        'ADD COLUMN previous_season INTEGER',
      );
    }

    if (!columnNames.contains('previous_episode_number')) {
      await database.execute(
        'ALTER TABLE episode_watch_logs '
        'ADD COLUMN previous_episode_number INTEGER',
      );
    }

    if (!columnNames.contains('previous_episode_id')) {
      await database.execute(
        'ALTER TABLE episode_watch_logs '
        'ADD COLUMN previous_episode_id INTEGER',
      );
    }
  }

  Future<void> _ensureLibraryPersonalColumns(Database database) async {
    final columns = await database.rawQuery(
      'PRAGMA table_info(library_entries)',
    );

    final columnNames = columns
        .map((column) => column['name']?.toString())
        .whereType<String>()
        .toSet();

    if (!columnNames.contains('is_favorite')) {
      await database.execute(
        'ALTER TABLE library_entries '
        'ADD COLUMN is_favorite '
        'INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (!columnNames.contains('personal_note')) {
      await database.execute(
        'ALTER TABLE library_entries '
        "ADD COLUMN personal_note "
        "TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> _createBackupMetadata(Database database) async {
    await database.execute('''
      CREATE TABLE backup_state (
        id INTEGER PRIMARY KEY CHECK(id = 1),
        local_version INTEGER NOT NULL DEFAULT 0,
        saved_version INTEGER NOT NULL DEFAULT 0,
        remote_revision INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('INSERT INTO backup_state(id) VALUES(1)');
    for (final table in [
      'library_entries',
      'episode_watch_logs',
      'unlocked_achievements',
    ]) {
      for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
        await database.execute('''
          CREATE TRIGGER backup_${table}_${operation.toLowerCase()}
          AFTER $operation ON $table BEGIN
            UPDATE backup_state SET local_version = local_version + 1 WHERE id = 1;
          END
        ''');
      }
    }
  }
}
