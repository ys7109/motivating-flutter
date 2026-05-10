import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../models/achievement_definitions.dart';

const kSkins = [
  {'id': 'default',  'emoji': '👤'},
  {'id': 'warrior',  'emoji': '⚔️'},
  {'id': 'scholar',  'emoji': '📚'},
  {'id': 'explorer', 'emoji': '🧭'},
  {'id': 'legend',   'emoji': '🌟'},
];
const kBadges = [
  {'id': 'none',      'emoji': ''},
  {'id': 'flame',     'emoji': '🔥'},
  {'id': 'lightning', 'emoji': '⚡'},
  {'id': 'crown',     'emoji': '👑'},
  {'id': 'diamond',   'emoji': '💎'},
];
const kFrames = [
  {'id': 'none',    'color': 0x00000000},
  {'id': 'silver',  'color': 0xFF9e9e9e},
  {'id': 'gold',    'color': 0xFFf9a825},
  {'id': 'rainbow', 'color': 0xFFe040fb},
];

// 업적 전용 스킨 이모지 맵 — achievement_definitions.dart와 동기화
const kAchieveSkins = <String, String>{
  // 목표
  'goal_first':    '🎯', 'goal_10':       '🏅', 'goal_50':       '🥈',
  'goal_100':      '🥇', 'goal_300':      '👑', 'repeat_first':  '🔄',
  'repeat_10':     '♾️', 'short_goal_50': '⚡', 'long_goal_10':  '🏔️',
  // 스트릭
  'streak_3':      '✨', 'streak_7':      '🔥', 'streak_14':     '🌙',
  'streak_30':     '🌕', 'streak_60':     '💫', 'streak_100':    '🌟',
  'streak_365':    '🏆',
  // 집중
  'focus_1h':      '⏱️', 'focus_5h':      '⚡', 'focus_10h':     '🔮',
  'focus_30h':     '🧘', 'focus_50h':     '🌊', 'focus_100h':    '🧠',
  'focus_200h':    '🌌', 'focus_session_10': '🎯', 'focus_session_50': '🎪',
  // 레벨
  'level_5':       '🌱', 'level_10':      '🌿', 'level_20':      '🌳',
  'level_30':      '🦅', 'level_50':      '💎', 'level_75':      '🌠',
  'level_100':     '👑',
  // 소셜
  'friend_first':  '🤝', 'friend_5':      '👥', 'friend_10':     '🌐',
  'diary_first':   '📔', 'diary_10':      '📖', 'diary_50':      '📚',
  'chat_first':    '💬', 'ranking_top3':  '🥉', 'ranking_top1':  '🥇',
};

String skinEmoji(String? skin) {
  if (skin == null) return '👤';
  // 업적 스킨 먼저 확인
  if (kAchieveSkins.containsKey(skin)) return kAchieveSkins[skin]!;
  return (kSkins.firstWhere((s) => s['id'] == skin, orElse: () => kSkins[0])['emoji'] as String?) ?? '👤';
}

String badgeEmoji(String? badge) =>
    (kBadges.firstWhere((b) => b['id'] == badge, orElse: () => kBadges[0])['emoji'] as String?) ?? '';

bool isRainbowFrame(String? frame) => frame == 'rainbow';

Color? frameColor(String? frame) {
  if (frame == null || frame == 'none' || frame == 'rainbow') return null;
  final f = kFrames.firstWhere((f) => f['id'] == frame, orElse: () => kFrames[0]);
  final c = f['color'] as int;
  return c == 0 ? null : Color(c);
}

const _rainbowColors = [
  Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFD700),
  Color(0xFF00CC00), Color(0xFF0000FF), Color(0xFF8B00FF),
];

class CharacterAvatar extends StatelessWidget {
  final Map<String, dynamic>? character;
  final double size;
  /// 업적 칭호 ID (있으면 아바타 아래에 칭호 표시)
  final String? equippedAchievement;
  final bool showTitle;

  const CharacterAvatar({
    super.key,
    this.character,
    this.size = 40,
    this.equippedAchievement,
    this.showTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final skin = character?['skin'] as String?;
    final badge = character?['badge'] as String?;
    final frame = character?['frame'] as String?;
    final fc = frameColor(frame);
    final isRainbow = isRainbowFrame(frame);
    final se = skinEmoji(skin);
    final be = badgeEmoji(badge);
    final innerSize = size * 0.88;

    final achievement = equippedAchievement != null
        ? Achievements.findById(equippedAchievement!)
        : null;

    Widget avatar = Stack(clipBehavior: Clip.none, children: [
      // 프레임
      if (isRainbow)
        _RainbowFrameAvatar(size: size, innerSize: innerSize, skinEmoji: se)
      else
        Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fc ?? context.subtleBg),
          child: Center(
            child: Container(
              width: innerSize, height: innerSize,
              decoration: BoxDecoration(shape: BoxShape.circle, color: context.surfaceColor),
              child: Center(child: Text(se, style: TextStyle(fontSize: size * 0.42))),
            ),
          ),
        ),
      // 뱃지
      if (be.isNotEmpty)
        Positioned(
          bottom: -2, right: -2,
          child: Container(
            width: size * 0.38, height: size * 0.38,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: context.surfaceColor,
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Center(child: Text(be, style: TextStyle(fontSize: size * 0.2))),
          ),
        ),
    ]);

    // 칭호 표시 (showTitle=true일 때만)
    if (showTitle && achievement != null) {
      final diffColor = Color(Achievements.difficultyColor[achievement.difficulty]!);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        avatar,
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: diffColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: diffColor.withOpacity(0.3)),
          ),
          child: Text(achievement.title,
              style: TextStyle(fontSize: 9, color: diffColor, fontWeight: FontWeight.w600)),
        ),
      ]);
    }

    return avatar;
  }
}

// 무지개 프레임 아바타 (애니메이션)
class _RainbowFrameAvatar extends StatefulWidget {
  final double size, innerSize;
  final String skinEmoji;
  const _RainbowFrameAvatar({required this.size, required this.innerSize, required this.skinEmoji});
  @override
  State<_RainbowFrameAvatar> createState() => _RainbowFrameAvatarState();
}
class _RainbowFrameAvatarState extends State<_RainbowFrameAvatar> with SingleTickerProviderStateMixin {
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
    builder: (_, __) => CustomPaint(
      painter: _RainbowPainter(_anim.value, widget.size),
      child: SizedBox(
        width: widget.size, height: widget.size,
        child: Center(
          child: Container(
            width: widget.innerSize, height: widget.innerSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: context.surfaceColor),
            child: Center(child: Text(widget.skinEmoji, style: TextStyle(fontSize: widget.size * 0.42))),
          ),
        ),
      ),
    ),
  );
}
class _RainbowPainter extends CustomPainter {
  final double progress, size;
  _RainbowPainter(this.progress, this.size);
  @override
  void paint(Canvas canvas, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final radius = s.width / 2 - 1;
    final strokeW = size * 0.07;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // 캔버스를 회전시켜서 무지개가 돌아가는 효과
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * 2 * pi);
    canvas.translate(-center.dx, -center.dy);
    final gradient = const SweepGradient(
      colors: [
        Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFD700),
        Color(0xFF00CC00), Color(0xFF0000FF), Color(0xFF8B00FF),
        Color(0xFFFF0000),
      ],
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt
      ..shader = gradient.createShader(rect);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }
  @override
  bool shouldRepaint(_RainbowPainter old) => old.progress != progress;
}