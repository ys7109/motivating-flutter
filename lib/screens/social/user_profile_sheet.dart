import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/achievement_definitions.dart';
import '../../models/goal_model.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/friend_service.dart';
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
  bool _isFriend = false; // 친구 여부 — 달성 목표 공개 범위 결정
  String? _memo;          // 이 친구에 대한 내 메모

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final myUid = context.read<AppProvider>().authUser?.uid;
      final userSnap = await _db.collection('users').doc(widget.uid).get();

      // 내 프로필이면 항상 친구 처리, 아니면 친구 여부 확인
      bool isFriend = false;
      String? memo;
      if (myUid != null && myUid != widget.uid) {
        final status = await FriendService().getFriendshipStatus(myUid, widget.uid);
        isFriend = status == 'accepted';
        // 메모 조회 — users/{myUid}/friendMemos/{targetUid}
        final memoSnap = await _db
            .collection('users').doc(myUid)
            .collection('friendMemos').doc(widget.uid).get();
        memo = memoSnap.data()?['memo'] as String?;
      } else {
        isFriend = true; // 내 프로필
      }

      // 친구인 경우에만 달성 목표 로드
      List<GoalModel> goals = [];
      if (isFriend || myUid == widget.uid) {
        goals = await FirestoreService().getUserCompletedGoals(widget.uid);
      }

      if (!mounted) return;
      setState(() {
        _user = userSnap.data();
        _completedGoals = goals;
        _isFriend = isFriend;
        _memo = memo;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 메모 저장 — users/{myUid}/friendMemos/{targetUid}
  Future<void> _saveMemo(String memo) async {
    final myUid = context.read<AppProvider>().authUser?.uid;
    if (myUid == null) return;
    await _db
        .collection('users').doc(myUid)
        .collection('friendMemos').doc(widget.uid)
        .set({'memo': memo.trim()});
    setState(() => _memo = memo.trim().isEmpty ? null : memo.trim());
  }

  // 메모 입력 바텀시트 — 사용자가 입력한 값만 받아서 '- 값' 형태로 표시
  void _openMemoSheet() {
    // 기존 메모에서 '- ' 접두사 제거 후 현재 값 표시
    final currentInput = _memo?.startsWith('- ') == true
        ? _memo!.substring(2)
        : (_memo ?? '');
    final ctrl = TextEditingController(text: currentInput);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('친구 메모', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w600, color: ctx.textPrimary)),
            GestureDetector(onTap: () => Navigator.pop(ctx),
                child: Text('×', style: TextStyle(fontSize: 24, color: ctx.textSecondary))),
          ]),
          const SizedBox(height: 6),
          // 미리보기 — 입력하면 '- 값' 형태로 표시
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: ctrl,
            builder: (_, val, __) => val.text.trim().isEmpty
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('- ${val.text.trim()}',
                        style: TextStyle(fontSize: 13, color: ctx.textSecondary)),
                  ),
          ),
          Container(
            decoration: BoxDecoration(
                color: ctx.surfaceColor,
                border: Border.all(color: ctx.borderColor),
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: ctrl, maxLength: 30, autofocus: true,
              style: TextStyle(fontSize: 14, color: ctx.textPrimary),
              decoration: InputDecoration(
                hintText: '예: 엄마, 고등학교 친구',
                hintStyle: TextStyle(color: ctx.textSecondary),
                border: InputBorder.none,
                counterStyle: TextStyle(fontSize: 11, color: ctx.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            // 메모 삭제 버튼 — 기존 메모가 있을 때만 표시
            if (_memo != null) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _saveMemo('');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        color: ctx.subtleBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ctx.borderColor)),
                    child: Center(child: Text('삭제', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.danger))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final input = ctrl.text.trim();
                  Navigator.pop(ctx);
                  // 입력값이 있으면 '- 값' 형태로 저장
                  await _saveMemo(input.isEmpty ? '' : '- $input');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: ctx.primaryColor, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('저장', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: ctx.onPrimary))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
    ctrl.dispose();
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
    final myUid = context.read<AppProvider>().authUser?.uid;
    final isMe = myUid == widget.uid;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (_loading) {
      return SizedBox(
        height: 220 + bottomPad,
        child: Center(child: CircularProgressIndicator(color: context.primaryColor)),
      );
    }

    final user = _user;
    if (user == null) {
      return SizedBox(
        height: 180 + bottomPad,
        child: Center(child: Text('프로필을 불러오지 못했어요',
            style: TextStyle(fontSize: 14, color: context.textSecondary))),
      );
    }

    final level = user['level'] as int? ?? 1;
    final xp = user['xp'] as int? ?? 0;
    final xpToNext = user['xpToNext'] as int? ?? AppProvider.xpRequired(level);
    final xpPct = xpToNext == 0 ? 0.0 : (xp / xpToNext).clamp(0.0, 1.0);
    final achievements = List<String>.from(user['achievements'] ?? []);
    final equippedId = user['equippedAchievement'] as String?;
    final equipped = equippedId != null ? Achievements.findById(equippedId) : null;
    final unlockedAchievements =
        Achievements.all.where((a) => achievements.contains(a.id)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPad + 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: context.borderColor, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(height: 18),
          Row(children: [
            CharacterAvatar(
              character: user['character'] as Map<String, dynamic>?,
              size: 56,
              profileImageUrl: user['profileImageUrl'] as String?,
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user['name'] as String? ?? '모험가',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: context.textPrimary)),
              const SizedBox(height: 3),
              Text('${AppProvider.levelTitle(level)} · Lv.$level',
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
              if (equipped != null) ...[
                const SizedBox(height: 5),
                _AchievementChip(achievement: equipped),
              ],
              // 3번: 메모가 있으면 회색 글씨로 표시
              if (_memo != null && _memo!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_memo!,
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ])),
            // 닫기 버튼
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: 20, color: context.textSecondary),
            ),
          ]),

          // 3번: 메모 추가/수정 버튼 — 내 프로필이 아닐 때만, 친구인 경우에만 표시
          if (!isMe && _isFriend) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _openMemoSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: context.subtleBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderColor)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.edit_note_outlined, size: 16, color: context.textSecondary),
                  const SizedBox(width: 6),
                  Text(_memo == null || _memo!.isEmpty ? '메모 추가' : '메모 수정',
                      style: TextStyle(fontSize: 13, color: context.textSecondary)),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('현재 경험치',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
                Text('$xp / $xpToNext XP',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: context.textPrimary)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: xpPct, minHeight: 6,
                  backgroundColor: context.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
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
            _ProfileStat(label: '누적 집중',
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
                    spacing: 6, runSpacing: 6,
                    children: unlockedAchievements
                        .map((a) => _AchievementChip(achievement: a))
                        .toList(),
                  ),
                const SizedBox(height: 18),
                // 7번: 달성 목표는 친구인 경우에만 공개
                _SectionTitle('달성 목표'),
                const SizedBox(height: 8),
                if (!_isFriend && !isMe)
                  // 친구가 아니면 비공개 메시지 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: context.subtleBg, borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      Icon(Icons.lock_outline, size: 20, color: context.textSecondary),
                      const SizedBox(height: 6),
                      Text('친구인 경우에만 확인이 가능합니다.',
                          style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    ]),
                  )
                else if (_completedGoals.isEmpty)
                  _EmptyText('아직 달성한 목표가 없어요')
                else
                  ..._completedGoals.take(20).map((goal) => _GoalRow(goal: goal)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label, value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            color: context.subtleBg, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700, color: context.textPrimary)),
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
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
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
            color: context.subtleBg, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(text,
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
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final GoalModel goal;
  const _GoalRow({required this.goal});

  // 달성 날짜 포맷 — yyyy.MM.dd
  String _dateLabel(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  // 실제 획득 XP — 반복 목표는 repeatXp, 단일 목표는 xp
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
          color: context.subtleBg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: _tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
          child: Text(_tagLabel,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _tagColor)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(goal.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: context.textPrimary))),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // 실제 획득 XP 표시
          Text('+$_displayXp XP',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF1b8a5a))),
          // 달성 날짜 표시
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