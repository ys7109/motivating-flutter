import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../utils/transitions.dart';
import '../../providers/app_provider.dart';
import '../../models/achievement_definitions.dart';
import '../../services/firestore_service.dart';
import 'mailbox_screen.dart';
import 'settings_screen.dart';
import 'focus_stats_screen.dart';

const _achieveSkinDefs = <Map<String, String>>[
  // 목표
  {'id': 'goal_first',    'emoji': '🎯', 'unlock': "'첫 걸음' 업적 달성 시 해금"},
  {'id': 'goal_10',       'emoji': '🏅', 'unlock': "'목표 달인' 업적 달성 시 해금"},
  {'id': 'goal_50',       'emoji': '🥈', 'unlock': "'목표 고수' 업적 달성 시 해금"},
  {'id': 'goal_100',      'emoji': '🥇', 'unlock': "'목표 마스터' 업적 달성 시 해금"},
  {'id': 'goal_300',      'emoji': '👑', 'unlock': "'목표의 왕' 업적 달성 시 해금"},
  {'id': 'repeat_first',  'emoji': '🔄', 'unlock': "'꾸준함의 시작' 업적 달성 시 해금"},
  {'id': 'repeat_10',     'emoji': '♾️', 'unlock': "'반복의 달인' 업적 달성 시 해금"},
  {'id': 'short_goal_50', 'emoji': '⚡', 'unlock': "'단기 집중러' 업적 달성 시 해금"},
  {'id': 'long_goal_10',  'emoji': '🏔️', 'unlock': "'장기 전략가' 업적 달성 시 해금"},
  // 스트릭
  {'id': 'streak_3',      'emoji': '✨', 'unlock': "'3일의 시작' 업적 달성 시 해금"},
  {'id': 'streak_7',      'emoji': '🔥', 'unlock': "'7일의 불꽃' 업적 달성 시 해금"},
  {'id': 'streak_14',     'emoji': '🌙', 'unlock': "'2주의 열정' 업적 달성 시 해금"},
  {'id': 'streak_30',     'emoji': '🌕', 'unlock': "'한 달의 여정' 업적 달성 시 해금"},
  {'id': 'streak_60',     'emoji': '💫', 'unlock': "'두 달의 의지' 업적 달성 시 해금"},
  {'id': 'streak_100',    'emoji': '🌟', 'unlock': "'100일의 기적' 업적 달성 시 해금"},
  {'id': 'streak_365',    'emoji': '🏆', 'unlock': "'1년의 전설' 업적 달성 시 해금"},
  // 집중
  {'id': 'focus_1h',      'emoji': '⏱️',  'unlock': "'집중 입문' 업적 달성 시 해금"},
  {'id': 'focus_5h',      'emoji': '⚡',  'unlock': "'집중 훈련생' 업적 달성 시 해금"},
  {'id': 'focus_10h',     'emoji': '🔮',  'unlock': "'집중 수련자' 업적 달성 시 해금"},
  {'id': 'focus_30h',     'emoji': '🧘',  'unlock': "'집중 전문가' 업적 달성 시 해금"},
  {'id': 'focus_50h',     'emoji': '🌊',  'unlock': "'집중 고수' 업적 달성 시 해금"},
  {'id': 'focus_100h',    'emoji': '🧠',  'unlock': "'집중 마스터' 업적 달성 시 해금"},
  {'id': 'focus_200h',    'emoji': '🌌',  'unlock': "'집중의 신' 업적 달성 시 해금"},
  {'id': 'focus_session_10', 'emoji': '🎯', 'unlock': "'집중 10회' 업적 달성 시 해금"},
  {'id': 'focus_session_50', 'emoji': '🎪', 'unlock': "'집중 50회' 업적 달성 시 해금"},
  // 레벨
  {'id': 'level_5',       'emoji': '🌱', 'unlock': "'성장의 시작' 업적 달성 시 해금"},
  {'id': 'level_10',      'emoji': '🌿', 'unlock': "'베테랑 모험가' 업적 달성 시 해금"},
  {'id': 'level_20',      'emoji': '🌳', 'unlock': "'탐험가의 길' 업적 달성 시 해금"},
  {'id': 'level_30',      'emoji': '🦅', 'unlock': "'영웅의 탄생' 업적 달성 시 해금"},
  {'id': 'level_50',      'emoji': '💎', 'unlock': "'전설의 입문' 업적 달성 시 해금"},
  {'id': 'level_75',      'emoji': '🌠', 'unlock': "'신화에 가까운 자' 업적 달성 시 해금"},
  {'id': 'level_100',     'emoji': '👑', 'unlock': "'불멸의 존재' 업적 달성 시 해금"},
  // 소셜
  {'id': 'friend_first',  'emoji': '🤝', 'unlock': "'첫 친구' 업적 달성 시 해금"},
  {'id': 'friend_5',      'emoji': '👥', 'unlock': "'인기쟁이' 업적 달성 시 해금"},
  {'id': 'friend_10',     'emoji': '🌐', 'unlock': "'소셜 고수' 업적 달성 시 해금"},
  {'id': 'diary_first',   'emoji': '📔', 'unlock': "'첫 기록' 업적 달성 시 해금"},
  {'id': 'diary_10',      'emoji': '📖', 'unlock': "'기록의 습관' 업적 달성 시 해금"},
  {'id': 'diary_50',      'emoji': '📚', 'unlock': "'이야기꾼' 업적 달성 시 해금"},
  {'id': 'chat_first',    'emoji': '💬', 'unlock': "'첫 대화' 업적 달성 시 해금"},
  {'id': 'ranking_top3',  'emoji': '🥉', 'unlock': "'랭킹 3위' 업적 달성 시 해금"},
  {'id': 'ranking_top1',  'emoji': '🥇', 'unlock': "'랭킹 1위' 업적 달성 시 해금"},
];

const _levelSkins = [
  {'id': 'default',  'label': '기본',   'emoji': '👤', 'lv': 1,  'unlock': '기본 제공'},
  {'id': 'warrior',  'label': '전사',   'emoji': '⚔️', 'lv': 3,  'unlock': 'Lv.3 달성 시 해금'},
  {'id': 'scholar',  'label': '학자',   'emoji': '📚', 'lv': 6,  'unlock': 'Lv.6 달성 시 해금'},
  {'id': 'explorer', 'label': '탐험가', 'emoji': '🧭', 'lv': 10, 'unlock': 'Lv.10 달성 시 해금'},
  {'id': 'legend',   'label': '전설',   'emoji': '🌟', 'lv': 20, 'unlock': 'Lv.20 달성 시 해금'},
];
const _badges = [
  {'id': 'none',      'label': '없음',   'emoji': '—',  'lv': 1},
  {'id': 'flame',     'label': '열정',   'emoji': '🔥', 'lv': 2},
  {'id': 'lightning', 'label': '집중',   'emoji': '⚡', 'lv': 5},
  {'id': 'crown',     'label': '왕관',   'emoji': '👑', 'lv': 12},
  {'id': 'diamond',   'label': '다이아', 'emoji': '💎', 'lv': 18},
];
const _frames = [
  {'id': 'none',    'label': '없음',   'lv': 1},
  {'id': 'silver',  'label': '실버',   'lv': 4},
  {'id': 'gold',    'label': '골드',   'lv': 8},
  {'id': 'rainbow', 'label': '무지개', 'lv': 15},
];
const _roadmap = [
  {'lv': 3,  'reward': '전사 스킨 해금'},
  {'lv': 5,  'reward': '⚡ 집중 뱃지 해금'},
  {'lv': 8,  'reward': '🥈 실버 프레임 해금'},
  {'lv': 10, 'reward': '탐험가 스킨 해금'},
  {'lv': 12, 'reward': '👑 왕관 뱃지 해금'},
  {'lv': 15, 'reward': '🌈 무지개 프레임 해금'},
  {'lv': 20, 'reward': '🌟 전설 스킨 해금'},
];
const _achieveCategories = [
  {'id': 'goal',   'label': '목표',      'emoji': '🎯'},
  {'id': 'streak', 'label': '연속 출석', 'emoji': '🔥'},
  {'id': 'focus',  'label': '집중',      'emoji': '⏱'},
  {'id': 'level',  'label': '레벨',      'emoji': '⭐'},
  {'id': 'social', 'label': '소셜',      'emoji': '👥'},
];

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _editName = false;
  late TextEditingController _nameCtrl;
  bool _nameSaving = false;
  String _characterTab = 'skin';
  String _achieveCategory = 'goal';
  Map<String, double> _globalStats = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _nameCtrl = TextEditingController();
    _loadGlobalStats();
  }

  @override
  void dispose() { _tabCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadGlobalStats() async {
    final stats = await FirestoreService().getAchievementStats();
    if (mounted) setState(() => _globalStats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    if (userData == null) return const SizedBox();

    final level = userData.level;
    final character = userData.character;
    final activeSkin = character.skin;
    final activeBadge = character.badge;
    final currentSkin = _levelSkins.any((s) => s['id'] == activeSkin)
        ? _levelSkins.firstWhere((s) => s['id'] == activeSkin)
        : (_achieveSkinDefs.any((s) => s['id'] == activeSkin)
            ? _achieveSkinDefs.firstWhere((s) => s['id'] == activeSkin)
            : _levelSkins[0]);
    final currentBadge = _badges.firstWhere((b) => b['id'] == activeBadge, orElse: () => _badges[0]);
    final achievements = userData.achievements;
    final achieveCount = achievements.length;
    final achieveTotal = Achievements.all.length;
    final equippedId = userData.equippedAchievement;
    final equippedAchievement = equippedId != null ? Achievements.findById(equippedId) : null;
    final unlockedAchieveSkins = app.unlockedAchieveSkins;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('마이', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
              Row(children: [
                _IconBtn(
                  onTap: () => Navigator.push(context, SlideRightRoute(page: const SettingsScreen())),
                  child: Icon(Icons.settings_outlined, size: 18, color: context.textSecondary),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          _buildAvatar(context, character, currentSkin, currentBadge),
          const SizedBox(height: 10),
          if (_editName)
            _buildNameEdit(context, app)
          else
            Column(children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${userData.name.split(' ').first} 님',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: context.textPrimary)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () { _nameCtrl.text = userData.name; setState(() => _editName = true); },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: context.subtleBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Icon(Icons.edit_rounded, size: 14, color: context.textSecondary),
                  ),
                ),
              ]),
              if (equippedAchievement != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(Achievements.difficultyColor[equippedAchievement.difficulty]!)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: Color(Achievements.difficultyColor[equippedAchievement.difficulty]!)
                            .withOpacity(0.4)),
                  ),
                  child: Text(equippedAchievement.title,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: Color(
                              Achievements.difficultyColor[equippedAchievement.difficulty]!))),
                ),
              ],
            ]),
          const SizedBox(height: 4),
          Text('Lv.$level · ${AppProvider.levelTitle(level)}',
              style: TextStyle(fontSize: 13, color: context.textSecondary)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(color: context.subtleBg,
                  borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabCtrl,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(color: context.primaryColor,
                    borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: context.isDark ? Colors.black : Colors.white,
                unselectedLabelColor: context.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                padding: const EdgeInsets.all(3),
                tabs: [
                  Tab(text: '업적 $achieveCount/$achieveTotal'),
                  const Tab(text: '통계'),
                  const Tab(text: '캐릭터'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _AchievementsTab(
                  achievements: achievements,
                  claimedAchievements: userData.claimedAchievements,
                  equippedAchievement: equippedId,
                  achieveCategory: _achieveCategory,
                  onCategoryChanged: (c) => setState(() => _achieveCategory = c),
                  achieveCount: achieveCount,
                  achieveTotal: achieveTotal,
                  globalStats: _globalStats,
                  achievementUnlockedAt: userData.achievementUnlockedAt,
                  onClaim: (id) => app.claimAchievementReward(id),
                  onEquip: (id) => app.equipAchievement(id),
                  onUnequip: () => app.equipAchievement(null),
                ),
                _StatsTab(userData: userData, onGoToFocusStats: () {
                  Navigator.push(context, SlideRightRoute(page: FocusStatsScreen()));
                }),
                _CharacterTab(
                  level: level,
                  character: character,
                  characterTab: _characterTab,
                  onCharacterTabChanged: (t) => setState(() => _characterTab = t),
                  onUpdateCharacter: (updates) => app.updateCharacter(updates),
                  unlockedAchieveSkins: unlockedAchieveSkins,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, dynamic character,
      dynamic currentSkin, dynamic currentBadge) {
    final skinEmoji = currentSkin['emoji'] as String? ?? '🧑';
    Widget inner = Container(
      width: 82, height: 82,
      decoration: BoxDecoration(shape: BoxShape.circle, color: context.surfaceColor),
      child: Center(child: Text(skinEmoji, style: const TextStyle(fontSize: 40))),
    );
    Widget frame;
    if (character.frame == 'none') {
      frame = Container(width: 90, height: 90,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.subtleBg),
          child: Center(child: inner));
    } else if (character.frame == 'rainbow') {
      frame = _RainbowFrame(child: inner);
    } else {
      final color = character.frame == 'silver'
          ? const Color(0xFF9e9e9e) : const Color(0xFFf9a825);
      frame = Container(width: 90, height: 90,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Center(child: inner));
    }
    return Stack(children: [
      frame,
      if (character.badge != 'none')
        Positioned(bottom: 2, right: 2, child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.surfaceColor,
              border: Border.all(color: context.borderColor)),
          child: Center(child: Text(currentBadge['emoji'] as String,
              style: const TextStyle(fontSize: 14))),
        )),
    ]);
  }

  Widget _buildNameEdit(BuildContext context, AppProvider app) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 140,
        child: TextField(
          controller: _nameCtrl, maxLength: 12, autofocus: true, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary),
          decoration: InputDecoration(counterText: '', isDense: true,
              border: const UnderlineInputBorder(),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.primaryColor))),
          onSubmitted: (_) => _saveName(app),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _nameSaving ? null : () => _saveName(app),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: context.primaryColor,
              borderRadius: BorderRadius.circular(99)),
          child: Text(_nameSaving ? '...' : '저장',
              style: TextStyle(color: context.isDark ? Colors.black : Colors.white,
                  fontSize: 12)),
        ),
      ),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: () => setState(() => _editName = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: context.subtleBg,
              borderRadius: BorderRadius.circular(99)),
          child: Text('취소', style: TextStyle(color: context.textSecondary, fontSize: 12)),
        ),
      ),
    ]);
  }

  Future<void> _saveName(AppProvider app) async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _nameSaving = true);
    await app.updateName(_nameCtrl.text.trim());
    if (mounted) setState(() { _nameSaving = false; _editName = false; });
  }
}

class _RainbowFrame extends StatefulWidget {
  final Widget child;
  const _RainbowFrame({required this.child});
  @override
  State<_RainbowFrame> createState() => _RainbowFrameState();
}
class _RainbowFrameState extends State<_RainbowFrame> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, child) => CustomPaint(painter: _RainbowPainter(_anim.value), child: child),
    child: SizedBox(width: 90, height: 90, child: Center(child: widget.child)),
  );
}
class _RainbowPainter extends CustomPainter {
  final double progress;
  _RainbowPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * 2 * pi);
    canvas.translate(-center.dx, -center.dy);
    const gradient = SweepGradient(colors: [
      Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFD700),
      Color(0xFF00CC00), Color(0xFF0000FF), Color(0xFF8B00FF), Color(0xFFFF0000),
    ]);
    final paint = Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 4 ..strokeCap = StrokeCap.butt
      ..shader = gradient.createShader(rect);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }
  @override
  bool shouldRepaint(_RainbowPainter old) => old.progress != progress;
}

class _AchievementsTab extends StatelessWidget {
  final Set<String> achievements;
  final Set<String> claimedAchievements;
  final String? equippedAchievement;
  final String achieveCategory;
  final ValueChanged<String> onCategoryChanged;
  final int achieveCount, achieveTotal;
  final Map<String, double> globalStats;
  final Map<String, DateTime> achievementUnlockedAt;
  final Future<void> Function(String) onClaim;
  final Future<void> Function(String) onEquip;
  final Future<void> Function() onUnequip;
  const _AchievementsTab({
    required this.achievements, required this.claimedAchievements,
    required this.equippedAchievement, required this.achieveCategory,
    required this.onCategoryChanged, required this.achieveCount,
    required this.achieveTotal, required this.globalStats,
    required this.achievementUnlockedAt,
    required this.onClaim, required this.onEquip, required this.onUnequip,
  });

  @override
  Widget build(BuildContext context) {
    final achieveList = Achievements.byCategory(achieveCategory);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('전체 달성', style: TextStyle(fontSize: 13, color: context.textSecondary)),
          Text('$achieveCount / $achieveTotal', style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w500, color: context.textPrimary)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: achieveTotal > 0 ? achieveCount / achieveTotal : 0,
            minHeight: 6, backgroundColor: context.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _achieveCategories.map((cat) {
            final isSelected = achieveCategory == cat['id'];
            final catList = Achievements.byCategory(cat['id'] as String);
            final catDone = catList.where((a) => achievements.contains(a.id)).length;
            return GestureDetector(
              onTap: () => onCategoryChanged(cat['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? context.primaryColor : context.subtleBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('${cat['emoji']} ${cat['label']} $catDone/${catList.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: isSelected
                            ? (context.isDark ? Colors.black : Colors.white)
                            : context.textSecondary)),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 12),
        ...achieveList.map((a) {
          final unlocked = achievements.contains(a.id);
          final claimed = claimedAchievements.contains(a.id);
          final isEquipped = equippedAchievement == a.id;
          final pct = globalStats[a.id];
          final diffColor = Color(Achievements.difficultyColor[a.difficulty]!);
          final unlockedAt = achievementUnlockedAt[a.id];
          return GestureDetector(
            onTap: () => _showDetail(context, a, unlocked, claimed, isEquipped, unlockedAt),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: unlocked ? 1.0 : 0.4,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: unlocked ? context.surfaceColor : context.subtleBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isEquipped ? diffColor
                        : unlocked ? diffColor.withOpacity(0.3) : context.borderColor,
                    width: isEquipped ? 2 : unlocked ? 1.5 : 0.5,
                  ),
                ),
                child: Row(children: [
                  Text(unlocked ? a.emoji : '🔒', style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(a.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: context.textPrimary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: diffColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(99)),
                        child: Text(Achievements.difficultyLabel[a.difficulty]!,
                            style: TextStyle(fontSize: 10, color: diffColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Expanded(child: Text(a.description,
                          style: TextStyle(fontSize: 12, color: context.textSecondary))),
                      if (pct != null)
                        Text('${pct.toStringAsFixed(1)}% 달성',
                            style: TextStyle(fontSize: 10, color: context.textSecondary)),
                    ]),
                  ])),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (unlocked && !claimed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: context.primaryColor,
                            borderRadius: BorderRadius.circular(99)),
                        child: Text('보상', style: TextStyle(fontSize: 11,
                            color: context.isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w600)),
                      )
                    else if (claimed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1b8a5a).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(99)),
                        child: const Text('달성', style: TextStyle(fontSize: 11,
                            color: Color(0xFF1b8a5a), fontWeight: FontWeight.w600)),
                      ),
                    if (isEquipped) ...[
                      const SizedBox(height: 4),
                      Text('장착 중', style: TextStyle(fontSize: 10, color: diffColor)),
                    ],
                  ]),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showDetail(BuildContext context, Achievement a, bool unlocked,
      bool claimed, bool isEquipped, DateTime? unlockedAt) {
    final diffColor = Color(Achievements.difficultyColor[a.difficulty]!);
    final skinDef = _achieveSkinDefs.firstWhere(
        (s) => s['id'] == a.id, orElse: () => {'emoji': a.emoji});
    final skinEmoji = skinDef['emoji'] ?? a.emoji;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // builder 안에서 padding 계산 — 시스템 바 정확히 반영
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(unlocked ? a.emoji : '🔒', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(a.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: ctx.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: diffColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(99)),
                child: Text(Achievements.difficultyLabel[a.difficulty]!,
                    style: TextStyle(fontSize: 11, color: diffColor,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(a.description,
                style: TextStyle(fontSize: 14, color: ctx.textSecondary)),
            if (unlocked && unlockedAt != null) ...[
              const SizedBox(height: 4),
              Text('달성: ${_fmtDate(unlockedAt)}',
                  style: TextStyle(fontSize: 12, color: ctx.textSecondary)),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ctx.subtleBg,
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('보상', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: ctx.textPrimary)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _RewardChip(emoji: '✨', label: '+${a.xpReward} XP'),
                  _RewardChip(emoji: skinEmoji!, label: '전용 스킨'),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            // 버튼 — bottomPad로 시스템 바 가림 방지
            if (unlocked && !claimed)
              _FullBtn(
                label: '🎁 보상 수령하기', color: ctx.primaryColor,
                textColor: ctx.isDark ? Colors.black : Colors.white,
                onTap: () async { Navigator.pop(ctx); await onClaim(a.id); },
              )
            else if (claimed && !isEquipped)
              _FullBtn(
                label: '🏅 칭호 장착하기',
                color: diffColor.withOpacity(0.15), textColor: diffColor,
                onTap: () async { Navigator.pop(ctx); await onEquip(a.id); },
              )
            else if (isEquipped)
              _FullBtn(
                label: '칭호 해제', color: ctx.subtleBg,
                textColor: ctx.textSecondary,
                onTap: () async { Navigator.pop(ctx); await onUnequip(); },
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: ctx.subtleBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('업적을 달성하면 보상을 수령할 수 있어요',
                    style: TextStyle(fontSize: 13, color: ctx.textSecondary))),
              ),
          ]),
        );
      },
    );
  }
}

String _fmtDate(DateTime dt) =>
    '${dt.year}.${dt.month.toString().padLeft(2,'0')}.${dt.day.toString().padLeft(2,'0')}';

class _RewardChip extends StatelessWidget {
  final String emoji, label;
  const _RewardChip({required this.emoji, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 28)),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: context.textPrimary)),
  ]);
}

class _FullBtn extends StatelessWidget {
  final String label;
  final Color color, textColor;
  final VoidCallback onTap;
  const _FullBtn({required this.label, required this.color,
      required this.textColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(label, style: TextStyle(fontSize: 15,
          fontWeight: FontWeight.w600, color: textColor))),
    ),
  );
}

class _StatsTab extends StatelessWidget {
  final dynamic userData;
  final VoidCallback onGoToFocusStats;
  const _StatsTab({required this.userData, required this.onGoToFocusStats});
  @override
  Widget build(BuildContext context) {
    final focusHours = (userData.totalFocusMin / 60).floor();
    final focusMins = userData.totalFocusMin % 60;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        GestureDetector(
          onTap: onGoToFocusStats,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor, width: 0.5)),
            child: Row(children: [
              const Text('⏱', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('집중 통계', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
                const SizedBox(height: 2),
                Text('누적 ${focusHours}시간 ${focusMins}분',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ])),
              Icon(Icons.chevron_right, color: context.textSecondary, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor, width: 0.5)),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('연속 출석 일수', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
              const SizedBox(height: 2),
              Text('현재 ${userData.streak}일 · 최고 ${userData.maxStreak}일',
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Text('레벨 보상 로드맵', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
            color: context.textPrimary)),
        const SizedBox(height: 10),
        ..._roadmap.map((r) {
          final lv = r['lv'] as int;
          final unlocked = userData.level >= lv;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: unlocked ? 1.0 : 0.5,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor, width: 0.5)),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: unlocked ? context.primaryColor : context.subtleBg),
                  child: Center(child: unlocked
                      ? Icon(Icons.check,
                          color: context.isDark ? Colors.black : Colors.white, size: 14)
                      : Text('$lv', style: TextStyle(fontSize: 11,
                          color: context.textSecondary, fontWeight: FontWeight.w500))),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['reward'] as String, style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500, color: context.textPrimary)),
                  Text('레벨 $lv 달성 시',
                      style: TextStyle(fontSize: 11, color: context.textSecondary)),
                ]),
                if (unlocked) ...[
                  const Spacer(),
                  const Text('해금됨', style: TextStyle(fontSize: 12,
                      color: Color(0xFF1b8a5a), fontWeight: FontWeight.w500)),
                ],
              ]),
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CharacterTab extends StatelessWidget {
  final int level;
  final dynamic character;
  final String characterTab;
  final ValueChanged<String> onCharacterTabChanged;
  final ValueChanged<Map<String, dynamic>> onUpdateCharacter;
  final List<String> unlockedAchieveSkins;
  const _CharacterTab({
    required this.level, required this.character,
    required this.characterTab, required this.onCharacterTabChanged,
    required this.onUpdateCharacter, required this.unlockedAchieveSkins,
  });

  @override
  Widget build(BuildContext context) {
    final activeId = characterTab == 'skin' ? character.skin
        : characterTab == 'badge' ? character.badge
        : character.frame;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Row(children: ['skin', 'badge', 'frame'].asMap().entries.map((e) {
          final labels = ['스킨', '뱃지', '프레임'];
          final isActive = characterTab == e.value;
          return GestureDetector(
            onTap: () => onCharacterTabChanged(e.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? context.primaryColor : context.subtleBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(labels[e.key], style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? (context.isDark ? Colors.black : Colors.white)
                      : context.textSecondary)),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),

        if (characterTab == 'skin') ...[
          Text('레벨 스킨', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: context.textSecondary)),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: _levelSkins.map((item) {
              final unlocked = level >= (item['lv'] as int);
              final isActive = activeId == item['id'];
              return GestureDetector(
                onTap: () { if (unlocked) onUpdateCharacter({'skin': item['id']}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isActive ? context.primaryColor
                        : unlocked ? context.surfaceColor : context.subtleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isActive ? context.primaryColor : context.borderColor,
                        width: isActive ? 2 : 1),
                  ),
                  child: Opacity(
                    opacity: unlocked ? 1.0 : 0.5,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(item['emoji'] as String, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(item['label'] as String, style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? (context.isDark ? Colors.black : Colors.white)
                              : context.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        unlocked ? (isActive ? '착용 중' : '') : item['unlock'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9,
                            color: isActive
                                ? (context.isDark ? Colors.black54 : Colors.white70)
                                : context.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('업적 스킨', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: context.textSecondary)),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: _achieveSkinDefs.map((item) {
              final skinId = item['id']!;
              final unlocked = unlockedAchieveSkins.contains(skinId);
              final isActive = activeId == skinId;
              final achieveName = Achievements.findById(skinId)?.title ?? skinId;
              return GestureDetector(
                onTap: () { if (unlocked) onUpdateCharacter({'skin': skinId}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isActive ? context.primaryColor
                        : unlocked ? context.surfaceColor : context.subtleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isActive ? context.primaryColor : context.borderColor,
                        width: isActive ? 2 : 1),
                  ),
                  child: Opacity(
                    opacity: unlocked ? 1.0 : 0.4,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(unlocked ? item['emoji']! : '🔒',
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(achieveName, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                              color: isActive
                                  ? (context.isDark ? Colors.black : Colors.white)
                                  : context.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        unlocked ? (isActive ? '착용 중' : '') : item['unlock']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9,
                            color: isActive
                                ? (context.isDark ? Colors.black54 : Colors.white70)
                                : context.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),

        ] else if (characterTab == 'badge') ...[
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: _badges.map((item) {
              final unlocked = level >= (item['lv'] as int);
              final isActive = activeId == item['id'];
              return GestureDetector(
                onTap: () { if (unlocked) onUpdateCharacter({'badge': item['id']}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isActive ? context.primaryColor
                        : unlocked ? context.surfaceColor : context.subtleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isActive ? context.primaryColor : context.borderColor,
                        width: isActive ? 2 : 1),
                  ),
                  child: Opacity(
                    opacity: unlocked ? 1.0 : 0.5,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(item['emoji'] as String, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 6),
                      Text(item['label'] as String, style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? (context.isDark ? Colors.black : Colors.white)
                              : context.textPrimary)),
                      if (!unlocked)
                        Text('Lv.${item['lv']}',
                            style: TextStyle(fontSize: 10, color: context.textSecondary))
                      else if (isActive)
                        Text('착용 중', style: TextStyle(fontSize: 10,
                            color: context.isDark ? Colors.black54 : Colors.white70)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),

        ] else if (characterTab == 'frame') ...[
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: _frames.map((item) {
              final unlocked = level >= (item['lv'] as int);
              final isActive = activeId == item['id'];
              return GestureDetector(
                onTap: () { if (unlocked) onUpdateCharacter({'frame': item['id']}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isActive ? context.primaryColor
                        : unlocked ? context.surfaceColor : context.subtleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isActive ? context.primaryColor : context.borderColor,
                        width: isActive ? 2 : 1),
                  ),
                  child: Opacity(
                    opacity: unlocked ? 1.0 : 0.5,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (item['id'] == 'rainbow')
                        SizedBox(width: 34, height: 34,
                            child: CustomPaint(painter: _RainbowCirclePainter()))
                      else if (item['id'] == 'none')
                        Container(width: 34, height: 34,
                            decoration: BoxDecoration(shape: BoxShape.circle,
                                border: Border.all(color: context.borderColor, width: 2)))
                      else
                        Container(width: 34, height: 34, decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item['id'] == 'silver'
                                ? const Color(0xFF9e9e9e) : const Color(0xFFf9a825))),
                      const SizedBox(height: 6),
                      Text(item['label'] as String, style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? (context.isDark ? Colors.black : Colors.white)
                              : context.textPrimary)),
                      if (!unlocked)
                        Text('Lv.${item['lv']}',
                            style: TextStyle(fontSize: 10, color: context.textSecondary))
                      else if (isActive)
                        Text('착용 중', style: TextStyle(fontSize: 10,
                            color: context.isDark ? Colors.black54 : Colors.white70)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RainbowCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const gradient = SweepGradient(colors: [
      Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFD700),
      Color(0xFF00CC00), Color(0xFF0000FF), Color(0xFF8B00FF), Color(0xFFFF0000),
    ]);
    final paint = Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 4 ..strokeCap = StrokeCap.butt
      ..shader = gradient.createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _IconBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _IconBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: context.borderColor),
          borderRadius: BorderRadius.circular(99)),
      child: child,
    ),
  );
}