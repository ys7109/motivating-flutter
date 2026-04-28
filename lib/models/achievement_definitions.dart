class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final String category;   // goal | streak | focus | level | social
  final String difficulty; // easy | normal | hard | legend
  final int xpReward;
  final String skinReward; // 업적 전용 스킨 ID (= id)
  // 전체 유저 중 달성률 (%) — 클라이언트에서 Firestore stats로 채워넣음
  final double? globalPct;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.xpReward,
    String? skinReward,
    this.globalPct,
  }) : skinReward = skinReward ?? id;

  Achievement copyWith({double? globalPct}) => Achievement(
    id: id, emoji: emoji, title: title, description: description,
    category: category, difficulty: difficulty, xpReward: xpReward,
    skinReward: skinReward, globalPct: globalPct ?? this.globalPct,
  );
}

// 난이도별 XP: easy=50, normal=100, hard=300, legend=600
class Achievements {
  static const all = [
    // ── 목표 ──
    Achievement(id: 'goal_first',   emoji: '🎯', title: '첫 걸음',        description: '첫 번째 목표를 완료했어요',        category: 'goal',   difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'goal_10',      emoji: '🏅', title: '목표 달인',       description: '목표를 10개 완료했어요',           category: 'goal',   difficulty: 'normal', xpReward: 100),
    Achievement(id: 'goal_50',      emoji: '🥈', title: '목표 고수',       description: '목표를 50개 완료했어요',           category: 'goal',   difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'goal_100',     emoji: '🥇', title: '목표 마스터',     description: '목표를 100개 완료했어요',          category: 'goal',   difficulty: 'legend', xpReward: 600),
    Achievement(id: 'repeat_first', emoji: '🔄', title: '꾸준함의 시작',   description: '반복 목표를 처음 전부 완료했어요', category: 'goal',   difficulty: 'normal', xpReward: 100),

    // ── 스트릭 ──
    Achievement(id: 'streak_7',     emoji: '🔥', title: '7일의 불꽃',      description: '7일 연속 출석했어요',              category: 'streak', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'streak_30',    emoji: '🌙', title: '한 달의 여정',    description: '30일 연속 출석했어요',             category: 'streak', difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'streak_100',   emoji: '💫', title: '100일의 기적',    description: '100일 연속 출석했어요',            category: 'streak', difficulty: 'legend', xpReward: 600),
    Achievement(id: 'streak_365',   emoji: '🌟', title: '1년의 전설',      description: '365일 연속 출석했어요',            category: 'streak', difficulty: 'legend', xpReward: 600),

    // ── 집중 ──
    Achievement(id: 'focus_1h',     emoji: '⏱',  title: '집중 입문',       description: '누적 1시간 집중했어요',            category: 'focus',  difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'focus_10h',    emoji: '⚡', title: '집중 수련자',     description: '누적 10시간 집중했어요',           category: 'focus',  difficulty: 'normal', xpReward: 100),
    Achievement(id: 'focus_50h',    emoji: '🔮', title: '집중 고수',       description: '누적 50시간 집중했어요',           category: 'focus',  difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'focus_100h',   emoji: '🧠', title: '집중 마스터',     description: '누적 100시간 집중했어요',          category: 'focus',  difficulty: 'legend', xpReward: 600),

    // ── 레벨 ──
    Achievement(id: 'level_5',      emoji: '🌱', title: '성장하는 모험가', description: '레벨 5를 달성했어요',              category: 'level',  difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'level_10',     emoji: '🌿', title: '베테랑 모험가',   description: '레벨 10을 달성했어요',             category: 'level',  difficulty: 'normal', xpReward: 100),
    Achievement(id: 'level_20',     emoji: '🌳', title: '전설의 모험가',   description: '레벨 20을 달성했어요',             category: 'level',  difficulty: 'legend', xpReward: 600),

    // ── 소셜 ──
    Achievement(id: 'friend_first', emoji: '🤝', title: '첫 친구',         description: '첫 번째 친구를 추가했어요',        category: 'social', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'diary_first',  emoji: '📔', title: '첫 기록',         description: '첫 번째 다이어리를 작성했어요',    category: 'social', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'diary_10',     emoji: '📖', title: '기록의 습관',     description: '다이어리를 10개 작성했어요',       category: 'social', difficulty: 'normal', xpReward: 100),
  ];

  static const difficultyLabel = {
    'easy':   '입문',
    'normal': '일반',
    'hard':   '고급',
    'legend': '전설',
  };

  static const difficultyColor = {
    'easy':   0xFF4CAF50,
    'normal': 0xFF2196F3,
    'hard':   0xFFf9a825,
    'legend': 0xFFe040fb,
  };

  static Achievement? findById(String id) {
    try { return all.firstWhere((a) => a.id == id); } catch (_) { return null; }
  }

  static List<Achievement> byCategory(String category) =>
      all.where((a) => a.category == category).toList();
}