import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

// 홈 화면 — 오늘의 목표, XP 카드, 스트릭, 집중모드 진입 버튼
// onSwitchTab: MainNav로부터 받은 탭 전환 콜백 (GlobalKey 대신 콜백 방식 사용)
class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const HomeScreen({super.key, this.onSwitchTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    if (userData == null) return const SizedBox();

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final weekDays = ['일', '월', '화', '수', '목', '금', '토'];
    final todayLabel = '${today.month}월 ${today.day}일 (${weekDays[today.weekday % 7]})';

    // 오늘 날짜에 해당하는 목표 필터링 (scheduledDate 또는 createdAt 기준)
    final todayGoals = app.goals.where((g) {
      if (g.scheduledDate != null) return g.scheduledDate == todayStr;
      if (g.createdAt != null) {
        final d = g.createdAt!;
        final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return ds == todayStr;
      }
      return false;
    }).toList();

    final focusHours = (userData.totalFocusMin / 60).floor();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 헤더: 인사말(좌) + 날짜(가운데 고정) + 버튼(우)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: SizedBox(
                  height: 48,
                  child: Stack(alignment: Alignment.center, children: [
                    // 날짜 텍스트 — Stack 중앙에 고정
                    Center(
                      child: Text(todayLabel,
                          style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    // 인사말 — 왼쪽 정렬
                    Positioned(
                      left: 0,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('좋은 하루예요,', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('${userData.name.split(' ').first} 님',
                            style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    // 우편함 + 알림 버튼 — 오른쪽 정렬 (동일 크기 36x36)
                    Positioned(
                      right: 0,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        // 우편함 버튼
                        GestureDetector(
                          onTap: () => Navigator.push(context, SlideRightRoute(page: const MailboxScreen())),
                          child: Stack(clipBehavior: Clip.none, children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                  border: Border.all(color: context.borderColor),
                                  borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Icon(Icons.mail_outline_rounded, size: 18, color: context.textSecondary)),
                            ),
                            if (app.unreadMailCount > 0)
                              Positioned(top: -3, right: -3, child: Container(
                                width: 15, height: 15,
                                decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                                child: Center(child: Text(
                                  app.unreadMailCount > 9 ? '9+' : '${app.unreadMailCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                )),
                              )),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        // 알림 버튼
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(context, SlideRightRoute(page: const ActivityNotificationScreen()));
                            if (context.mounted) app.reloadUnreadNotifCount();
                          },
                          child: Stack(clipBehavior: Clip.none, children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                  border: Border.all(color: context.borderColor),
                                  borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Icon(Icons.notifications_outlined, size: 18, color: context.textSecondary)),
                            ),
                            if (app.unreadNotifCount > 0)
                              Positioned(top: -3, right: -3, child: Container(
                                width: 15, height: 15,
                                decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                                child: Center(child: Text(
                                  app.unreadNotifCount > 9 ? '9+' : '${app.unreadNotifCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                )),
                              )),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // XP 카드 — 레벨, XP 진행률 표시
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor, width: 0.5)),
                  child: Column(children: [
                    Row(children: [
                      // 레벨 원형 배지
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: context.primaryColor, shape: BoxShape.circle),
                        child: Center(child: Text('${userData.level}',
                            style: TextStyle(color: context.isDark ? Colors.black : Colors.white,
                                fontSize: 17, fontWeight: FontWeight.w600))),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('현재 레벨', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(_levelTitle(userData.level),
                            style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${userData.xp}',
                            style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
                        Text('/ ${userData.xpToNext} XP',
                            style: TextStyle(color: context.textSecondary, fontSize: 12)),
                      ]),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: app.xpPercent / 100, minHeight: 5,
                        backgroundColor: context.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Lv.${userData.level}', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                      Text('${userData.xpToNext - userData.xp} XP 남음',
                          style: TextStyle(color: context.textSecondary, fontSize: 11)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // 통계 3개 카드 — 달성 목표, 최고 스트릭, 집중 시간
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _StatCard(label: '달성 목표', value: '${app.goalsThisMonth}', sub: '이번 달'),
                  const SizedBox(width: 10),
                  _StatCard(label: '최고 스트릭', value: '${userData.maxStreak}일', sub: '최고 기록'),
                  const SizedBox(width: 10),
                  _StatCard(label: '집중 시간', value: '${focusHours}h', sub: '누적'),
                ]),
              ),
              const SizedBox(height: 12),

              // 연속 출석 카드 — 스트릭 및 마일스톤 진행률
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor, width: 0.5)),
                  child: Column(children: [
                    Row(children: [
                      const Text('🔥', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${userData.streak}일 연속 출석',
                            style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
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

              // 오늘의 목표 헤더 — 전체 보기는 목표 탭(1)으로 전환
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('오늘의 목표',
                      style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                  GestureDetector(
                    onTap: () => widget.onSwitchTab?.call(1),
                    child: Text('전체 보기 →', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // 오늘 목표 목록 — 최대 3개 표시
              if (todayGoals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Column(children: [
                    Text('오늘 등록된 목표가 없어요',
                        style: TextStyle(color: context.textSecondary, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('아래 버튼으로 목표를 추가해보세요',
                        style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  ])),
                )
              else
                ...todayGoals.take(3).map((g) {
                  int? currentCount;
                  int? totalCount;
                  bool willAllDone = false;

                  if (g.repeatId != null) {
                    final repeatGoals = app.goals.where((r) => r.repeatId == g.repeatId).toList()
                      ..sort((a, b) => (a.scheduledDate ?? '').compareTo(b.scheduledDate ?? ''));
                    totalCount = repeatGoals.length;
                    currentCount = repeatGoals.indexWhere((r) => r.id == g.id) + 1;
                    // 현재 목표 외 나머지가 모두 완료면 이 목표가 마지막
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
                    decoration: BoxDecoration(
                        border: Border.all(color: context.borderColor),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('+ 목표 추가',
                        style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w500))),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 집중 모드 카드 — 시작 버튼은 집중 탭(2)으로 전환
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor, width: 0.5)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('집중 모드', style: TextStyle(color: context.textSecondary, fontSize: 11, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text('휴대폰 안쓰기',
                          style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('10분당 +50 XP 획득', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                    ]),
                    GestureDetector(
                      onTap: () => widget.onSwitchTab?.call(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(99)),
                        child: Text('시작',
                            style: TextStyle(color: context.isDark ? Colors.black : Colors.white,
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // 레벨업 모달
        if (app.levelUpTo != null)
          LevelUpModal(level: app.levelUpTo!, onClose: () => app.dismissLevelUp()),
        // 출석 모달
        if (app.showAttendModal)
          AttendanceModal(onClose: () => app.dismissAttendModal()),
        // 스트릭 모달 (마일스톤 / 끊김)
        if (app.streakModalType != null)
          StreakModal(type: app.streakModalType!, onClose: () => app.dismissStreakModal()),
      ]),
    );
  }

  // 레벨별 칭호 텍스트
  String _levelTitle(int level) {
    // 레벨 구간별 접두사 (1~10레벨)
    const prefixes = ['', '새내기', '성장하는', '도전하는', '달리는', '노력하는', '빛나는', '도약하는', '질주하는', '각성한', '눈뜬'];
    final prefix = level <= 10 ? prefixes[level] : '';
    final title = AppProvider.levelTitle(level);
    return prefix.isEmpty ? title : '$prefix $title';
  }
}

// 통계 카드 위젯 — 달성 목표 / 최고 스트릭 / 집중 시간
class _StatCard extends StatelessWidget {
  final String label, value, sub;
  const _StatCard({required this.label, required this.value, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor, width: 0.5)),
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

// 스트릭 마일스톤 진행률 바 — 다음 마일스톤까지 남은 일수 표시
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
        child: LinearProgressIndicator(
          value: pct, minHeight: 5,
          backgroundColor: context.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
        ),
      ),
    ]);
  }
}

// 목표 아이템 위젯 — 완료/취소 애니메이션, 반복 목표 회차 표시
class _GoalItem extends StatefulWidget {
  final dynamic goal;
  final int? currentCount;
  final int? totalCount;
  final bool willAllDone;
  final VoidCallback onComplete, onUncomplete;
  const _GoalItem({
    required this.goal,
    this.currentCount,
    this.totalCount,
    this.willAllDone = false,
    required this.onComplete,
    required this.onUncomplete,
  });
  @override
  State<_GoalItem> createState() => _GoalItemState();
}

class _GoalItemState extends State<_GoalItem> with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
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
    // 목표 유형별 태그 색상
    final tagColor = g.type == 'short' ? const Color(0xFF1b8a5a)
        : g.type == 'mid' ? const Color(0xFFf9a825)
        : const Color(0xFF3949ab);
    final tagLabel = g.type == 'short' ? '단기' : g.type == 'mid' ? '중기' : '장기';
    final isRepeat = g.repeatId != null;

    // 마지막 회차 완료 시 repeatXp + xp, 그 외 repeatXp, 단일 목표는 xp
    final displayXp = isRepeat
        ? (widget.willAllDone ? g.repeatXp + g.xp : g.repeatXp)
        : g.xp;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: g.done ? 0.6 : 1.0,
      child: TapScale(
        onTap: g.done ? widget.onUncomplete : widget.onComplete,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor, width: 0.5)),
          child: Row(children: [
            // 완료 체크 원형 버튼 — 완료 시 primaryColor로 채워짐
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.done ? context.primaryColor : Colors.transparent,
                border: g.done ? null : Border.all(color: context.borderColor, width: 1.5),
              ),
              child: g.done
                  ? Icon(Icons.check, color: context.isDark ? Colors.black : Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: g.done ? context.textSecondary : context.textPrimary,
                        fontSize: 14, fontWeight: FontWeight.w500,
                        decoration: g.done ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                      child: Text(
                        // 반복 목표는 현재/전체 회차 표시
                        isRepeat && widget.currentCount != null && widget.totalCount != null
                            ? '${g.title} (${widget.currentCount} / ${widget.totalCount})'
                            : g.title,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(isRepeat ? '반복' : tagLabel,
                        style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: (g.progress ?? 0) / 100),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (_, value, __) => LinearProgressIndicator(
                          value: value, minHeight: 4,
                          backgroundColor: context.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${g.progress ?? 0}%', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                ]),
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: g.done ? const Color(0xFF1b8a5a) : context.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w500,
                ),
                child: Text('+$displayXp XP'),
              ),
              if (g.done) ...[
                const SizedBox(height: 6),
                // 완료 취소 버튼
                GestureDetector(
                  onTap: widget.onUncomplete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        border: Border.all(color: context.borderColor),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('취소', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}