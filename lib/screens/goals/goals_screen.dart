import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../utils/transitions.dart';
import '../../providers/app_provider.dart';
import '../../models/goal_model.dart';
import '../../widgets/tap_scale.dart';
import 'add_goal_screen.dart';

const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

String _toDateStr(int y, int m, int d) =>
    '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

List<int?> _calendarDays(int year, int month) {
  final firstDay = DateTime(year, month, 1).weekday % 7;
  final lastDate = DateTime(year, month + 1, 0).day;
  return [
    ...List.filled(firstDay, null),
    ...List.generate(lastDate, (i) => i + 1),
  ];
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _today = DateTime.now();
  late int _viewYear = DateTime.now().year;
  late int _viewMonth = DateTime.now().month;
  late String _selectedDate = _toDateStr(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _filter = 'all';
  Map<String, dynamic>? _deleteModal;

  String get _todayStr => _toDateStr(_today.year, _today.month, _today.day);

  List<GoalModel> _goalsForDate(List<GoalModel> goals, String dateStr) {
    return goals.where((g) {
      if (g.scheduledDate != null) return g.scheduledDate == dateStr;
      if (g.createdAt != null) {
        final d = g.createdAt!;
        return _toDateStr(d.year, d.month, d.day) == dateStr;
      }
      return false;
    }).toList();
  }

  void _handleDeleteRequest(GoalModel goal, AppProvider app) {
    final info = app.getRepeatInfo(goal.id);
    if (info != null) {
      setState(() => _deleteModal = {'goalId': goal.id, 'repeatInfo': info});
    } else {
      app.removeGoal(goal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final goals = app.goals;
    final calDays = _calendarDays(_viewYear, _viewMonth);
    final selectedGoals = _goalsForDate(goals, _selectedDate).where((g) {
      if (_filter == 'active') return !g.done;
      if (_filter == 'done') return g.done;
      return true;
    }).toList();
    final doneCount = goals.where((g) => g.done).length;
    final activeCount = goals.where((g) => !g.done).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('목표', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          Text('진행 중 ${activeCount}개 · 완료 ${doneCount}개',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ]),
                        TapScale(
                          onTap: () => Navigator.push(context,
                              SlideUpRoute(page: AddGoalScreen(initialDate: _selectedDate))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(99)),
                            child: const Text('+ 추가', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 캘린더
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                      ),
                      child: Column(children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => setState(() {
                                if (_viewMonth == 1) { _viewYear--; _viewMonth = 12; }
                                else _viewMonth--;
                              }),
                              icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Text('$_viewYear년 $_viewMonth월',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            IconButton(
                              onPressed: () => setState(() {
                                if (_viewMonth == 12) { _viewYear++; _viewMonth = 1; }
                                else _viewMonth++;
                              }),
                              icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(7, (i) => Expanded(
                            child: Center(
                              child: Text(_weekDays[i],
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w500,
                                    color: i == 0 ? AppTheme.danger : i == 6 ? const Color(0xFF3949ab) : AppTheme.textSecondary,
                                  )),
                            ),
                          )),
                        ),
                        const SizedBox(height: 6),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 7,
                          childAspectRatio: 1,
                          children: calDays.asMap().entries.map((e) {
                            final idx = e.key;
                            final day = e.value;
                            if (day == null) return const SizedBox();
                            final dateStr = _toDateStr(_viewYear, _viewMonth, day);
                            final isToday = dateStr == _todayStr;
                            final isSelected = dateStr == _selectedDate;
                            final dayGoals = _goalsForDate(goals, dateStr);
                            final hasGoals = dayGoals.isNotEmpty;
                            final allDone = hasGoals && dayGoals.every((g) => g.done);
                            final dow = idx % 7;

                            return GestureDetector(
                              onTap: () => setState(() => _selectedDate = dateStr),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? AppTheme.primary : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Text('$day',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                                            color: isSelected ? Colors.white
                                                : isToday ? AppTheme.primary
                                                : dow == 0 ? AppTheme.danger
                                                : dow == 6 ? const Color(0xFF3949ab)
                                                : AppTheme.textPrimary,
                                          )),
                                    ),
                                  ),
                                  if (hasGoals)
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 4, height: 4,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? Colors.white
                                            : allDone ? const Color(0xFF1b8a5a)
                                            : const Color(0xFFf9a825),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == _todayStr ? '오늘 목표' : _selectedDate.replaceAll('-', '.'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                        ),
                        Row(
                          children: [['all', '전체'], ['active', '진행'], ['done', '완료']].map((f) =>
                            GestureDetector(
                              onTap: () => setState(() => _filter = f[0]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _filter == f[0] ? AppTheme.primary : Colors.transparent,
                                  border: Border.all(color: _filter == f[0] ? AppTheme.primary : AppTheme.border),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(f[1], style: TextStyle(
                                    fontSize: 11,
                                    color: _filter == f[0] ? Colors.white : AppTheme.textSecondary)),
                              ),
                            )
                          ).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (selectedGoals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(children: [
                          const Text('📅', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          const Text('이 날의 목표가 없어요',
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          TapScale(
                            onTap: () => Navigator.push(context,
                                SlideUpRoute(page: AddGoalScreen(initialDate: _selectedDate))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(99)),
                              child: const Text('+ 목표 추가', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ),
                          ),
                        ]),
                      ),
                    )
                  else
                    ...selectedGoals.map((g) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _GoalCard(
                        goal: g,
                        onComplete: () => app.completeGoal(g.id),
                        onUncomplete: () => app.uncompleteGoal(g.id),
                        onDelete: () => _handleDeleteRequest(g, app),
                        selectedDate: _selectedDate,
                        todayStr: _todayStr,
                        showToast: app.showToast,
                      ),
                    )),
                ],
              ),
            ),
          ),

          if (_deleteModal != null)
            _DeleteModal(
              repeatInfo: _deleteModal!['repeatInfo'],
              onDeleteAll: () {
                app.removeRepeatGoals(_deleteModal!['repeatInfo']['repeatId']);
                setState(() => _deleteModal = null);
              },
              onDeleteOne: () {
                app.removeGoal(_deleteModal!['goalId']);
                setState(() => _deleteModal = null);
              },
              onCancel: () => setState(() => _deleteModal = null),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatefulWidget {
  final GoalModel goal;
  final VoidCallback onComplete, onUncomplete, onDelete;
  final String selectedDate, todayStr;
  final void Function(String) showToast;
  const _GoalCard({required this.goal, required this.onComplete, required this.onUncomplete, required this.onDelete, required this.selectedDate, required this.todayStr, required this.showToast});

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
    if (widget.goal.done) _checkCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_GoalCard old) {
    super.didUpdateWidget(old);
    if (!old.goal.done && widget.goal.done) _checkCtrl.forward();
    else if (old.goal.done && !widget.goal.done) _checkCtrl.reverse();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final tagColor = g.type == 'short' ? const Color(0xFF1b8a5a)
        : g.type == 'mid' ? const Color(0xFFf9a825)
        : const Color(0xFF3949ab);
    final tagLabel = g.type == 'short' ? '단기' : g.type == 'mid' ? '중기' : '장기';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: g.done ? 0.65 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TapScale(
              onTap: () {
                if (!g.done && widget.selectedDate.compareTo(widget.todayStr) > 0) {
                  widget.showToast('도달하지 않은 날짜의 목표는 완료 처리할 수 없어요.');
                  return;
                }
                g.done ? widget.onUncomplete() : widget.onComplete();
              },
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(_checkScale),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24, height: 24,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: g.done ? AppTheme.primary : Colors.transparent,
                    border: g.done ? null : Border.all(color: AppTheme.border, width: 1.5),
                  ),
                  child: g.done ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(tagLabel, style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500,
                            color: g.done ? AppTheme.textSecondary : AppTheme.textPrimary,
                            decoration: g.done ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                          child: Text(g.title),
                        ),
                      ),
                    ]),
                    if (g.repeat != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '🔄 ${g.repeat!.type == 'daily' ? '매일' : g.repeat!.type == 'weekly' ? '매주 ${_weekDays[g.repeat!.day ?? 0]}요일' : '매달 ${g.repeat!.date}일'}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _expanded && g.desc.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(g.desc, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: g.progress / 100),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            builder: (_, value, __) => LinearProgressIndicator(
                              value: value,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFE0E0E0),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${g.progress}%', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: g.done ? const Color(0xFF1b8a5a) : AppTheme.textSecondary,
                  ),
                  child: Text('+${g.xp} XP'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  if (g.done)
                    TapScale(
                      onTap: widget.onUncomplete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(6)),
                        child: const Text('취소', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ),
                    ),
                  const SizedBox(width: 6),
                  TapScale(
                    onTap: widget.onDelete,
                    child: const Text('×', style: TextStyle(fontSize: 18, color: AppTheme.border)),
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteModal extends StatelessWidget {
  final Map<String, dynamic> repeatInfo;
  final VoidCallback onDeleteAll, onDeleteOne, onCancel;
  const _DeleteModal({required this.repeatInfo, required this.onDeleteAll, required this.onDeleteOne, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('반복 목표 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('반복 목표를 모두 함께 삭제하시겠습니까?',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(10)),
                  child: Text('삭제되는 목표: ${repeatInfo['undone']}개',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 16),
                _ModalBtn(label: '모두 삭제', color: AppTheme.danger, textColor: Colors.white, onTap: onDeleteAll),
                const SizedBox(height: 8),
                _ModalBtn(label: '하나만 삭제', onTap: onDeleteOne),
                const SizedBox(height: 8),
                _ModalBtn(label: '취소', textColor: AppTheme.textSecondary, onTap: onCancel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalBtn extends StatelessWidget {
  final String label;
  final Color? color, textColor;
  final VoidCallback onTap;
  const _ModalBtn({required this.label, this.color, this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          border: color == null ? Border.all(color: AppTheme.border) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(label,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                color: textColor ?? AppTheme.textPrimary))),
      ),
    );
  }
}