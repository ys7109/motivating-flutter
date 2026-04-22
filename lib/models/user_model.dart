class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoURL;
  final int level;
  final int xp;
  final int xpToNext;
  final int streak;
  final int maxStreak;
  final String lastStreakDate;
  final int reviveItem;
  final Map<String, dynamic> streakBadges;
  final int totalFocusMin;
  final String lastAttendDate;
  final CharacterModel character;
  final bool onboardingDone;
  final DateTime? withdrawScheduledAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoURL,
    required this.level,
    required this.xp,
    required this.xpToNext,
    required this.streak,
    required this.maxStreak,
    required this.lastStreakDate,
    required this.reviveItem,
    required this.streakBadges,
    required this.totalFocusMin,
    required this.lastAttendDate,
    required this.character,
    required this.onboardingDone,
    this.withdrawScheduledAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '새로운 모험가',
      email: map['email'] ?? '',
      photoURL: map['photoURL'] ?? '',
      level: map['level'] ?? 1,
      xp: map['xp'] ?? 0,
      xpToNext: map['xpToNext'] ?? 300,
      streak: map['streak'] ?? 0,
      maxStreak: map['maxStreak'] ?? 0,
      lastStreakDate: map['lastStreakDate'] ?? '',
      reviveItem: map['reviveItem'] ?? 0,
      streakBadges: Map<String, dynamic>.from(map['streakBadges'] ?? {}),
      totalFocusMin: map['totalFocusMin'] ?? 0,
      lastAttendDate: map['lastAttendDate'] ?? '',
      character: CharacterModel.fromMap(map['character'] ?? {}),
      onboardingDone: map['onboardingDone'] ?? false,
      withdrawScheduledAt: map['withdrawScheduledAt'] != null
          ? (map['withdrawScheduledAt'] as dynamic).toDate()
          : null,
    );
  }

  UserModel copyWith({
    String? name,
    int? level,
    int? xp,
    int? xpToNext,
    int? streak,
    int? maxStreak,
    String? lastStreakDate,
    int? reviveItem,
    int? totalFocusMin,
    String? lastAttendDate,
    CharacterModel? character,
    bool? onboardingDone,
    DateTime? withdrawScheduledAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoURL: photoURL,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNext: xpToNext ?? this.xpToNext,
      streak: streak ?? this.streak,
      maxStreak: maxStreak ?? this.maxStreak,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      reviveItem: reviveItem ?? this.reviveItem,
      streakBadges: streakBadges,
      totalFocusMin: totalFocusMin ?? this.totalFocusMin,
      lastAttendDate: lastAttendDate ?? this.lastAttendDate,
      character: character ?? this.character,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      withdrawScheduledAt: withdrawScheduledAt ?? this.withdrawScheduledAt,
    );
  }
}

class CharacterModel {
  final String skin;
  final String badge;
  final String frame;

  CharacterModel({
    this.skin = 'default',
    this.badge = 'none',
    this.frame = 'none',
  });

  factory CharacterModel.fromMap(Map<String, dynamic> map) {
    return CharacterModel(
      skin: map['skin'] ?? 'default',
      badge: map['badge'] ?? 'none',
      frame: map['frame'] ?? 'none',
    );
  }

  Map<String, dynamic> toMap() => {
    'skin': skin,
    'badge': badge,
    'frame': frame,
  };
}