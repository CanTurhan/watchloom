import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:watchloom/features/account/data/cloud_backup_repository.dart';
import 'package:watchloom/features/account/data/library_backup.dart';
import 'package:watchloom/features/account/data/firestore_account_store.dart';

enum BackupStatus {
  idle,
  pending,
  syncing,
  saved,
  offline,
  conflict,
  verificationRequired,
  deletionPending,
}

/// Snapshot synchronization with optimistic concurrency on both devices.
/// A newer cloud revision plus unsaved local edits always requires a choice.
class BackupController extends ChangeNotifier with WidgetsBindingObserver {
  BackupController({
    required this.local,
    required this.cloud,
    required this.onRestore,
    required this.canBackup,
    required this.changes,
  }) {
    changes.addListener(_schedule);
    WidgetsBinding.instance.addObserver(this);
  }
  final LocalBackupStore local;
  final CloudBackupRepository cloud;
  final Future<void> Function() onRestore;
  final bool Function() canBackup;
  final Listenable changes;
  BackupStatus status = BackupStatus.idle;
  DateTime? lastSaved;
  bool _bootstrapped = false;
  bool _stopped = false;
  bool _running = false;
  bool _queued = false;
  Timer? _timer;
  Future<void>? _pending;
  bool get isBusy => _running;

  void _schedule() {
    if (_stopped) return;
    if (status == BackupStatus.conflict ||
        status == BackupStatus.deletionPending) {
      return;
    }
    if (_running) {
      _queued = true;
      return;
    }
    _set(BackupStatus.pending);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () {
      unawaited(synchronize());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(synchronize());
  }

  Future<void> synchronize() {
    if (_stopped) return Future.value();
    if (_running) {
      _queued = true;
      return _pending ?? Future.value();
    }
    _pending = _synchronize();
    return _pending!;
  }

  Future<void> _synchronize() async {
    if (!canBackup()) {
      _set(BackupStatus.verificationRequired);
      return;
    }
    _running = true;
    _set(BackupStatus.syncing);
    try {
      if (!_bootstrapped) {
        await cloud.bootstrap();
        _bootstrapped = true;
      }
      final remote = await cloud.head();
      final snapshot = await local.read();
      if (_stopped) return;
      if (remote.revision != snapshot.state.remoteRevision) {
        if (snapshot.state.dirty || remote.id == null) {
          throw const BackupConflict();
        }
        final data = await cloud.download(remote);
        if (_stopped) return;
        await local.restore(
          data,
          expectedVersion: snapshot.state.version,
          remoteRevision: remote.revision,
        );
        if (_stopped) return;
        await onRestore();
      } else if (snapshot.state.dirty ||
          (remote.id == null && !snapshot.data.isEmpty)) {
        final revision = await cloud.upload(
          snapshot.data,
          expectedRevision: remote.revision,
        );
        if (_stopped) return;
        await local.acknowledge(snapshot.state.version, revision);
      }
      lastSaved = DateTime.now();
      final latest = await local.read();
      _set(latest.state.dirty ? BackupStatus.pending : BackupStatus.saved);
      if (latest.state.dirty) _queued = true;
    } on AccountDeletionPending {
      _set(BackupStatus.deletionPending);
    } on BackupConflict {
      _set(BackupStatus.conflict);
    } catch (_) {
      _set(BackupStatus.offline);
    } finally {
      _running = false;
      if (_queued &&
          !_stopped &&
          status != BackupStatus.conflict &&
          status != BackupStatus.deletionPending) {
        _queued = false;
        _schedule();
      }
    }
  }

  /// Called only after a destructive-resolution confirmation in the account UI.
  Future<void> resolve({required bool useCloud}) async {
    if (_running || _stopped || !canBackup()) return;
    _running = true;
    _set(BackupStatus.syncing);
    try {
      final remote = await cloud.head();
      final snapshot = await local.read();
      if (_stopped) return;
      if (useCloud) {
        if (remote.id == null) throw const BackupConflict();
        final data = await cloud.download(remote);
        if (_stopped) return;
        await local.restore(
          data,
          expectedVersion: snapshot.state.version,
          remoteRevision: remote.revision,
        );
        if (!_stopped) await onRestore();
      } else {
        final revision = await cloud.upload(
          snapshot.data,
          expectedRevision: remote.revision,
        );
        if (!_stopped) {
          await local.acknowledge(snapshot.state.version, revision);
        }
      }
      lastSaved = DateTime.now();
      final latest = await local.read();
      _set(latest.state.dirty ? BackupStatus.pending : BackupStatus.saved);
      if (latest.state.dirty) _queued = true;
    } on AccountDeletionPending {
      _set(BackupStatus.deletionPending);
    } on BackupConflict {
      _set(BackupStatus.conflict);
    } catch (_) {
      _set(BackupStatus.offline);
    } finally {
      _running = false;
      if (_queued &&
          !_stopped &&
          status != BackupStatus.conflict &&
          status != BackupStatus.deletionPending) {
        _queued = false;
        _schedule();
      }
    }
  }

  void _set(BackupStatus value) {
    if (_stopped) return;
    status = value;
    notifyListeners();
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    changes.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
