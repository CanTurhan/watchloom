import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

enum NotificationReminderTiming {
  oneDayBefore,
  threeHoursBefore,
  oneHourBefore,
  atAirTime,
}

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

  static const String _reminderTimingKey = 'upcoming_episode_reminder_timing';

  static const String _channelId = 'watchloom_upcoming_episodes';

  static const int _testNotificationId = 2999999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<int> _showOpenController =
      StreamController<int>.broadcast();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.tvmaze.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  bool _initialized = false;
  bool _syncing = false;
  int _syncGeneration = 0;
  int? _pendingShowId;

  Stream<int> get showOpenRequests {
    return _showOpenController.stream;
  }

  int? takePendingShowId() {
    final showId = _pendingShowId;
    _pendingShowId = null;
    return showId;
  }

  Future<void> initialize() async {
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

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingShowId = _parseShowId(
        launchDetails?.notificationResponse?.payload,
      );
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final showId = _parseShowId(response.payload);

    if (showId == null) {
      return;
    }

    _showOpenController.add(showId);
  }

  int? _parseShowId(String? payload) {
    if (payload == null || !payload.startsWith('show:')) {
      return null;
    }

    return int.tryParse(payload.substring('show:'.length));
  }

  Future<bool> get isEnabled async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<int> get scheduledCount async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getStringList(_scheduledIdsKey)?.length ?? 0;
  }

  Future<NotificationReminderTiming> get reminderTiming async {
    final preferences = await SharedPreferences.getInstance();

    final storedValue = preferences.getString(_reminderTimingKey);

    for (final timing in NotificationReminderTiming.values) {
      if (timing.name == storedValue) {
        return timing;
      }
    }

    return NotificationReminderTiming.oneDayBefore;
  }

  Future<void> setReminderTiming(NotificationReminderTiming timing) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_reminderTimingKey, timing.name);
  }

  Future<NotificationSyncResult> enableAndSync({
    required List<LibraryEntry> entries,
    required bool isTurkish,
  }) async {
    await initialize();

    final permissionGranted = await _requestPermission();

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

  Future<void> disable({bool preservePreference = false}) async {
    _syncGeneration++;
    _syncing = false;
    await initialize();

    final preferences = await SharedPreferences.getInstance();

    final ids = preferences.getStringList(_scheduledIdsKey) ?? const <String>[];

    for (final value in ids) {
      final id = int.tryParse(value);

      if (id != null) {
        await _plugin.cancel(id);
      }
    }

    await _plugin.cancel(_testNotificationId);

    if (!preservePreference) await preferences.setBool(_enabledKey, false);

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

  Future<bool> showTestNotification({
    required LibraryEntry entry,
    required bool isTurkish,
  }) async {
    await initialize();

    if (!await isEnabled) {
      return false;
    }

    final title = isTurkish
        ? 'Watchloom test bildirimi'
        : 'Watchloom test notification';

    final body = isTurkish
        ? '${entry.name} detayını açmak için bildirime dokun.'
        : 'Tap to open ${entry.name}.';

    await _plugin.show(
      _testNotificationId,
      title,
      body,
      _notificationDetails(),
      payload: 'show:${entry.showId}',
    );

    return true;
  }

  Future<bool> _requestPermission() async {
    var granted = true;

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final iosResult = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (iosResult == false) {
      granted = false;
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final androidResult = await androidPlugin?.requestNotificationsPermission();

    if (androidResult == false) {
      granted = false;
    }

    return granted;
  }

  Future<int> _sync({
    required List<LibraryEntry> entries,
    required bool isTurkish,
  }) async {
    if (_syncing) {
      return await scheduledCount;
    }

    _syncing = true;
    final generation = _syncGeneration;

    try {
      await initialize();
      if (generation != _syncGeneration) return 0;
      await _cancelPreviouslyScheduled(generation);

      final selectedTiming = await reminderTiming;

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
        if (generation != _syncGeneration) return 0;
        try {
          final nextEpisode = await _loadNextEpisode(entry.showId);
          if (generation != _syncGeneration) return 0;

          if (nextEpisode == null) {
            continue;
          }

          final notificationTime = _calculateNotificationTime(
            nextEpisode.airDateTime,
            selectedTiming,
          );

          if (notificationTime == null) {
            continue;
          }

          final notificationId = 2000000 + entry.showId;

          final season = nextEpisode.season.toString().padLeft(2, '0');

          final episode = nextEpisode.episode.toString().padLeft(2, '0');

          final title = isTurkish
              ? '${entry.name} yakında yayınlanıyor'
              : '${entry.name} is coming soon';

          final body = isTurkish
              ? 'S$season · B$episode bölümü yakında yayınlanacak.'
              : 'Season $season, episode $episode will be released soon.';

          await _plugin.zonedSchedule(
            notificationId,
            title,
            body,
            tz.TZDateTime.from(notificationTime, tz.local),
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'show:${entry.showId}',
          );
          if (generation != _syncGeneration) {
            await _plugin.cancel(notificationId);
            return 0;
          }

          scheduledIds.add('$notificationId');
        } catch (_) {
          continue;
        }
      }

      final preferences = await SharedPreferences.getInstance();
      if (generation != _syncGeneration) return 0;

      await preferences.setStringList(_scheduledIdsKey, scheduledIds);

      return scheduledIds.length;
    } finally {
      if (generation == _syncGeneration) _syncing = false;
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Upcoming Episodes',
        channelDescription: 'Reminders for upcoming television episodes',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: 'watchloom_upcoming_episodes',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _cancelPreviouslyScheduled(int generation) async {
    final preferences = await SharedPreferences.getInstance();

    final oldIds =
        preferences.getStringList(_scheduledIdsKey) ?? const <String>[];

    for (final value in oldIds) {
      if (generation != _syncGeneration) return;
      final id = int.tryParse(value);

      if (id != null) {
        await _plugin.cancel(id);
      }
    }

    if (generation == _syncGeneration) {
      await preferences.remove(_scheduledIdsKey);
    }
  }

  DateTime? _calculateNotificationTime(
    DateTime episodeDate,
    NotificationReminderTiming timing,
  ) {
    final now = DateTime.now();

    final DateTime notificationTime;

    switch (timing) {
      case NotificationReminderTiming.oneDayBefore:
        notificationTime = episodeDate.subtract(const Duration(days: 1));

      case NotificationReminderTiming.threeHoursBefore:
        notificationTime = episodeDate.subtract(const Duration(hours: 3));

      case NotificationReminderTiming.oneHourBefore:
        notificationTime = episodeDate.subtract(const Duration(hours: 1));

      case NotificationReminderTiming.atAirTime:
        notificationTime = episodeDate;
    }

    if (!notificationTime.isAfter(now.add(const Duration(minutes: 2)))) {
      return null;
    }

    return notificationTime;
  }

  Future<_NextEpisode?> _loadNextEpisode(int showId) async {
    final response = await _dio.get<dynamic>('/shows/$showId/episodes');

    final data = response.data;

    if (data is! List) {
      return null;
    }

    final now = DateTime.now();

    _NextEpisode? nearest;

    for (final rawEpisode in data) {
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

    if (airStamp != null && airStamp.trim().isNotEmpty) {
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
