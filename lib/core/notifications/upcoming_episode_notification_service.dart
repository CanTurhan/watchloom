import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

class NotificationSyncResult {
  const NotificationSyncResult({
    required this.permissionGranted,
    required this.scheduledCount,
  });

  final bool permissionGranted;
  final int scheduledCount;
}

class UpcomingEpisodeNotificationService {
  UpcomingEpisodeNotificationService._();

  static final UpcomingEpisodeNotificationService instance =
      UpcomingEpisodeNotificationService._();

  static const String _enabledKey = 'upcoming_episode_notifications_enabled';

  static const String _scheduledIdsKey = 'upcoming_episode_notification_ids';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.tvmaze.com',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  bool _initialized = false;
  bool _syncing = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(initializationSettings);

    _initialized = true;
  }

  Future<bool> get isEnabled async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<NotificationSyncResult> enableAndSync({
    required List<LibraryEntry> entries,
    required bool isTurkish,
  }) async {
    await _ensureInitialized();

    var permissionGranted = true;

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final iosPermission = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (iosPermission == false) {
      permissionGranted = false;
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final androidPermission = await androidPlugin
        ?.requestNotificationsPermission();

    if (androidPermission == false) {
      permissionGranted = false;
    }

    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_enabledKey, permissionGranted);

    if (!permissionGranted) {
      return const NotificationSyncResult(
        permissionGranted: false,
        scheduledCount: 0,
      );
    }

    final count = await _sync(entries: entries, isTurkish: isTurkish);

    return NotificationSyncResult(
      permissionGranted: true,
      scheduledCount: count,
    );
  }

  Future<void> disable() async {
    await _ensureInitialized();

    final preferences = await SharedPreferences.getInstance();

    final ids = preferences.getStringList(_scheduledIdsKey) ?? const <String>[];

    for (final value in ids) {
      final id = int.tryParse(value);

      if (id != null) {
        await _plugin.cancel(id);
      }
    }

    await preferences.setBool(_enabledKey, false);

    await preferences.remove(_scheduledIdsKey);
  }

  Future<int> syncIfEnabled({
    required List<LibraryEntry> entries,
    required bool isTurkish,
  }) async {
    if (!await isEnabled) {
      return 0;
    }

    return _sync(entries: entries, isTurkish: isTurkish);
  }

  Future<int> _sync({
    required List<LibraryEntry> entries,
    required bool isTurkish,
  }) async {
    if (_syncing) {
      return 0;
    }

    _syncing = true;

    try {
      await _ensureInitialized();

      final preferences = await SharedPreferences.getInstance();

      final oldIds =
          preferences.getStringList(_scheduledIdsKey) ?? const <String>[];

      for (final value in oldIds) {
        final id = int.tryParse(value);

        if (id != null) {
          await _plugin.cancel(id);
        }
      }

      final eligibleEntries = entries
          .where(
            (entry) =>
                entry.status != LibraryStatus.completed &&
                entry.status != LibraryStatus.dropped,
          )
          .take(32)
          .toList(growable: false);

      final scheduledIds = <String>[];

      for (final entry in eligibleEntries) {
        try {
          final episode = await _loadNextEpisode(entry.showId);

          if (episode == null) {
            continue;
          }

          final now = DateTime.now();

          var notificationTime = episode.airDateTime.subtract(
            const Duration(days: 1),
          );

          if (!notificationTime.isAfter(now)) {
            notificationTime = episode.airDateTime.subtract(
              const Duration(hours: 1),
            );
          }

          if (!notificationTime.isAfter(now.add(const Duration(minutes: 1)))) {
            continue;
          }

          final notificationId = 1000000 + entry.showId;

          final seasonText = episode.season.toString().padLeft(2, '0');

          final episodeText = episode.episode.toString().padLeft(2, '0');

          final title = isTurkish
              ? '${entry.name} yakında yayınlanıyor'
              : '${entry.name} is coming soon';

          final body = isTurkish
              ? 'S$seasonText · B$episodeText yaklaşan bölümünü unutma.'
              : 'Do not miss the upcoming S$seasonText · E$episodeText.';

          const details = NotificationDetails(
            android: AndroidNotificationDetails(
              'upcoming_episodes',
              'Upcoming Episodes',
              channelDescription: 'Notifications for upcoming TV episodes',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              threadIdentifier: 'upcoming_episodes',
            ),
          );

          await _plugin.zonedSchedule(
            notificationId,
            title,
            body,
            tz.TZDateTime.from(notificationTime, tz.local),
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'show:${entry.showId}',
          );

          scheduledIds.add('$notificationId');
        } catch (_) {
          continue;
        }
      }

      await preferences.setStringList(_scheduledIdsKey, scheduledIds);

      return scheduledIds.length;
    } finally {
      _syncing = false;
    }
  }

  Future<_NextEpisode?> _loadNextEpisode(int showId) async {
    final response = await _dio.get<List<dynamic>>('/shows/$showId/episodes');

    final episodes = response.data ?? const <dynamic>[];

    final now = DateTime.now();

    _NextEpisode? nearest;

    for (final rawEpisode in episodes) {
      if (rawEpisode is! Map) {
        continue;
      }

      final episode = Map<String, dynamic>.from(rawEpisode);

      final season = (episode['season'] as num?)?.toInt();

      final episodeNumber = (episode['number'] as num?)?.toInt();

      if (season == null || episodeNumber == null) {
        continue;
      }

      final airDateTime = _parseAirDateTime(episode);

      if (airDateTime == null || !airDateTime.isAfter(now)) {
        continue;
      }

      final candidate = _NextEpisode(
        season: season,
        episode: episodeNumber,
        airDateTime: airDateTime,
      );

      if (nearest == null ||
          candidate.airDateTime.isBefore(nearest.airDateTime)) {
        nearest = candidate;
      }
    }

    return nearest;
  }

  DateTime? _parseAirDateTime(Map<String, dynamic> episode) {
    final airStamp = episode['airstamp']?.toString();

    if (airStamp != null && airStamp.isNotEmpty) {
      final parsed = DateTime.tryParse(airStamp);

      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    final airDate = episode['airdate']?.toString();

    final parsedDate = DateTime.tryParse(airDate ?? '');

    if (parsedDate == null) {
      return null;
    }

    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 20);
  }
}

class _NextEpisode {
  const _NextEpisode({
    required this.season,
    required this.episode,
    required this.airDateTime,
  });

  final int season;
  final int episode;
  final DateTime airDateTime;
}
