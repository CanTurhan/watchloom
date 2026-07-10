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

  static const String _channelId = 'watchloom_upcoming_episodes';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.tvmaze.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  bool _initialized = false;
  bool _syncing = false;

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

    await _plugin.initialize(settings);

    _initialized = true;
  }

  Future<bool> get isEnabled async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<int> get scheduledCount async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getStringList(_scheduledIdsKey)?.length ?? 0;
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

  Future<void> disable() async {
    await initialize();

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
      return scheduledCount;
    }

    _syncing = true;

    try {
      await initialize();

      await _cancelPreviouslyScheduled();

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
          final nextEpisode = await _loadNextEpisode(entry.showId);

          if (nextEpisode == null) {
            continue;
          }

          final notificationTime = _calculateNotificationTime(
            nextEpisode.airDateTime,
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

          const notificationDetails = NotificationDetails(
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

          await _plugin.zonedSchedule(
            notificationId,
            title,
            body,
            tz.TZDateTime.from(notificationTime, tz.local),
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'show:${entry.showId}',
          );

          scheduledIds.add('$notificationId');
        } catch (_) {
          continue;
        }
      }

      final preferences = await SharedPreferences.getInstance();

      await preferences.setStringList(_scheduledIdsKey, scheduledIds);

      return scheduledIds.length;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _cancelPreviouslyScheduled() async {
    final preferences = await SharedPreferences.getInstance();

    final oldIds =
        preferences.getStringList(_scheduledIdsKey) ?? const <String>[];

    for (final value in oldIds) {
      final id = int.tryParse(value);

      if (id != null) {
        await _plugin.cancel(id);
      }
    }

    await preferences.remove(_scheduledIdsKey);
  }

  DateTime? _calculateNotificationTime(DateTime episodeDate) {
    final now = DateTime.now();

    var notificationTime = episodeDate.subtract(const Duration(days: 1));

    if (!notificationTime.isAfter(now)) {
      notificationTime = episodeDate.subtract(const Duration(hours: 1));
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
