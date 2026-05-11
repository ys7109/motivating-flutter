import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoURL;
  // 사용자가 직접 업로드한 프로필 이미지 URL (없으면 캐릭터 아바타 사용)
  final String? profileImageUrl;
  final int level;
  final int xp;
  final int xpToNext;
  final int totalXp;   // 누적 총 경험치 — 레벨 배율 변경 시 재계산 기준
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
  final DateTime? createdAt;

  // 업적
  final Set<String> achievements;         // 달성한 업적 ID 목록
  final Set<String> claimedAchievements;  // 보상을 수령한 업적 ID 목록
  final String? equippedAchievement;      // 현재 장착 중인 업적 ID
  final Map<String, DateTime> achievementUnlockedAt; // 업적 달성 시각

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoURL,
    this.profileImageUrl,
    required this.level,
    required this.xp,
    required this.xpToNext,
    required this.totalXp,
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
    this.createdAt,
    this.achievements = const {},
    this.claimedAchievements = const {},
    this.equippedAchievement,
    this.achievementUnlockedAt = const {},
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // achievementUnlockedAt: Map<String, Timestamp> → Map<String, DateTime>
    final rawUnlocked =
        map['achievementUnlockedAt'] as Map<String, dynamic>? ?? {};
    final unlockedAt = rawUnlocked.map((k, v) =>
        MapEntry(k, v is Timestamp ? v.toDate() : DateTime.now()));

    final level = map['level'] ?? 1;
    final xp = (map['xp'] ?? 0) as int;

    // totalXp 없는 기존 유저 — level과 xp로 역산 (1.15배 기준)
    final totalXp = map['totalXp'] != null
        ? (map['totalXp'] as int)
        : _calcTotalXpLegacy(level, xp);

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '새로운 모험가',
      email: map['email'] ?? '',
      photoURL: map['photoURL'] ?? '',
      // 사용자가 직접 업로드한 프로필 이미지 URL
      profileImageUrl: map['profileImageUrl'] as String?,
      level: level,
      xp: xp,
      xpToNext: map['xpToNext'] ?? 300,
      totalXp: totalXp,
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
          ? (map['withdrawScheduledAt'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      achievements: Set<String>.from(map['achievements'] ?? []),
      claimedAchievements:
          Set<String>.from(map['claimedAchievements'] ?? []),
      equippedAchievement: map['equippedAchievement'] as String?,
      achievementUnlockedAt: unlockedAt,
    );
  }

  // 기존 유저 마이그레이션용 — 1.15배 기준으로 totalXp 역산
  static int _calcTotalXpLegacy(int level, int xp) {
    int total = xp;
    int req = 100;
    for (int i = 1; i < level; i++) {
      total += req;
      req = (req * 1.15).round();
    }
    return total;
  }

  UserModel copyWith({
    String? name,
    String? profileImageUrl,
    int? level,
    int? xp,
    int? xpToNext,
    int? totalXp,
    int? streak,
    int? maxStreak,
    String? lastStreakDate,
    int? reviveItem,
    int? totalFocusMin,
    String? lastAttendDate,
    CharacterModel? character,
    bool? onboardingDone,
    DateTime? withdrawScheduledAt,
    DateTime? createdAt,
    Set<String>? achievements,
    Set<String>? claimedAchievements,
    Object? equippedAchievement = _sentinel,
    Map<String, DateTime>? achievementUnlockedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoURL: photoURL,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNext: xpToNext ?? this.xpToNext,
      totalXp: totalXp ?? this.totalXp,
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
      createdAt: createdAt ?? this.createdAt,
      achievements: achievements ?? this.achievements,
      claimedAchievements: claimedAchievements ?? this.claimedAchievements,
      equippedAchievement: equippedAchievement == _sentinel
          ? this.equippedAchievement
          : equippedAchievement as String?,
      achievementUnlockedAt:
          achievementUnlockedAt ?? this.achievementUnlockedAt,
    );
  }
}

// null을 명시적으로 전달하기 위한 sentinel 객체
const Object _sentinel = Object();

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