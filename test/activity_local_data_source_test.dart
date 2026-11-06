import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/features/activity/data/datasources/activity_local_data_source.dart';

// A transactional database double exercises the data-source contract without
// requiring an iOS plugin. Native SQLite integration remains a device check.
class _MemoryDatabase implements Database, Transaction {
  final entries = <int, Map<String, Object?>>{};
  final logs = <Map<String, Object?>>[];
  var rejectNextUpdate = false;
  var _nextId = 1;
  var _insideTransaction = false;
  Future<void> _tail = Future<void>.value();

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    final result = _tail.then((_) async {
      final oldEntries = {
        for (final entry in entries.entries) entry.key: Map.of(entry.value),
      };
      final oldLogs = logs.map(Map<String, Object?>.of).toList();
      final oldNextId = _nextId;
      _insideTransaction = true;
      try {
        return await action(this);
      } catch (_) {
        entries
          ..clear()
          ..addAll(oldEntries);
        logs
          ..clear()
          ..addAll(oldLogs);
        _nextId = oldNextId;
        rethrow;
      } finally {
        _insideTransaction = false;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    expect(_insideTransaction, isTrue);
    var rows = table == 'library_entries'
        ? entries.values.map(Map<String, Object?>.of).toList()
        : logs.map(Map<String, Object?>.of).toList();
    if (where != null) {
      final keys = switch (where) {
        'show_id = ?' => ['show_id'],
        'show_id = ? AND episode_id = ?' => ['show_id', 'episode_id'],
        'show_id = ? AND source = ?' => ['show_id', 'source'],
        _ => throw StateError('unsupported query in database double: $where'),
      };
      rows = rows.where((row) {
        for (var index = 0; index < keys.length; index++) {
          if (row[keys[index]] != whereArgs![index]) return false;
        }
        return true;
      }).toList();
    }
    if (orderBy == 'watched_at DESC, id DESC') {
      rows.sort((a, b) {
        final time = (b['watched_at'] as String).compareTo(
          a['watched_at'] as String,
        );
        return time != 0 ? time : (b['id'] as int).compareTo(a['id'] as int);
      });
    }
    if (limit != null) rows = rows.take(limit).toList();
    return [
      for (final row in rows)
        columns == null ? row : {for (final key in columns) key: row[key]},
    ];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    expect(_insideTransaction, isTrue);
    expect(table, 'episode_watch_logs');
    if (logs.any(
      (row) =>
          row['show_id'] == values['show_id'] &&
          row['episode_id'] == values['episode_id'],
    )) {
      throw StateError('duplicate episode');
    }
    final id = _nextId++;
    logs.add({...values, 'id': id});
    return id;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    expect(_insideTransaction, isTrue);
    expect(table, 'library_entries');
    expect(where, 'show_id = ?');
    if (rejectNextUpdate) {
      rejectNextUpdate = false;
      return 0;
    }
    final entry = entries[whereArgs!.single];
    if (entry == null) return 0;
    entry.addAll(values);
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    expect(_insideTransaction, isTrue);
    expect(table, 'episode_watch_logs');
    expect(where, 'id = ?');
    final before = logs.length;
    logs.removeWhere((row) => row['id'] == whereArgs!.single);
    return before - logs.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends WatchloomDatabase {
  final memory = _MemoryDatabase();
  @override
  Future<Database> get database async => memory;
}

Map<String, Object?> _entry() => {
  'show_id': 1,
  'status': 'watchlist',
  'last_season': null,
  'last_episode': null,
  'last_episode_id': null,
  'personal_note': 'Keep my private note',
  'is_favorite': 1,
  'updated_at': '2026-11-01T10:00:00.000Z',
};

Map<String, Object?> _log({int episode = 1}) => {
  'show_id': 1,
  'show_name': 'Series 1',
  'episode_id': 10 + episode,
  'season': 1,
  'episode_number': episode,
  'runtime_minutes': 45,
  'watched_at': '2026-11-0${episode + 1}T10:00:00.000Z',
  'source': 'manual_watch',
  'previous_status': episode == 1 ? 'watchlist' : 'watching',
  'previous_season': episode == 1 ? null : 1,
  'previous_episode_number': episode == 1 ? null : episode - 1,
  'previous_episode_id': episode == 1 ? null : 10 + episode - 1,
};

Map<String, Object?> _progress({int episode = 1}) => {
  ..._entry(),
  'status': 'watching',
  'last_season': 1,
  'last_episode': episode,
  'last_episode_id': 10 + episode,
  // A stale UI snapshot must not overwrite these independently edited fields.
  'personal_note': 'Stale note',
  'is_favorite': 0,
  'updated_at': '2026-11-0${episode + 1}T10:00:00.000Z',
};

void main() {
  late _Store store;
  late ActivityLocalDataSource source;
  setUp(() {
    store = _Store();
    store.memory.entries[1] = _entry();
    source = ActivityLocalDataSource(store);
    addTearDown(store.changes.dispose);
  });

  test(
    'record atomically saves one event and progress without replacing notes',
    () async {
      final result = await source.recordEpisode(
        log: _log(),
        updatedLibraryEntry: _progress(),
      );
      expect(result, isTrue);
      expect(store.memory.logs.length, 1);
      expect(store.memory.entries[1]?['last_episode_id'], 11);
      expect(store.memory.entries[1]?['status'], 'watching');
      expect(store.memory.entries[1]?['personal_note'], 'Keep my private note');
      expect(store.memory.entries[1]?['is_favorite'], 1);
      expect(store.changes.value, 1);
    },
  );

  test(
    'simultaneous duplicate requests cannot count or advance twice',
    () async {
      final results = await Future.wait([
        source.recordEpisode(log: _log(), updatedLibraryEntry: _progress()),
        source.recordEpisode(log: _log(), updatedLibraryEntry: _progress()),
      ]);
      expect(results.where((value) => value).length, 1);
      expect(store.memory.logs.length, 1);
      expect(store.memory.entries[1]?['last_episode'], 1);
      expect(store.changes.value, 1);
    },
  );

  test(
    'stale progress and deleted library records cannot create an event',
    () async {
      store.memory.entries[1]!.addAll({
        'last_season': 3,
        'last_episode': 4,
        'last_episode_id': 304,
      });
      expect(
        await source.recordEpisode(
          log: _log(),
          updatedLibraryEntry: _progress(),
        ),
        isFalse,
      );
      expect(store.memory.entries[1]?['last_episode_id'], 304);
      store.memory.entries.clear();
      expect(
        await source.recordEpisode(
          log: _log(),
          updatedLibraryEntry: _progress(),
        ),
        isFalse,
      );
      expect(store.memory.logs, isEmpty);
      expect(store.changes.value, 0);
    },
  );

  test(
    'a stale status selection cannot overwrite a later manual status',
    () async {
      store.memory.entries[1]!['status'] = 'paused';
      expect(
        await source.recordEpisode(
          log: _log(),
          updatedLibraryEntry: _progress(),
        ),
        isFalse,
      );
      expect(store.memory.entries[1]?['status'], 'paused');
      expect(store.memory.logs, isEmpty);
    },
  );

  test(
    'mismatched show or episode pointers are rejected before writing',
    () async {
      for (final altered in [
        {..._progress(), 'show_id': 2},
        {..._progress(), 'last_episode_id': 12},
        {..._progress(), 'last_episode': 2},
        {..._progress(), 'last_season': 2},
      ]) {
        expect(
          await source.recordEpisode(log: _log(), updatedLibraryEntry: altered),
          isFalse,
        );
      }
      expect(store.memory.logs, isEmpty);
      expect(store.changes.value, 0);
    },
  );

  test('an unsuccessful progress update rolls the new log back', () async {
    store.memory.rejectNextUpdate = true;
    await expectLater(
      source.recordEpisode(log: _log(), updatedLibraryEntry: _progress()),
      throwsStateError,
    );
    expect(store.memory.logs, isEmpty);
    expect(store.memory.entries[1], _entry());
    expect(store.changes.value, 0);
  });

  test(
    'invalid runtime is stored as unknown instead of negative minutes',
    () async {
      expect(
        await source.recordEpisode(
          log: {..._log(), 'runtime_minutes': -45},
          updatedLibraryEntry: _progress(),
        ),
        isTrue,
      );
      expect(store.memory.logs.single['runtime_minutes'], isNull);
    },
  );

  test(
    'undo restores exact previous progress, including nullable first state',
    () async {
      await source.recordEpisode(log: _log(), updatedLibraryEntry: _progress());
      await source.recordEpisode(
        log: _log(episode: 2),
        updatedLibraryEntry: _progress(episode: 2),
      );
      final second = await source.undoLatestEpisode(
        currentLibraryEntry: _progress(),
      );
      expect(second?['episode_id'], 12);
      expect(store.memory.entries[1]?['last_episode_id'], 11);
      expect(store.memory.entries[1]?['status'], 'watching');
      final first = await source.undoLatestEpisode(
        currentLibraryEntry: _progress(),
      );
      expect(first?['episode_id'], 11);
      expect(store.memory.entries[1]?['last_episode_id'], isNull);
      expect(store.memory.entries[1]?['last_season'], isNull);
      expect(store.memory.entries[1]?['last_episode'], isNull);
      expect(store.memory.entries[1]?['status'], 'watchlist');
      expect(store.memory.entries[1]?['personal_note'], 'Keep my private note');
      expect(store.memory.entries[1]?['is_favorite'], 1);
      expect(store.memory.logs, isEmpty);
      expect(store.changes.value, 4);
    },
  );

  test(
    'undo preserves later manual progress while removing the watch event',
    () async {
      await source.recordEpisode(log: _log(), updatedLibraryEntry: _progress());
      store.memory.entries[1]!.addAll({
        'status': 'completed',
        'last_season': 3,
        'last_episode': 4,
        'last_episode_id': 304,
      });
      final result = await source.undoLatestEpisode(
        currentLibraryEntry: _progress(),
      );
      expect(result?['episode_id'], 11);
      expect(store.memory.logs, isEmpty);
      expect(store.memory.entries[1]?['last_episode_id'], 304);
      expect(store.memory.entries[1]?['status'], 'completed');
    },
  );

  test(
    'undo preserves later manual status while restoring untouched progress',
    () async {
      await source.recordEpisode(log: _log(), updatedLibraryEntry: _progress());
      store.memory.entries[1]!['status'] = 'paused';
      await source.undoLatestEpisode(currentLibraryEntry: _progress());
      expect(store.memory.entries[1]?['status'], 'paused');
      expect(store.memory.entries[1]?['last_episode_id'], isNull);
      expect(store.memory.logs, isEmpty);
    },
  );

  test('failed undo progress update rolls the removed log back', () async {
    await source.recordEpisode(log: _log(), updatedLibraryEntry: _progress());
    store.memory.rejectNextUpdate = true;
    await expectLater(
      source.undoLatestEpisode(currentLibraryEntry: _progress()),
      throwsStateError,
    );
    expect(store.memory.logs.single['episode_id'], 11);
    expect(store.memory.entries[1]?['last_episode_id'], 11);
    expect(store.changes.value, 1);
  });

  test(
    'legacy records without previous state use earlier recorded progress',
    () async {
      store.memory.entries[1]!.addAll(_progress(episode: 2));
      store.memory.logs.addAll([
        {..._log(), 'id': 1, 'previous_status': null},
        {..._log(episode: 2), 'id': 2, 'previous_status': null},
      ]);
      await source.undoLatestEpisode(
        currentLibraryEntry: _progress(episode: 2),
      );
      expect(store.memory.entries[1]?['last_episode_id'], 11);
      expect(store.memory.entries[1]?['status'], 'watching');
      expect(store.memory.logs.length, 1);
    },
  );
}
