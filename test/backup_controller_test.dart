import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/features/account/data/cloud_backup_repository.dart';
import 'package:watchloom/features/account/data/library_backup.dart';
import 'package:watchloom/features/account/data/firestore_account_store.dart';
import 'package:watchloom/features/account/presentation/backup_controller.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

LibraryBackup sample(int id, {String note = 'Özel not 🎬'}) => LibraryBackup(
  entries: [
    LibraryEntry(
      showId: id,
      name: 'Show $id',
      summary: '',
      genres: ['Drama'],
      status: LibraryStatus.watching,
      addedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      personalNote: note,
      isFavorite: true,
      lastSeason: 2,
      lastEpisode: 3,
    ).toMap(),
  ],
  logs: [],
  achievements: [],
);
const empty = LibraryBackup(entries: [], logs: [], achievements: []);

class MemoryLocal implements LocalBackupStore {
  MemoryLocal(this.data, {this.version = 0, this.saved = 0, this.revision = 0});
  LibraryBackup data;
  int version, saved, revision;
  int restores = 0;
  @override
  Future<LocalBackupSnapshot> read() async => LocalBackupSnapshot(
    data,
    LocalBackupState(
      version: version,
      savedVersion: saved,
      remoteRevision: revision,
    ),
  );
  @override
  Future<void> acknowledge(int localVersion, int remoteRevision) async {
    saved = localVersion;
    revision = remoteRevision;
  }

  @override
  Future<void> restore(
    LibraryBackup data, {
    required int expectedVersion,
    required int remoteRevision,
  }) async {
    if (version != expectedVersion) throw const BackupConflict();
    this.data = data;
    revision = remoteRevision;
    saved = version;
    restores++;
  }
}

class MemoryCloud implements CloudBackupRepository {
  MemoryCloud(this.data, {this.revision = 0});
  LibraryBackup? data;
  int revision;
  int uploads = 0;
  bool offline = false;
  bool deleting = false;
  Future<void> Function()? beforeDownload;
  Future<void> Function()? beforeUpload;
  @override
  Future<void> bootstrap() async {
    if (deleting) throw const AccountDeletionPending();
    if (offline) throw StateError('offline');
  }

  @override
  Future<CloudBackupHead> head() async {
    if (deleting) throw const AccountDeletionPending();
    return CloudBackupHead(revision, data == null ? null : 'backup');
  }

  @override
  Future<LibraryBackup> download(CloudBackupHead head) async {
    await beforeDownload?.call();
    return data!;
  }

  @override
  Future<int> upload(
    LibraryBackup backup, {
    required int expectedRevision,
  }) async {
    await beforeUpload?.call();
    if (revision != expectedRevision) throw const BackupConflict();
    data = backup;
    uploads++;
    return ++revision;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackupController controller(
    MemoryLocal local,
    MemoryCloud remote, {
    bool verified = true,
    ChangeNotifier? changes,
  }) {
    final c = BackupController(
      local: local,
      cloud: remote,
      onRestore: () async {},
      canBackup: () => verified,
      changes: changes ?? ChangeNotifier(),
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'guest file is preserved and account paths are distinct safe hashes',
    () {
      expect(WatchloomDatabase.fileNameFor(null), 'watchloom.db');
      expect(
        WatchloomDatabase.fileNameFor('user/a'),
        isNot(WatchloomDatabase.fileNameFor('user/b')),
      );
      expect(
        WatchloomDatabase.fileNameFor('user/a'),
        matches(r'^watchloom_account_[0-9a-f]{64}\.db$'),
      );
    },
  );
  test('snapshot preserves Unicode notes, favorites and progress', () {
    final restored = LibraryBackup.decode(sample(1).encode());
    expect(restored.entries.single['personal_note'], 'Özel not 🎬');
    expect(restored.entries.single['is_favorite'], 1);
    expect(restored.entries.single['last_episode'], 3);
  });
  test('unsupported and incomplete snapshots cannot replace local data', () {
    expect(
      () => LibraryBackup.decode(gzip.encode(utf8.encode('{"schema":9}'))),
      throwsFormatException,
    );
    expect(() => LibraryBackup.decode([1, 2, 3]), throwsA(anything));
    final duplicated = LibraryBackup(
      entries: [...sample(1).entries, ...sample(1).entries],
      logs: [],
      achievements: [],
    );
    expect(
      () => LibraryBackup.decode(duplicated.encode()),
      throwsFormatException,
    );
  });
  test(
    'reinstall restores server backup instead of uploading an empty library',
    () async {
      final local = MemoryLocal(empty);
      final cloud = MemoryCloud(sample(7), revision: 4);
      final c = controller(local, cloud);
      await c.synchronize();
      expect(local.data.entries.single['show_id'], 7);
      expect(local.revision, 4);
      expect(cloud.uploads, 0);
      expect(c.status, BackupStatus.saved);
    },
  );
  test(
    'conflicting offline edits never overwrite either copy silently',
    () async {
      final local = MemoryLocal(sample(1), version: 3, saved: 2, revision: 1);
      final cloud = MemoryCloud(sample(2), revision: 2);
      final c = controller(local, cloud);
      await c.synchronize();
      expect(c.status, BackupStatus.conflict);
      expect(cloud.uploads, 0);
      expect(local.restores, 0);
      expect(local.data.entries.single['show_id'], 1);
    },
  );
  test(
    'an interrupted deletion blocks backup and preserves both copies',
    () async {
      final local = MemoryLocal(sample(1), version: 1);
      final cloud = MemoryCloud(sample(2), revision: 1)..deleting = true;
      final c = controller(local, cloud);
      await c.synchronize();
      expect(c.status, BackupStatus.deletionPending);
      expect(cloud.uploads, 0);
      expect(local.restores, 0);
      expect(local.data.entries.single['show_id'], 1);
    },
  );

  test('offline bootstrap leaves local data and dirty state intact', () async {
    final local = MemoryLocal(sample(1), version: 1);
    final cloud = MemoryCloud(null)..offline = true;
    final c = controller(local, cloud);
    await c.synchronize();
    expect(c.status, BackupStatus.offline);
    expect((await local.read()).state.dirty, true);
    expect(cloud.uploads, 0);
  });
  test('unverified email never uploads private library data', () async {
    final cloud = MemoryCloud(null);
    final c = controller(
      MemoryLocal(sample(1), version: 1),
      cloud,
      verified: false,
    );
    await c.synchronize();
    expect(c.status, BackupStatus.verificationRequired);
    expect(cloud.uploads, 0);
  });
  test(
    'edit during upload remains dirty and is not reported as fully saved',
    () async {
      final local = MemoryLocal(sample(1), version: 1);
      final cloud = MemoryCloud(null)
        ..beforeUpload = () async {
          local.version++;
          local.data = sample(2);
        };
      final c = controller(local, cloud);
      await c.synchronize();
      expect(local.saved, 1);
      expect(local.version, 2);
      expect(c.status, BackupStatus.pending);
      expect(cloud.data!.entries.single['show_id'], 1);
    },
  );
  test(
    'edit while downloading aborts restore rather than losing the edit',
    () async {
      final local = MemoryLocal(sample(1), version: 1, saved: 1, revision: 1);
      final cloud = MemoryCloud(sample(2), revision: 2)
        ..beforeDownload = () async {
          local.version++;
        };
      final c = controller(local, cloud);
      await c.synchronize();
      expect(c.status, BackupStatus.conflict);
      expect(local.restores, 0);
    },
  );
  test('edit during confirmed conflict resolution remains pending', () async {
    final local = MemoryLocal(sample(1), version: 2, saved: 1, revision: 1);
    final cloud = MemoryCloud(sample(2), revision: 2)
      ..beforeUpload = () async {
        local.version++;
        local.data = sample(3);
      };
    final c = controller(local, cloud);
    await c.synchronize();
    expect(c.status, BackupStatus.conflict);
    await c.resolve(useCloud: false);
    expect(c.status, BackupStatus.pending);
    expect(local.saved, 2);
    expect(local.version, 3);
    expect(cloud.data!.entries.single['show_id'], 1);
    expect(local.data.entries.single['show_id'], 3);
  });
  test('deletion on another device also blocks conflict resolution', () async {
    final local = MemoryLocal(sample(1), version: 2, saved: 1, revision: 1);
    final cloud = MemoryCloud(sample(2), revision: 2);
    final c = controller(local, cloud);
    await c.synchronize();
    expect(c.status, BackupStatus.conflict);
    cloud.deleting = true;
    await c.resolve(useCloud: false);
    expect(c.status, BackupStatus.deletionPending);
    expect(cloud.uploads, 0);
    expect(local.restores, 0);
  });
  test(
    'a racing second device cannot overwrite a newer remote revision',
    () async {
      final local = MemoryLocal(sample(1), version: 1);
      final cloud = MemoryCloud(null);
      cloud.beforeUpload = () async {
        cloud.revision++;
        cloud.data = sample(2);
      };
      final c = controller(local, cloud);
      await c.synchronize();
      expect(c.status, BackupStatus.conflict);
      expect(local.saved, 0);
      expect(cloud.data!.entries.single['show_id'], 2);
    },
  );
  test(
    'sign-out during download prevents late restoration into a retired session',
    () async {
      final local = MemoryLocal(empty);
      final cloud = MemoryCloud(sample(1), revision: 1);
      final c = controller(local, cloud);
      cloud.beforeDownload = () async {
        c.stop();
      };
      await c.synchronize();
      expect(local.restores, 0);
    },
  );
}
