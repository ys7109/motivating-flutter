import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../goals/add_goal_screen.dart';
import '../../widgets/level_up_modal.dart';
import '../../widgets/attendance_modal.dart';
import '../../widgets/streak_modal.dart';
import '../../widgets/tap_scale.dart';
import '../../utils/transitions.dart';
import '../my/mailbox_screen.dart';
import '../my/activity_notification_screen.dart';
import '../social/character_avatar.dart';

const _kPatchId = 'patchnote';
const _kPatchTitle = '패치노트';
const _kPatchItems = [
  '1. 목표 이월 기능이 추가되었습니다. 미완료 목표를 오늘로 이월이 가능하며, 1일당 20XP의 패널티가 적용됩니다.'
  '2. 채팅 메시지를 길게 눌러 반응을 남기거나 수정, 삭제를 할 수 있습니다. 기존의 반응추가 버튼은 삭제됩니다.'
  '3. 자신의 메시지에도 반응을 추가할 수 있게 되었습니다.'
  '4. 일기 탭에서도 사진을 추가할 수 있도록 변경되었습니다.',
];

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  const HomeScreen({super.key, this.onSwitchTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 출석 모달 로컬 표시 상태 — app.showAttendModal을 로컬로 캐싱해서 Stack 오버레이로 표시
  bool _showAttend = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 출석 모달 먼저 확인 후 패치노트 표시
      _syncAttendModal();
      if (mounted && !_showAttend) await _checkAndShowPatch();
    });
  }

  // app.showAttendModal 상태를 로컬 _showAttend에 동기화
  void _syncAttendModal() {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    if (app.showAttendModal && !_showAttend) {
      setState(() => _showAttend = true);
    }
  }

  Future<void> _checkAndShowPatch() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getBool('patch_hidden_$_kPatchId') ?? false;
    if (!hidden && mounted) _showPatchDialog();
  }

  void _showPatchDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PatchDialog(
        title: _kPatchTitle,
        items: _kPatchItems,
        onClose: () => Navigator.pop(ctx),
        onHidePermanently: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('patch_hidden_$_kPatchId', true);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // 출석 모달 닫기 — 닫힌 후 패치노트 확인
  Future<void> _dismissAttend() async {
    final app = context.read<AppProvider>();
    app.dismissAttendModal();
    setState(() => _showAttend = false);
    await _checkAndShowPatch();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    if (userData == null) return const SizedBox();

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final weekDays = ['일', '월', '화', '수', '목', '금', '토'];
    final todayLabel = '${today.month}월 ${today.day}일 (${weekDays[today.weekday % 7]})';

    final todayGoals = app.goals.where((g) {
      if (g.scheduledDate != null) return g.scheduledDate == todayStr;
      if (g.createdAt != null) {
        final d = g.createdAt!;
        final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return ds == todayStr;
      }
      return false;
    }).toList();

    final todayTotal = todayGoals.length;
    final todayDone = todayGoals.where((g) => g.done).length;
    final todayPct = todayTotal == 0 ? 0 : (todayDone / todayTotal * 100).round();
    final focusHours = (userData.totalFocusMin / 60).floor();

    // 외부(부활 아이템 등)에서 app.showAttendModal이 true로 바뀌면 로컬도 동기화
    if (app.showAttendModal && !_showAttend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showAttend = true);
      });
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: SizedBox(
                  height: 48,
                  child: Stack(alignment: Alignment.center, children: [
                    Center(child: Text(todayLabel, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
                    Positioned(
                      left: 0,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('좋은 하루예요,', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('${userData.name} 님', style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Positioned(
                      right: 0,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        // 패치노트 버튼
                        GestureDetector(
                          onTap: _showPatchDialog,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(99)),
                            child: Center(child: Icon(Icons.campaign_outlined, size: 18, color: context.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 우편함 버튼
                        GestureDetector(
                          onTap: () => Navigator.push(context, SlideRightRoute(page: const MailboxScreen())),
                          child: Stack(clipBehavior: Clip.none, children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Icon(Icons.mail_outline_rounded, size: 18, color: context.textSecondary)),
                            ),
                            if (app.unreadMailCount > 0)
                              Positioned(top: -3, right: 0,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                                  child: Center(child: Text(app.unreadMailCount > 99 ? '99+' : '${app.unreadMailCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                                )),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        // 활동 알림 버튼
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(context, SlideRightRoute(page: const ActivityNotificationScreen()));
                            if (context.mounted) app.reloadUnreadNotifCount();
                          },
                          child: Stack(clipBehavior: Clip.none, children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Icon(Icons.notifications_outlined, size: 18, color: context.textSecondary)),
                            ),
                            if (app.unreadNotifCount > 0)
                              Positioned(top: -3, right: 0,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                                  child: Center(child: Text(app.unreadNotifCount > 99 ? '99+' : '${app.unreadNotifCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                                )),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // XP 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor, width: 0.5)),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: context.subtleBg, shape: BoxShape.circle),
                        child: CharacterAvatar(character: userData.character.toMap(), size: 46, profileImageUrl: userData.profileImageUrl),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('현재 등급', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(_levelTitle(userData.level), style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${userData.xp}', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
                        Text('/ ${userData.xpToNext} XP', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                      ]),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: app.xpPercent / 100, minHeight: 5, backgroundColor: context.borderColor, valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor)),
                    ),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Lv.${userData.level}', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                      Text('${userData.xpToNext - userData.xp} XP 남음', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // 통계 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _StatCard(label: '달성 목표', value: '${app.goalsThisMonth}', sub: '이번 달'),
                  const SizedBox(width: 10),
                  _StatCard(label: '최고 출석', value: '${userData.maxStreak}일', sub: '최고 기록'),
                  const SizedBox(width: 10),
                  _StatCard(label: '집중 시간', value: '${focusHours}h', sub: '누적'),
                ]),
              ),
              const SizedBox(height: 12),

              // 연속 출석 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor, width: 0.5)),
                  child: Column(children: [
                    Row(children: [
                      const Text('🔥', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${userData.streak}일 연속 출석', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(userData.streak >= 7 ? '대단해요! 계속 유지하세요' : '7일까지 ${7 - userData.streak}일 남음',
                            style: TextStyle(color: context.textSecondary, fontSize: 12)),
                      ]),
                    ]),
                    _StreakMilestone(streak: userData.streak),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // 오늘의 목표 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('오늘의 목표', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                    if (todayTotal > 0) ...[
                      const SizedBox(width: 6),
                      Text('($todayPct% 완료)', style: TextStyle(color: todayPct == 100 ? const Color(0xFF1b8a5a) : context.textSecondary, fontSize: 12)),
                    ],
                  ]),
                  GestureDetector(
                    onTap: () => widget.onSwitchTab?.call(1),
                    child: Text('전체 보기 →', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              if (todayGoals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Column(children: [
                    Text('오늘 등록된 목표가 없어요', style: TextStyle(color: context.textSecondary, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('아래 버튼으로 목표를 추가해보세요', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  ])),
                )
              else
                ...todayGoals.take(3).map((g) {
                  int? currentCount;
                  int? totalCount;
                  bool willAllDone = false;
                  if (g.repeatId != null) {
                    final repeatGoals = app.goals
                        .where((r) => r.repeatId == g.repeatId)
                        .toList()
                      ..sort((a, b) => (a.scheduledDate ?? '').compareTo(b.scheduledDate ?? ''));
                    totalCount = repeatGoals.length;
                    currentCount = repeatGoals.indexWhere((r) => r.id == g.id) + 1;
                    willAllDone = repeatGoals.where((r) => r.id != g.id).every((r) => r.done);
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _GoalItem(
                      goal: g,
                      currentCount: currentCount,
                      totalCount: totalCount,
                      willAllDone: willAllDone,
                      onComplete: () => app.completeGoal(g.id),
                      onUncomplete: () => app.uncompleteGoal(g.id),
                      onDelete: () {
                        final info = app.getRepeatInfo(g.id);
                        showDialog(
                          context: context,
                          builder: (ctx) => _DeleteConfirmDialog(
                            repeatInfo: info,
                            onDeleteAll: () { Navigator.pop(ctx); app.removeRepeatGoals(info!['repeatId']); },
                            onDeleteOne: () { Navigator.pop(ctx); app.removeGoal(g.id); },
                            onCancel: () => Navigator.pop(ctx),
                          ),
                        );
                      },
                      onEdit: () async {
                        final uid = app.authUser?.uid;
                        if (uid == null) return;
                        final snap = await app.firestoreService.getGoalDoc(uid, g.id);
                        if (!context.mounted || snap == null) return;
                        if (g.repeatId != null) {
                          final repeatGoals = app.goals
                              .where((r) => r.repeatId == g.repeatId)
                              .map((r) => r.scheduledDate ?? '')
                              .where((d) => d.isNotEmpty)
                              .toList()..sort();
                          if (repeatGoals.isNotEmpty) {
                            snap['startDate'] = repeatGoals.first;
                            snap['endDate'] = repeatGoals.last;
                          }
                        }
                        Navigator.push(context, SlideUpRoute(page: AddGoalScreen(editGoalId: g.id, editGoalData: snap)));
                      },
                    ),
                  );
                }),

              // 목표 추가 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, SlideUpRoute(page: const AddGoalScreen())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('+ 목표 추가', style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w500))),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 집중 모드 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor, width: 0.5)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('집중 모드', style: TextStyle(color: context.textSecondary, fontSize: 11, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text('휴대폰 안쓰기', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('집중한 시간에 비례해 XP 획득', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                    ]),
                    GestureDetector(
                      onTap: () => widget.onSwitchTab?.call(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(99)),
                        child: Text('시작', style: TextStyle(color: context.onPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        if (app.levelUpTo != null)
          LevelUpModal(level: app.levelUpTo!, onClose: () => app.dismissLevelUp()),

        // 출석 모달 — Stack 최상단
        if (_showAttend)
          AttendanceModal(onClose: _dismissAttend),

        if (app.streakModalType != null)
          StreakModal(type: app.streakModalType!, onClose: () => app.dismissStreakModal()),
      ]),
    );
  }

  String _levelTitle(int level) {
    const prefixes = ['', '새내기', '성장하는', '도전하는', '달리는', '노력하는', '빛나는', '도약하는', '질주하는', '각성한', '눈뜬'];
    final prefix = level <= 10 ? prefixes[level] : '';
    final title = AppProvider.levelTitle(level);
    return prefix.isEmpty ? title : '$prefix $title';
  }
}

class _PatchDialog extends StatelessWidget {
  final String title;
  final List<String> items;
  final VoidCallback onClose;
  final VoidCallback onHidePermanently;
  const _PatchDialog({required this.title, required this.items, required this.onClose, required this.onHidePermanently});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.modalBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.campaign_outlined, size: 20, color: context.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary))),
            GestureDetector(onTap: onClose, child: Icon(Icons.close, size: 18, color: context.textSecondary)),
          ]),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(item, style: TextStyle(fontSize: 13, color: context.textPrimary, height: 1.5)),
          )),
          const SizedBox(height: 16),
          Row(children: [
            GestureDetector(onTap: onHidePermanently, child: Text('다시 보지 않기', style: TextStyle(fontSize: 12, color: context.textSecondary))),
            const Spacer(),
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(99)),
                child: Text('확인', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.onPrimary)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  const _StatCard({required this.label, required this.value, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: context.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: context.textPrimary, fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: context.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _StreakMilestone extends StatelessWidget {
  final int streak;
  const _StreakMilestone({required this.streak});
  @override
  Widget build(BuildContext context) {
    final milestones = [7, 14, 30, 60, 100, 365];
    final next = milestones.firstWhere((m) => m > streak, orElse: () => 0);
    if (next == 0) return const SizedBox();
    final idx = milestones.indexOf(next);
    final prev = idx > 0 ? milestones[idx - 1] : 0;
    final pct = ((streak - prev) / (next - prev)).clamp(0.0, 1.0);
    return Column(children: [
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('🎁 특별 보상까지', style: TextStyle(color: context.textSecondary, fontSize: 11)),
        Text('$next일 (${next - streak}일 남음)', style: TextStyle(color: context.textSecondary, fontSize: 11)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: context.borderColor, valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor)),
      ),
    ]);
  }
}

class _GoalItem extends StatefulWidget {
  final dynamic goal;
  final int? currentCount, totalCount;
  final bool willAllDone;
  final VoidCallback onComplete, onUncomplete, onDelete;
  final Future<void> Function() onEdit;
  const _GoalItem({required this.goal, this.currentCount, this.totalCount,
      this.willAllDone = false, required this.onComplete,
      required this.onUncomplete, required this.onDelete, required this.onEdit});
  @override
  State<_GoalItem> createState() => _GoalItemState();
}

class _GoalItemState extends State<_GoalItem> with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;
  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    if (widget.goal.done) _checkCtrl.value = 1.0;
  }
  @override
  void didUpdateWidget(_GoalItem old) {
    super.didUpdateWidget(old);
    if (!old.goal.done && widget.goal.done) _checkCtrl.forward();
    else if (old.goal.done && !widget.goal.done) _checkCtrl.reverse();
  }
  @override
  void dispose() { _checkCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final tagColor = g.type == 'short' ? const Color(0xFF1b8a5a) : g.type == 'mid' ? const Color(0xFFf9a825) : const Color(0xFF3949ab);
    final tagLabel = g.type == 'short' ? '단기' : g.type == 'mid' ? '중기' : '장기';
    final isRepeat = g.repeatId != null;
    final displayXp = isRepeat ? (widget.willAllDone ? g.repeatXp + g.xp : g.repeatXp) : g.xp;
    return GestureDetector(
      onLongPress: widget.onEdit,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: g.done ? 0.6 : 1.0,
        child: TapScale(
          onTap: g.done ? widget.onUncomplete : widget.onComplete,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor, width: 0.5)),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24, height: 24,
                decoration: BoxDecoration(shape: BoxShape.circle, color: g.done ? context.primaryColor : Colors.transparent, border: g.done ? null : Border.all(color: context.borderColor, width: 1.5)),
                child: g.done ? Icon(Icons.check, color: context.onPrimary, size: 13) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(isRepeat ? '반복' : tagLabel, style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(color: g.done ? context.textSecondary : context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500, decoration: g.done ? TextDecoration.lineThrough : TextDecoration.none),
                    child: Text(isRepeat && widget.currentCount != null && widget.totalCount != null
                        ? '${g.title} (${widget.currentCount} / ${widget.totalCount})' : g.title),
                  )),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: (g.progress ?? 0) / 100),
                      duration: const Duration(milliseconds: 600), curve: Curves.easeOut,
                      builder: (_, value, __) => LinearProgressIndicator(value: value, minHeight: 4, backgroundColor: context.borderColor, valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor)),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Text('${g.progress ?? 0}%', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                ]),
              ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(6)), child: Text('수정', style: TextStyle(fontSize: 11, color: context.textSecondary))),
                  ),
                  const SizedBox(width: 4),
                  TapScale(
                    onTap: widget.onDelete,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(border: Border.all(color: AppTheme.danger.withOpacity(0.5)), borderRadius: BorderRadius.circular(6)), child: Text('삭제', style: const TextStyle(fontSize: 11, color: AppTheme.danger))),
                  ),
                ]),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: g.done ? const Color(0xFF1b8a5a) : context.textSecondary),
                  child: Text('+$displayXp XP'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final Map<String, dynamic>? repeatInfo;
  final VoidCallback onDeleteAll, onDeleteOne, onCancel;
  const _DeleteConfirmDialog({required this.repeatInfo, required this.onDeleteAll, required this.onDeleteOne, required this.onCancel});
  @override
  Widget build(BuildContext context) {
    final isSingle = repeatInfo == null;
    return Dialog(
      backgroundColor: context.modalBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isSingle ? '목표 삭제' : '반복 목표 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 8),
          Text(isSingle ? '이 목표를 삭제하시겠습니까?' : '반복 목표를 모두 함께 삭제하시겠습니까?', style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.6)),
          if (!isSingle) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(10)),
                child: Text('삭제되는 목표: ${repeatInfo!["undone"]}개', style: TextStyle(fontSize: 12, color: context.textSecondary))),
          ],
          const SizedBox(height: 16),
          GestureDetector(onTap: isSingle ? onDeleteOne : onDeleteAll, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(isSingle ? '삭제' : '모두 삭제', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white))))),
          if (!isSingle) ...[
            const SizedBox(height: 8),
            GestureDetector(onTap: onDeleteOne, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('하나만 삭제', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary))))),
          ],
          const SizedBox(height: 8),
          GestureDetector(onTap: onCancel, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('취소', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary))))),
        ]),
      ),
    );
  }
}