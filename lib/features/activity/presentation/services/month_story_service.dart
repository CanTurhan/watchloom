import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchloom/core/localization/app_activity_strings.dart';
import 'package:watchloom/core/localization/app_story_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';

class MonthStoryService {
  static const int imageWidth = 1080;
  static const int imageHeight = 1920;

  Future<ShareResult> createAndShare({
    required AppStrings strings,
    required WatchActivityController controller,
    required Rect sharePositionOrigin,
  }) async {
    final pngBytes = await _createStoryImage(
      strings: strings,
      controller: controller,
    );

    final directory = await getTemporaryDirectory();
    final now = DateTime.now();

    final filename = [
      'watchloom',
      now.year,
      now.month.toString().padLeft(2, '0'),
      now.millisecondsSinceEpoch,
    ].join('_');

    final file = File('${directory.path}/$filename.png');

    await file.writeAsBytes(pngBytes, flush: true);

    return SharePlus.instance.share(
      ShareParams(
        title: 'Watchloom',
        subject: '${strings.monthName(now.month)} ${now.year}',
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<Uint8List> _createStoryImage({
    required AppStrings strings,
    required WatchActivityController controller,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const size = Size(1080.0, 1920.0);

    _paintBackground(canvas, size);

    final now = DateTime.now();
    final monthLogs = controller.logsForMonth(now);
    final achievements = controller.achievementsUnlockedThisMonth;

    _drawText(
      canvas,
      'WATCHLOOM',
      const Offset(76, 82),
      928,
      const TextStyle(
        color: Color(0xFFB8AFFF),
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: 8,
      ),
    );

    _drawText(
      canvas,
      strings.myMonth.toUpperCase(),
      const Offset(76, 144),
      928,
      const TextStyle(
        color: Colors.white,
        fontSize: 82,
        fontWeight: FontWeight.w900,
        height: 0.95,
      ),
      maxLines: 2,
    );

    _drawText(
      canvas,
      '${strings.monthName(now.month)} ${now.year}',
      const Offset(78, 315),
      928,
      const TextStyle(
        color: Color(0xFFC9C7D5),
        fontSize: 36,
        fontWeight: FontWeight.w600,
      ),
    );

    _drawSummaryCards(canvas, strings: strings, controller: controller);

    _drawStreakCards(canvas, strings: strings, controller: controller);

    _drawAchievements(
      canvas,
      strings: strings,
      achievements: achievements
          .map((achievement) => strings.achievementTitle(achievement.code))
          .toList(growable: false),
    );

    _drawRecentActivity(canvas, strings: strings, logs: monthLogs);

    canvas.drawLine(
      const Offset(76, 1805),
      const Offset(1004, 1805),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 2,
    );

    _drawText(
      canvas,
      strings.madeWithWatchloom,
      const Offset(76, 1835),
      650,
      const TextStyle(
        color: Color(0xFFC9C7D5),
        fontSize: 25,
        fontWeight: FontWeight.w600,
      ),
    );

    _drawText(
      canvas,
      'Your shows, remembered.',
      const Offset(650, 1835),
      354,
      const TextStyle(
        color: Color(0xFFB8AFFF),
        fontSize: 23,
        fontWeight: FontWeight.w700,
      ),
      textAlign: TextAlign.right,
    );

    final picture = recorder.endRecording();

    final image = await picture.toImage(imageWidth, imageHeight);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('Story image could not be encoded.');
    }

    return byteData.buffer.asUint8List();
  }

  void _paintBackground(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        const [Color(0xFF090A12), Color(0xFF18132B), Color(0xFF0B0D16)],
        const [0, 0.52, 1],
      );

    canvas.drawRect(Offset.zero & size, backgroundPaint);

    canvas.drawCircle(
      const Offset(960, 120),
      360,
      Paint()..color = const Color(0xFF6D5BEF).withValues(alpha: 0.20),
    );

    canvas.drawCircle(
      const Offset(70, 970),
      390,
      Paint()..color = const Color(0xFF4435B7).withValues(alpha: 0.12),
    );

    canvas.drawCircle(
      const Offset(1030, 1650),
      300,
      Paint()..color = const Color(0xFF7867F5).withValues(alpha: 0.10),
    );
  }

  void _drawSummaryCards(
    Canvas canvas, {
    required AppStrings strings,
    required WatchActivityController controller,
  }) {
    const y = 405.0;
    const height = 210.0;
    const gap = 18.0;
    const width = 297.0;

    final watchTime = _formatWatchTime(controller.monthWatchMinutes);

    final values = [
      '${controller.monthEpisodeCount}',
      '${controller.monthShowCount}',
      watchTime,
    ];

    final labels = [
      strings.episodes.toUpperCase(),
      strings.shows.toUpperCase(),
      strings.watchTimeLabel.toUpperCase(),
    ];

    for (var index = 0; index < values.length; index++) {
      final x = 76 + ((width + gap) * index);

      _drawCard(canvas, Rect.fromLTWH(x, y, width, height));

      _drawText(
        canvas,
        values[index],
        Offset(x + 25, y + 36),
        width - 50,
        const TextStyle(
          color: Colors.white,
          fontSize: 58,
          fontWeight: FontWeight.w900,
        ),
      );

      _drawText(
        canvas,
        labels[index],
        Offset(x + 25, y + 132),
        width - 50,
        const TextStyle(
          color: Color(0xFFAAA7B8),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        maxLines: 2,
      );
    }
  }

  void _drawStreakCards(
    Canvas canvas, {
    required AppStrings strings,
    required WatchActivityController controller,
  }) {
    const y = 660.0;
    const height = 230.0;
    const gap = 18.0;
    const width = 297.0;

    final values = [
      controller.currentDailyStreak,
      controller.bestDailyStreak,
      controller.currentMonthlyStreak,
    ];

    final labels = [
      strings.storyCurrentStreak,
      strings.storyBestStreak,
      strings.storyMonthlyStreak,
    ];

    final units = [strings.dayUnit, strings.dayUnit, strings.monthUnit];

    final icons = [
      Icons.local_fire_department_rounded,
      Icons.workspace_premium_rounded,
      Icons.calendar_month_rounded,
    ];

    for (var index = 0; index < values.length; index++) {
      final x = 76 + ((width + gap) * index);

      _drawCard(canvas, Rect.fromLTWH(x, y, width, height));

      _drawIcon(
        canvas,
        icons[index],
        Offset(x + 25, y + 26),
        const Color(0xFFB8AFFF),
        38,
      );

      _drawText(
        canvas,
        '${values[index]} ${units[index]}',
        Offset(x + 25, y + 92),
        width - 50,
        const TextStyle(
          color: Colors.white,
          fontSize: 39,
          fontWeight: FontWeight.w900,
        ),
      );

      _drawText(
        canvas,
        labels[index],
        Offset(x + 25, y + 163),
        width - 50,
        const TextStyle(
          color: Color(0xFFAAA7B8),
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        maxLines: 2,
      );
    }
  }

  void _drawAchievements(
    Canvas canvas, {
    required AppStrings strings,
    required List<String> achievements,
  }) {
    _drawText(
      canvas,
      strings.storyAchievements,
      const Offset(76, 950),
      928,
      const TextStyle(
        color: Color(0xFFB8AFFF),
        fontSize: 23,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
      ),
    );

    final rect = const Rect.fromLTWH(76, 1000, 928, 250);

    _drawCard(canvas, rect);

    if (achievements.isEmpty) {
      _drawIcon(
        canvas,
        Icons.lock_outline_rounded,
        const Offset(112, 1080),
        const Color(0xFFAAA7B8),
        42,
      );

      _drawText(
        canvas,
        strings.storyNoAchievements,
        const Offset(185, 1083),
        770,
        const TextStyle(
          color: Color(0xFFCAC8D4),
          fontSize: 27,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
      );

      return;
    }

    final visible = achievements.take(3).toList();

    for (var index = 0; index < visible.length; index++) {
      final y = 1035.0 + (index * 65.0);

      _drawIcon(
        canvas,
        Icons.emoji_events_rounded,
        Offset(112, y),
        const Color(0xFFFFD166),
        31,
      );

      _drawText(
        canvas,
        visible[index],
        Offset(165, y + 1),
        790,
        const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      );
    }
  }

  void _drawRecentActivity(
    Canvas canvas, {
    required AppStrings strings,
    required List<EpisodeWatchLog> logs,
  }) {
    _drawText(
      canvas,
      strings.storyRecentActivity,
      const Offset(76, 1310),
      928,
      const TextStyle(
        color: Color(0xFFB8AFFF),
        fontSize: 23,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
      ),
    );

    final rect = const Rect.fromLTWH(76, 1360, 928, 385);

    _drawCard(canvas, rect);

    if (logs.isEmpty) {
      _drawIcon(
        canvas,
        Icons.history_rounded,
        const Offset(112, 1515),
        const Color(0xFFAAA7B8),
        42,
      );

      _drawText(
        canvas,
        strings.storyNoActivity,
        const Offset(185, 1518),
        760,
        const TextStyle(
          color: Color(0xFFCAC8D4),
          fontSize: 27,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
      );

      return;
    }

    final visibleLogs = logs.take(4).toList();

    for (var index = 0; index < visibleLogs.length; index++) {
      final log = visibleLogs[index];
      final y = 1394.0 + (index * 82.0);

      canvas.drawCircle(
        Offset(124, y + 27),
        24,
        Paint()..color = const Color(0xFF4ADE80).withValues(alpha: 0.16),
      );

      _drawIcon(
        canvas,
        Icons.check_rounded,
        Offset(108, y + 11),
        const Color(0xFF4ADE80),
        32,
      );

      _drawText(
        canvas,
        log.showName,
        Offset(173, y),
        560,
        const TextStyle(
          color: Colors.white,
          fontSize: 27,
          fontWeight: FontWeight.w800,
        ),
      );

      _drawText(
        canvas,
        log.episodeCode,
        Offset(760, y + 3),
        190,
        const TextStyle(
          color: Color(0xFFB8AFFF),
          fontSize: 23,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.right,
      );
    }
  }

  void _drawCard(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(32));

    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF21212D).withValues(alpha: 0.94),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.08),
    );
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset offset,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  double _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double maxWidth,
    TextStyle style, {
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, offset);

    return painter.height;
  }

  String _formatWatchTime(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}m';
    }

    return '${hours}h ${remainingMinutes}m';
  }
}
