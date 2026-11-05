import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:watchloom/features/activity/domain/entities/achievement.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

/// A versioned, validated snapshot. No authentication tokens or Premium state.
class LibraryBackup {
  const LibraryBackup({
    required this.entries,
    required this.logs,
    required this.achievements,
  });
  final List<Map<String, Object?>> entries;
  final List<Map<String, Object?>> logs;
  final List<Map<String, Object?>> achievements;
  bool get isEmpty => entries.isEmpty && logs.isEmpty && achievements.isEmpty;
  static const maxBytes = 64 * 1024 * 1024;

  Uint8List encode() {
    final json = utf8.encode(
      jsonEncode({
        'schema': 1,
        'entries': entries,
        'logs': logs,
        'achievements': achievements,
      }),
    );
    if (json.length > maxBytes) throw const FormatException('backup-too-large');
    return Uint8List.fromList(gzip.encode(json));
  }

  static String digest(List<int> bytes) => sha256.convert(bytes).toString();

  static LibraryBackup decode(List<int> bytes) {
    // Limit expansion before parsing, including corrupt or malicious payloads.
    final output = _LimitedBytes(maxBytes);
    final decoder = gzip.decoder.startChunkedConversion(output);
    decoder.add(bytes);
    decoder.close();
    final data = jsonDecode(utf8.decode(output.bytes));
    if (data is! Map || data['schema'] != 1) {
      throw const FormatException('unsupported-backup');
    }
    List<Map<String, Object?>> rows(String key) {
      final list = data[key];
      if (list is! List) throw const FormatException('invalid-backup');
      return list.map((row) => Map<String, Object?>.from(row as Map)).toList();
    }

    // Round-trip domain parsing also strips unexpected SQL column names.
    final entries = rows(
      'entries',
    ).map((row) => LibraryEntry.fromMap(row).toMap()).toList();
    final logs = rows(
      'logs',
    ).map((row) => EpisodeWatchLog.fromMap(row).toMap()..remove('id')).toList();
    final achievements = rows(
      'achievements',
    ).map((row) => UnlockedAchievement.fromMap(row).toMap()).toList();
    if (entries.map((r) => r['show_id']).toSet().length != entries.length ||
        logs.map((r) => '${r['show_id']}:${r['episode_id']}').toSet().length !=
            logs.length ||
        achievements.map((r) => r['code']).toSet().length !=
            achievements.length) {
      throw const FormatException('duplicate-backup-record');
    }
    return LibraryBackup(
      entries: entries,
      logs: logs,
      achievements: achievements,
    );
  }
}

class _LimitedBytes implements Sink<List<int>> {
  _LimitedBytes(this.limit);
  final int limit;
  final _builder = BytesBuilder(copy: false);
  int _length = 0;
  Uint8List get bytes => _builder.takeBytes();
  @override
  void add(List<int> chunk) {
    if (_length + chunk.length > limit) {
      throw const FormatException('backup-too-large');
    }
    _length += chunk.length;
    _builder.add(chunk);
  }

  @override
  void close() {}
}

class LocalBackupState {
  const LocalBackupState({
    required this.version,
    required this.savedVersion,
    required this.remoteRevision,
  });
  final int version;
  final int savedVersion;
  final int remoteRevision;
  bool get dirty => version != savedVersion;
}

class LocalBackupSnapshot {
  const LocalBackupSnapshot(this.data, this.state);
  final LibraryBackup data;
  final LocalBackupState state;
}

abstract interface class LocalBackupStore {
  Future<LocalBackupSnapshot> read();
  Future<void> acknowledge(int localVersion, int remoteRevision);
  Future<void> restore(
    LibraryBackup data, {
    required int expectedVersion,
    required int remoteRevision,
  });
}

class BackupConflict implements Exception {
  const BackupConflict();
}
