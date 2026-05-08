class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final String category;   // goal | streak | focus | level | social
  final String difficulty; // easy | normal | hard | legend
  final int xpReward;
  final String skinReward;
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
    // 목표 (goal)
    Achievement(id: 'goal_first',    emoji: '🎯', title: '첫 걸음',          description: '첫 번째 목표를 완료했어요',          category: 'goal',   difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'goal_10',       emoji: '🏅', title: '목표 달인',         description: '목표를 10개 완료했어요',             category: 'goal',   difficulty: 'normal', xpReward: 100),
    Achievement(id: 'goal_50',       emoji: '🥈', title: '목표 고수',         description: '목표를 50개 완료했어요',             category: 'goal',   difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'goal_100',      emoji: '🥇', title: '목표 마스터',       description: '목표를 100개 완료했어요',            category: 'goal',   difficulty: 'legend', xpReward: 600),
    Achievement(id: 'goal_300',      emoji: '👑', title: '목표의 왕',         description: '목표를 300개 완료했어요',            category: 'goal',   difficulty: 'legend', xpReward: 600),
    Achievement(id: 'repeat_first',  emoji: '🔄', title: '꾸준함의 시작',     description: '반복 목표를 처음 전부 완료했어요',   category: 'goal',   difficulty: 'normal', xpReward: 100),
    Achievement(id: 'repeat_10',     emoji: '♾️', title: '반복의 달인',       description: '반복 목표를 10세트 완료했어요',      category: 'goal',   difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'short_goal_50', emoji: '⚡', title: '단기 집중러',       description: '단기 목표를 50개 완료했어요',        category: 'goal',   difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'long_goal_10',  emoji: '🏔️', title: '장기 전략가',       description: '장기 목표를 10개 완료했어요',        category: 'goal',   difficulty: 'hard',   xpReward: 300),

    // 스트릭 (streak)
    Achievement(id: 'streak_3',      emoji: '✨', title: '3일의 시작',        description: '3일 연속 출석했어요',                category: 'streak', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'streak_7',      emoji: '🔥', title: '7일의 불꽃',        description: '7일 연속 출석했어요',                category: 'streak', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'streak_14',     emoji: '🌙', title: '2주의 열정',        description: '14일 연속 출석했어요',               category: 'streak', difficulty: 'normal', xpReward: 100),
    Achievement(id: 'streak_30',     emoji: '🌕', title: '한 달의 여정',      description: '30일 연속 출석했어요',               category: 'streak', difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'streak_60',     emoji: '💫', title: '두 달의 의지',      description: '60일 연속 출석했어요',               category: 'streak', difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'streak_100',    emoji: '🌟', title: '100일의 기적',      description: '100일 연속 출석했어요',              category: 'streak', difficulty: 'legend', xpReward: 600),
    Achievement(id: 'streak_365',    emoji: '🏆', title: '1년의 전설',        description: '365일 연속 출석했어요',              category: 'streak', difficulty: 'legend', xpReward: 600),

    // 집중 (focus)
    Achievement(id: 'focus_1h',      emoji: '⏱️',  title: '집중 입문',         description: '누적 1시간 집중했어요',              category: 'focus',  difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'focus_5h',      emoji: '⚡',  title: '집중 훈련생',       description: '누적 5시간 집중했어요',              category: 'focus',  difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'focus_10h',     emoji: '🔮',  title: '집중 수련자',       description: '누적 10시간 집중했어요',             category: 'focus',  difficulty: 'normal', xpReward: 100),
    Achievement(id: 'focus_30h',     emoji: '🧘',  title: '집중 전문가',       description: '누적 30시간 집중했어요',             category: 'focus',  difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'focus_50h',     emoji: '🌊',  title: '집중 고수',         description: '누적 50시간 집중했어요',             category: 'focus',  difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'focus_100h',    emoji: '🧠',  title: '집중 마스터',       description: '누적 100시간 집중했어요',            category: 'focus',  difficulty: 'legend', xpReward: 600),
    Achievement(id: 'focus_200h',    emoji: '🌌',  title: '집중의 신',         description: '누적 200시간 집중했어요',            category: 'focus',  difficulty: 'legend', xpReward: 600),
    Achievement(id: 'focus_session_10',  emoji: '🧘‍♂', title: '집중 10회',      description: '집중 세션을 10회 완료했어요',        category: 'focus',  difficulty: 'normal', xpReward: 100),
    Achievement(id: 'focus_session_50',  emoji: '🎪', title: '집중 50회',      description: '집중 세션을 50회 완료했어요',        category: 'focus',  difficulty: 'hard',   xpReward: 300),

    // 레벨 (level)
    Achievement(id: 'level_5',       emoji: '🌱', title: '성장의 시작',       description: '레벨 5를 달성했어요',                category: 'level',  difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'level_10',      emoji: '🌿', title: '베테랑 모험가',     description: '레벨 10을 달성했어요',               category: 'level',  difficulty: 'normal', xpReward: 100),
    Achievement(id: 'level_20',      emoji: '🌳', title: '탐험가의 길',       description: '레벨 20을 달성했어요',               category: 'level',  difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'level_30',      emoji: '🦅', title: '영웅의 탄생',       description: '레벨 30을 달성했어요',               category: 'level',  difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'level_50',      emoji: '💎', title: '전설의 입문',       description: '레벨 50을 달성했어요',               category: 'level',  difficulty: 'legend', xpReward: 600),
    Achievement(id: 'level_75',      emoji: '🌠', title: '신화에 가까운 자',  description: '레벨 75를 달성했어요',               category: 'level',  difficulty: 'legend', xpReward: 600),
    Achievement(id: 'level_100',     emoji: '👑', title: '불멸의 존재',       description: '레벨 100을 달성했어요',              category: 'level',  difficulty: 'legend', xpReward: 600),

    // 소셜 (social)
    Achievement(id: 'friend_first',  emoji: '🤝', title: '첫 친구',           description: '첫 번째 친구를 추가했어요',          category: 'social', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'friend_5',      emoji: '👥', title: '인기쟁이',          description: '친구를 5명 추가했어요',              category: 'social', difficulty: 'normal', xpReward: 100),
    Achievement(id: 'friend_10',     emoji: '🌐', title: '소셜 고수',         description: '친구를 10명 추가했어요',             category: 'social', difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'diary_first',   emoji: '📔', title: '첫 기록',           description: '첫 번째 게시글을 작성했어요',        category: 'social', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'diary_10',      emoji: '📖', title: '기록의 습관',       description: '게시글을 10개 작성했어요',           category: 'social', difficulty: 'normal', xpReward: 100),
    Achievement(id: 'diary_50',      emoji: '📚', title: '이야기꾼',          description: '게시글을 50개 작성했어요',           category: 'social', difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'chat_first',    emoji: '💬', title: '첫 대화',           description: '처음으로 채팅을 시작했어요',         category: 'social', difficulty: 'easy',   xpReward: 50),
    Achievement(id: 'ranking_top3',  emoji: '🥉', title: '랭킹 3위',          description: '집중 시간 랭킹 3위 안에 들었어요',  category: 'social', difficulty: 'hard',   xpReward: 300),
    Achievement(id: 'ranking_top1',  emoji: '🥇', title: '랭킹 1위',          description: '집중 시간 랭킹 1위를 달성했어요',   category: 'social', difficulty: 'legend', xpReward: 600),
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