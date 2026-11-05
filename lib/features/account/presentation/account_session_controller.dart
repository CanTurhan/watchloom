import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/core/notifications/upcoming_episode_notification_service.dart';
import 'package:watchloom/features/account/data/cloud_backup_repository.dart';
import 'package:watchloom/features/account/data/sqlite_backup_store.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/account/presentation/backup_controller.dart';
import 'package:watchloom/features/activity/data/datasources/activity_local_data_source.dart';
import 'package:watchloom/features/activity/data/repositories/sqlite_activity_repository.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/data/datasources/library_local_data_source.dart';
import 'package:watchloom/features/library/data/repositories/sqlite_library_repository.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/settings/data/local_data_reset_service.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';

class AccountSessionController extends ChangeNotifier {
  AccountSessionController({
    required this.auth,
    required this.showRepository,
    required this.accessPolicy,
    required this.guestDatabase,
    required this.library,
    required this.activity,
  }) {
    auth.addListener(_authChanged);
  }
  final AuthController auth;
  final ShowRepository showRepository;
  final LibraryAccessPolicy accessPolicy;
  final WatchloomDatabase guestDatabase;
  LibraryController library;
  WatchActivityController activity;
  WatchloomDatabase? _accountDatabase;
  WatchloomDatabase get database => _accountDatabase ?? guestDatabase;
  BackupController? backup;
  bool switching = false;
  bool failed = false;
  bool hasGuestData = false;
  bool deletionPending = false;
  String? _uid;
  int _generation = 0;
  int get generation => _generation;
  bool _disposed = false;

  Future<void> initialize() async {
    hasGuestData = !(await SqliteBackupStore(
      guestDatabase,
    ).read()).data.isEmpty;
    if (auth.user != null && !switching) await _switch(auth.user!.uid);
  }

  void _authChanged() {
    final uid = auth.user?.uid;
    if (uid == null && _uid != null && auth.lastDeletedUserId == _uid) {
      unawaited(database.erase().catchError((Object _) {}));
    }
    if (uid != _uid || failed) {
      unawaited(_switch(uid));
    } else if (!switching) {
      if (auth.canBackup &&
          backup?.status == BackupStatus.verificationRequired) {
        unawaited(backup!.synchronize());
      }
      notifyListeners();
    }
  }

  Future<void> retry() => _switch(auth.user?.uid);

  Future<void> _switch(String? uid) async {
    final ticket = ++_generation;
    _uid = uid;
    switching = true;
    failed = false;
    deletionPending = false;
    backup?.dispose();
    backup = null;
    notifyListeners();
    final previousLibrary = library;
    final previousActivity = activity;
    try {
      // Notifications and generated share cards must not expose another account.
      try {
        await UpcomingEpisodeNotificationService.instance.disable(
          preservePreference: true,
        );
      } catch (_) {
        /* Unsupported platform. */
      }
      await LocalDataResetService.clearGeneratedShareImages(
        await getTemporaryDirectory(),
      );
      final db = uid == null ? guestDatabase : WatchloomDatabase(userId: uid);
      final nextLibrary = LibraryController(
        SqliteLibraryRepository(
          LibraryLocalDataSource(db, accessPolicy: accessPolicy),
        ),
        accessPolicy: accessPolicy,
      );
      final nextActivity = WatchActivityController(
        repository: SqliteActivityRepository(ActivityLocalDataSource(db)),
        libraryController: nextLibrary,
        showRepository: showRepository,
      );
      await nextLibrary.load();
      await nextActivity.load();
      final guestExists = !(await SqliteBackupStore(
        guestDatabase,
      ).read()).data.isEmpty;
      if (nextLibrary.error != null || nextActivity.error != null) {
        throw StateError('local-load-failed');
      }
      if (_disposed || ticket != _generation) {
        nextLibrary.dispose();
        nextActivity.dispose();
        return;
      }
      _accountDatabase = uid == null ? null : db;
      library = nextLibrary;
      activity = nextActivity;
      hasGuestData = guestExists;
      if (uid != null) {
        backup = _createBackup(uid, db, nextLibrary, nextActivity);
      }
      previousActivity.dispose();
      previousLibrary.dispose();
    } catch (_) {
      if (ticket == _generation) failed = true;
    } finally {
      if (!_disposed && ticket == _generation) {
        switching = false;
        notifyListeners();
        if (!failed && backup != null) unawaited(backup!.synchronize());
      }
    }
  }

  BackupController _createBackup(
    String uid,
    WatchloomDatabase db,
    LibraryController targetLibrary,
    WatchActivityController targetActivity,
  ) {
    final controller = BackupController(
      local: SqliteBackupStore(db),
      cloud: FirestoreBackupRepository(
        firestore: FirebaseFirestore.instanceFor(app: auth.auth!.app),
        uid: uid,
      ),
      onRestore: () async {
        await targetLibrary.load();
        await targetActivity.load();
      },
      canBackup: () => auth.user?.uid == uid && auth.canBackup,
      changes: db.changes,
    );
    controller.addListener(() {
      if (!deletionPending &&
          controller.status == BackupStatus.deletionPending &&
          !_disposed) {
        deletionPending = true;
        _generation++;
        unawaited(
          UpcomingEpisodeNotificationService.instance
              .disable(preservePreference: true)
              .catchError((Object _) {}),
        );
        notifyListeners();
      }
    });
    return controller;
  }

  Future<void> importGuest() async {
    final owner = auth.user?.uid;
    final target = database;
    if (auth.user == null ||
        switching ||
        backup?.isBusy == true ||
        backup?.status != BackupStatus.saved) {
      throw StateError('backup-not-ready');
    }
    final guest = await SqliteBackupStore(guestDatabase).read();
    if (auth.user?.uid != owner || database != target) return;
    // Existing legacy libraries above the cap remain intact when moving into an
    // empty account; this operation copies data, it does not add new shows.
    await SqliteBackupStore(target).importGuest(guest.data);
    if (auth.user?.uid != owner || database != target) return;
    await library.load();
    await activity.load();
    await backup?.synchronize();
  }

  Future<bool> deleteAccount({String? password}) async {
    final db = database;
    final owner = auth.user?.uid;
    backup?.stop();
    final result = await auth.deleteAccount(password: password);
    if (result) {
      // Remove the deleted identity's cache, without touching the guest library.
      await db.erase();
      if (owner != null) await auth.localDeletionCacheCleared(owner);
    } else if (auth.user != null) {
      // Keep the account page open so a failed deletion can be corrected.
      backup?.dispose();
      backup = _createBackup(auth.user!.uid, db, library, activity);
      notifyListeners();
      unawaited(backup!.synchronize());
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_authChanged);
    backup?.dispose();
    super.dispose();
  }
}
