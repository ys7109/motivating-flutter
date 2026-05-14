import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/achievement_definitions.dart';
import '../../models/goal_model.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import 'character_avatar.dart';

Future<void> showUserProfileSheet(BuildContext context, String uid) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.modalBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UserProfileSheet(uid: uid),
  );
}

class _UserProfileSheet extends StatefulWidget {
  final String uid;
  const _UserProfileSheet({required this.uid});

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  final _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _user;
  List<GoalModel> _completedGoals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userSnap = await _db.collection('users').doc(widget.uid).get();
      final goals = await FirestoreService().getUserCompletedGoals(widget.uid);
      if (!mounted) return;
      setState(() {
        _user = userSnap.data();
        _completedGoals = goals;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatFocus(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}분';
    if (m == 0) return '${h}시간';
    return '${h}시간 ${m}분';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    if (_loading) {
      return SizedBox(
        height: 220 + bottomPad,
        child: Center(
            child: CircularProgressIndicator(color: context.primaryColor)),
      );
    }

    final user = _user;
    if (user == null) {
      return SizedBox(
        height: 180 + bottomPad,
        child: Center(
          child: Text('프로필을 불러오지 못했어요',
              style: TextStyle(fontSize: 14, color: context.textSecondary)),
        ),
      );
    }

    final level = user['level'] as int? ?? 1;
    final xp = user['xp'] as int? ?? 0;
    final xpToNext = user['xpToNext'] as int? ?? AppProvider.xpRequired(level);
    final xpPct = xpToNext == 0 ? 0.0 : (xp / xpToNext).clamp(0.0, 1.0);
    final achievements = List<String>.from(user['achievements'] ?? []);
    final equippedId = user['equippedAchievement'] as String?;
    final equipped =
        equippedId != null ? Achievements.findById(equippedId) : null;
    final unlockedAchievements =
        Achievements.all.where((a) => achievements.contains(a.id)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPad + 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            CharacterAvatar(
              character: user['character'] as Map<String, dynamic>?,
              size: 56,
              profileImageUrl: user['profileImageUrl'] as String?,
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(user['name'] as String? ?? '모험가',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary)),
                  const SizedBox(height: 3),
                  Text('${AppProvider.levelTitle(level)} · Lv.$level',
                      style: TextStyle(
                          fontSize: 12, color: context.textSecondary)),
                  if (equipped != null) ...[
                    const SizedBox(height: 5),
                    _AchievementChip(achievement: equipped),
                  ],
                ])),
            // 닫기 버튼
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: 20, color: context.textSecondary),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.subtleBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('현재 경험치',
                    style:
                        TextStyle(fontSize: 12, color: context.textSecondary)),
                Text('$xp / $xpToNext XP',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: xpPct,
                  minHeight: 6,
                  backgroundColor: context.borderColor,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(context.primaryColor),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _ProfileStat(label: '달성 목표', value: '${_completedGoals.length}개'),
            const SizedBox(width: 8),
            _ProfileStat(label: '최고 출석', value: '${user['maxStreak'] ?? 0}일'),
            const SizedBox(width: 8),
            _ProfileStat(
                label: '누적 집중',
                value: _formatFocus(user['totalFocusMin'] as int? ?? 0)),
          ]),
          const SizedBox(height: 14),
          Flexible(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SectionTitle('완료한 업적 ${unlockedAchievements.length}개'),
                const SizedBox(height: 8),
                if (unlockedAchievements.isEmpty)
                  _EmptyText('아직 완료한 업적이 없어요')
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: unlockedAchievements
                        .map((a) => _AchievementChip(achievement: a))
                        .toList(),
                  ),
                const SizedBox(height: 18),
                _SectionTitle('달성 목표 ${_completedGoals.length}개'),
                const SizedBox(height: 8),
                if (_completedGoals.isEmpty)
                  _EmptyText('아직 달성한 목표가 없어요')
                else
                  ..._completedGoals
                      .take(20)
                      .map((goal) => _GoalRow(goal: goal)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: context.subtleBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: context.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.textPrimary));
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.subtleBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: context.textSecondary))),
      );
}

class _AchievementChip extends StatelessWidget {
  final Achievement achievement;
  const _AchievementChip({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final color = Color(Achievements.difficultyColor[achievement.difficulty]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text('${achievement.emoji} ${achievement.title}',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final GoalModel goal;
  const _GoalRow({required this.goal});

  // 달성 날짜 포맷 — yyyy.MM.dd
  String _dateLabel(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  // 1번: 실제 획득 XP — 반복 목표는 repeatXp, 단일 목표는 xp
  int get _displayXp => goal.repeatId != null ? goal.repeatXp : goal.xp;

  // 목표 유형 태그 색상
  Color get _tagColor {
    if (goal.type == 'short') return const Color(0xFF1b8a5a);
    if (goal.type == 'mid') return const Color(0xFFf9a825);
    return const Color(0xFF3949ab);
  }

  // 목표 유형 레이블
  String get _tagLabel {
    if (goal.repeatId != null) return '반복';
    if (goal.type == 'short') return '단기';
    if (goal.type == 'mid') return '중기';
    return '장기';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.subtleBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        // 목표 유형 태그
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _tagColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(_tagLabel,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _tagColor)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(goal.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // 1번: 실제 획득 XP 표시
          Text('+$_displayXp XP',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1b8a5a))),
          // 1번: 달성 날짜 표시
          if (goal.completedAt != null) ...[
            const SizedBox(height: 2),
            Text(_dateLabel(goal.completedAt!),
                style: TextStyle(fontSize: 10, color: context.textSecondary)),
          ],
        ]),
      ]),
    );
  }
}