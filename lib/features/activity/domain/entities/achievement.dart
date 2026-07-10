class AchievementCatalog {
  AchievementCatalog._();

  static const firstEpisode = 'first_episode';
  static const tenEpisodes = 'ten_episodes';
  static const fiftyEpisodes = 'fifty_episodes';
  static const hundredEpisodes = 'hundred_episodes';

  static const threeDayStreak = 'three_day_streak';
  static const sevenDayStreak = 'seven_day_streak';
  static const fourteenDayStreak = 'fourteen_day_streak';

  static const threeMonthStreak = 'three_month_streak';
  static const sixMonthStreak = 'six_month_streak';
  static const twelveMonthStreak = 'twelve_month_streak';

  static const codes = <String>[
    firstEpisode,
    tenEpisodes,
    fiftyEpisodes,
    hundredEpisodes,
    threeDayStreak,
    sevenDayStreak,
    fourteenDayStreak,
    threeMonthStreak,
    sixMonthStreak,
    twelveMonthStreak,
  ];
}

class UnlockedAchievement {
  const UnlockedAchievement({required this.code, required this.unlockedAt});

  final String code;
  final DateTime unlockedAt;

  Map<String, Object?> toMap() {
    return {'code': code, 'unlocked_at': unlockedAt.toUtc().toIso8601String()};
  }

  factory UnlockedAchievement.fromMap(Map<String, Object?> map) {
    return UnlockedAchievement(
      code: map['code'] as String,
      unlockedAt: DateTime.parse(map['unlocked_at'] as String),
    );
  }
}
