import 'package:flutter/material.dart';
import '../../utils/theme.dart';

const kSkins = [
  {'id': 'default', 'emoji': '🧑'},
  {'id': 'warrior', 'emoji': '⚔️'},
  {'id': 'scholar', 'emoji': '📚'},
  {'id': 'explorer', 'emoji': '🧭'},
  {'id': 'legend', 'emoji': '🌟'},
];
const kBadges = [
  {'id': 'none', 'emoji': ''},
  {'id': 'flame', 'emoji': '🔥'},
  {'id': 'lightning', 'emoji': '⚡'},
  {'id': 'crown', 'emoji': '👑'},
  {'id': 'diamond', 'emoji': '💎'},
];
const kFrames = [
  {'id': 'none', 'color': 0x00000000},
  {'id': 'silver', 'color': 0xFF9e9e9e},
  {'id': 'gold', 'color': 0xFFf9a825},
  {'id': 'rainbow', 'color': 0xFFe040fb},
];

String skinEmoji(String? skin) =>
    (kSkins.firstWhere((s) => s['id'] == skin, orElse: () => kSkins[0])['emoji'] as String?) ?? '🧑';

String badgeEmoji(String? badge) =>
    (kBadges.firstWhere((b) => b['id'] == badge, orElse: () => kBadges[0])['emoji'] as String?) ?? '';

Color? frameColor(String? frame) {
  if (frame == null || frame == 'none') return null;
  final f = kFrames.firstWhere((f) => f['id'] == frame, orElse: () => kFrames[0]);
  final c = f['color'] as int;
  return c == 0 ? null : Color(c);
}

class CharacterAvatar extends StatelessWidget {
  final Map<String, dynamic>? character;
  final double size;
  const CharacterAvatar({super.key, this.character, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final skin = character?['skin'] as String?;
    final badge = character?['badge'] as String?;
    final frame = character?['frame'] as String?;
    final fc = frameColor(frame);
    final se = skinEmoji(skin);
    final be = badgeEmoji(badge);
    final innerSize = size * 0.88;

    return Stack(clipBehavior: Clip.none, children: [
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
  }
}