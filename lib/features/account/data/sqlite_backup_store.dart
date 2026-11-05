import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/features/account/data/library_backup.dart';

class SqliteBackupStore implements LocalBackupStore {
  const SqliteBackupStore(this.database);
  final WatchloomDatabase database;

  @override
  Future<LocalBackupSnapshot> read() async {
    final db = await database.database;
    return db.transaction((tx) async {
      final state = (await tx.query('backup_state')).single;
      return LocalBackupSnapshot(
        LibraryBackup(
          entries: await tx.query('library_entries'),
          logs: [
            for (final log in await tx.query('episode_watch_logs'))
              Map<String, Object?>.from(log)..remove('id'),
          ],
          achievements: await tx.query('unlocked_achievements'),
        ),
        LocalBackupState(
          version: state['local_version'] as int,
          savedVersion: state['saved_version'] as int,
          remoteRevision: state['remote_revision'] as int,
        ),
      );
    });
  }

  @override
  Future<void> acknowledge(int localVersion, int remoteRevision) async {
    final db = await database.database;
    // A concurrent edit remains dirty and is backed up in the next pass.
    await db.update('backup_state', {
      'saved_version': localVersion,
      'remote_revision': remoteRevision,
    }, where: 'id = 1');
  }

  @override
  Future<void> restore(
    LibraryBackup data, {
    required int expectedVersion,
    required int remoteRevision,
    bool asLocalEdit = false,
  }) async {
    final db = await database.database;
    await db.transaction((tx) async {
      final before = (await tx.query('backup_state')).single;
      if (before['local_version'] != expectedVersion) {
        throw const BackupConflict();
      }
      for (final table in [
        'episode_watch_logs',
        'unlocked_achievements',
        'library_entries',
      ]) {
        await tx.delete(table);
      }
      for (final row in data.entries) {
        await tx.insert('library_entries', row);
      }
      for (final row in data.logs) {
        await tx.insert('episode_watch_logs', row);
      }
      for (final row in data.achievements) {
        await tx.insert('unlocked_achievements', row);
      }
      await tx.rawUpdate(
        'UPDATE backup_state SET saved_version = local_version ${asLocalEdit ? '- 1' : ''}, '
        'remote_revision = ? WHERE id = 1',
        [remoteRevision],
      );
    });
    database.didChange();
  }

  /// Import only into an empty account library, after an explicit user choice.
  /// The original guest data stays intact. No destructive merge or quota bypass.
  Future<void> importGuest(LibraryBackup guest) async {
    if (guest.isEmpty) return;
    final current = await read();
    if (!current.data.isEmpty) throw const BackupConflict();
    await restore(
      guest,
      expectedVersion: current.state.version,
      remoteRevision: current.state.remoteRevision,
      asLocalEdit: true,
    );
  }
}
