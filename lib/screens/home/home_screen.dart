import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_nav.dart';
import '../goals/add_goal_screen.dart';
import '../../widgets/level_up_modal.dart';
import '../../widgets/attendance_modal.dart';
import '../../widgets/streak_modal.dart';
import '../../widgets/tap_scale.dart';
import '../../utils/transitions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _logoutModal = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    if (userData == null) return const SizedBox();

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
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

    final focusHours = (userData.totalFocusMin / 60).floor();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('좋은 하루예요,',
                              style: TextStyle(color: context.textSecondary, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('${userData.name.split(' ').first} 님',
                              style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                        ]),
                        Text(todayLabel,
                            style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        GestureDetector(
                          onTap: () => setState(() => _logoutModal = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                                border: Border.all(color: context.borderColor),
                                borderRadius: BorderRadius.circular(99)),
                            child: Text('로그아웃',
                                style: TextStyle(color: context.textSecondary, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // XP 카드
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor, width: 0.5),
                      ),
                      child: Column(children: [
                        Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                                color: context.primaryColor, shape: BoxShape.circle),
                            child: Center(child: Text('${userData.level}',
                                style: TextStyle(
                                    color: context.isDark ? Colors.black : Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600))),
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('현재 레벨',
                                style: TextStyle(color: context.textSecondary, fontSize: 11)),
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
                            value: app.xpPercent / 100,
                            minHeight: 5,
                            backgroundColor: context.borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Lv.${userData.level}',
                              style: TextStyle(color: context.textSecondary, fontSize: 11)),
                          Text('${userData.xpToNext - userData.xp} XP 남음',
                              style: TextStyle(color: context.textSecondary, fontSize: 11)),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 통계 3개
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

                  // 스트릭 카드
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor, width: 0.5),
                      ),
                      child: Column(children: [
                        Row(children: [
                          const Text('🔥', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${userData.streak}일 연속 출석',
                                style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              userData.streak >= 7 ? '대단해요! 계속 유지하세요' : '7일까지 ${7 - userData.streak}일 남음',
                              style: TextStyle(color: context.textSecondary, fontSize: 12),
                            ),
                          ]),
                        ]),
                        _StreakMilestone(streak: userData.streak),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 오늘의 목표
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('오늘의 목표',
                            style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                        GestureDetector(
                          onTap: () => mainNavKey.currentState?.switchTab(1),
                          child: Text('전체 보기 →',
                              style: TextStyle(color: context.textSecondary, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                    ...todayGoals.take(3).map((g) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _GoalItem(goal: g, onComplete: () => app.completeGoal(g.id)),
                    )),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context,
                          SlideUpRoute(page: const AddGoalScreen())),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.borderColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text('+ 목표 추가',
                            style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w500))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 집중 모드 카드
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('집중 모드',
                                style: TextStyle(color: context.textSecondary, fontSize: 11, letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text('휴대폰 안쓰기',
                                style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('10분당 +50 XP 획득',
                                style: TextStyle(color: context.textSecondary, fontSize: 12)),
                          ]),
                          GestureDetector(
                            onTap: () => mainNavKey.currentState?.switchTab(2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                  color: context.primaryColor,
                                  borderRadius: BorderRadius.circular(99)),
                              child: Text('시작',
                                  style: TextStyle(
                                      color: context.isDark ? Colors.black : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_logoutModal)
            _LogoutModal(
              onCancel: () => setState(() => _logoutModal = false),
              onConfirm: () async {
                setState(() => _logoutModal = false);
                await app.signOut();
              },
            ),

          if (app.levelUpTo != null)
            LevelUpModal(level: app.levelUpTo!, onClose: () => app.dismissLevelUp()),

          if (app.showAttendModal)
            AttendanceModal(onClose: () => app.dismissAttendModal()),

          if (app.streakModalType != null)
            StreakModal(type: app.streakModalType!, onClose: () => app.dismissStreakModal()),
        ],
      ),
    );
  }

  String _levelTitle(int level) {
    const prefixes = ['', '새내기', '성장하는', '도전하는', '달리는', '노력하는',
        '빛나는', '도약하는', '질주하는', '각성한', '눈뜬'];
    final prefix = level <= 10 ? prefixes[level] : '';
    final title = level >= 20 ? '전설의 모험가'
        : level >= 15 ? '영웅'
        : level >= 10 ? '탐험가'
        : level >= 6  ? '학자'
        : level >= 3  ? '전사'
        : '초보 모험가';
    return '$prefix $title'.trim();
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
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
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
        Text('🎁 특별 보상까지',
            style: TextStyle(color: context.textSecondary, fontSize: 11)),
        Text('$next일 (${next - streak}일 남음)',
            style: TextStyle(color: context.textSecondary, fontSize: 11)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 5,
          backgroundColor: context.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
        ),
      ),
    ]);
  }
}

class _GoalItem extends StatefulWidget {
  final dynamic goal;
  final VoidCallback onComplete;
  const _GoalItem({required this.goal, required this.onComplete});

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
    final tagColor = widget.goal.type == 'short'
        ? const Color(0xFF1b8a5a)
        : widget.goal.type == 'mid'
            ? const Color(0xFFf9a825)
            : const Color(0xFF3949ab);
    final tagLabel = widget.goal.type == 'short' ? '단기'
        : widget.goal.type == 'mid' ? '중기' : '장기';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: widget.goal.done ? 0.6 : 1.0,
      child: TapScale(
        onTap: widget.goal.done ? null : widget.onComplete,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.goal.done ? context.primaryColor : Colors.transparent,
                border: widget.goal.done ? null : Border.all(color: context.borderColor, width: 1.5),
              ),
              child: widget.goal.done
                  ? Icon(Icons.check,
                      color: context.isDark ? Colors.black : Colors.white, size: 13)
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
                        color: widget.goal.done ? context.textSecondary : context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: widget.goal.done ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                      child: Text(widget.goal.title),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(tagLabel,
                        style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: (widget.goal.progress ?? 0) / 100),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (_, value, __) => LinearProgressIndicator(
                          value: value,
                          minHeight: 4,
                          backgroundColor: context.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${widget.goal.progress ?? 0}%',
                      style: TextStyle(color: context.textSecondary, fontSize: 11)),
                ]),
              ]),
            ),
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: widget.goal.done ? const Color(0xFF1b8a5a) : context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              child: Text('+${widget.goal.xp} XP'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LogoutModal extends StatelessWidget {
  final VoidCallback onCancel, onConfirm;
  const _LogoutModal({required this.onCancel, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: context.modalBg, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('로그아웃',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
            const SizedBox(height: 8),
            Text('로그아웃 하시겠습니까?',
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: onCancel,
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                        color: context.subtleBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('취소',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: onConfirm,
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                        color: context.primaryColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('로그아웃',
                        style: TextStyle(
                            color: context.isDark ? Colors.black : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)))))),
            ]),
          ]),
        ),
      )),
    );
  }
}