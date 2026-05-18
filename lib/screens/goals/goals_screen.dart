import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../utils/transitions.dart';
import '../../providers/app_provider.dart';
import '../../models/goal_model.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/level_up_modal.dart' hide mainNavKey;
import 'package:shared_preferences/shared_preferences.dart';
import 'add_goal_screen.dart';

const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

String _toDateStr(int y, int m, int d) =>
    '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

List<int?> _calendarDays(int year, int month) {
  final firstDay = DateTime(year, month, 1).weekday % 7;
  final lastDate = DateTime(year, month + 1, 0).day;
  return [...List.filled(firstDay, null), ...List.generate(lastDate, (i) => i + 1)];
}

// 해당 월 달력이 몇 주(행)인지 계산 — 5주 또는 6주
int _calendarRowCount(int year, int month) {
  final totalCells = _calendarDays(year, month).length;
  return (totalCells / 7).ceil();
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
  String _sort = 'recent';
  Map<String, String> _holidays = {};
  Map<String, dynamic>? _deleteModal;

  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _loadSortPref();
    _loadHolidays();
    final now = DateTime.now();
    // 현재 년월을 페이지 인덱스로 변환 — year * 12 + (month - 1)
    final initialPage = now.year * 12 + (now.month - 1);
    _pageCtrl = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSortPref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('goals_sort') ?? 'recent';
    if (mounted) setState(() => _sort = saved);
  }

  Future<void> _loadHolidays() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('holidays_${now.year}');
    await prefs.remove('holidays_${now.year + 1}');
    final h1 = await _HolidayService.getHolidays(now.year);
    final h2 = await _HolidayService.getHolidays(now.year + 1);
    if (mounted) setState(() => _holidays = {...h1, ...h2});
  }

  Future<void> _saveSortPref(String sort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goals_sort', sort);
  }

  String get _todayStr => _toDateStr(_today.year, _today.month, _today.day);

  // 페이지 인덱스 → DateTime 변환
  DateTime _pageToDate(int page) {
    final year = page ~/ 12;
    final month = page % 12 + 1;
    return DateTime(year, month);
  }

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
      // 반복 목표 — 전체/하나만 선택 모달
      setState(() => _deleteModal = {'goalId': goal.id, 'repeatInfo': info});
    } else {
      // 단일 목표도 삭제 확인 모달 표시
      setState(() => _deleteModal = {'goalId': goal.id, 'repeatInfo': null});
    }
  }

  bool _willAllDone(GoalModel g, List<GoalModel> allGoals) {
    if (g.repeatId == null) return false;
    final repeatGoals = allGoals.where((r) => r.repeatId == g.repeatId).toList();
    return repeatGoals.where((r) => r.id != g.id).every((r) => r.done);
  }

  Future<void> _showYearMonthPicker() async {
    int pickerYear = _viewYear;
    int pickerMonth = _viewMonth;
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                onPressed: () => setModal(() => pickerYear--),
                icon: Icon(Icons.chevron_left, color: ctx.textSecondary),
              ),
              Text('$pickerYear년', style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w600, color: ctx.textPrimary)),
              IconButton(
                onPressed: () => setModal(() => pickerYear++),
                icon: Icon(Icons.chevron_right, color: ctx.textSecondary),
              ),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true, crossAxisCount: 4,
              childAspectRatio: 2.0, mainAxisSpacing: 8, crossAxisSpacing: 8,
              children: List.generate(12, (i) {
                final m = i + 1;
                final isSelected = m == pickerMonth && pickerYear == _viewYear;
                return GestureDetector(
                  onTap: () {
                    setModal(() => pickerMonth = m);
                    Navigator.pop(ctx);
                    final targetPage = pickerYear * 12 + (m - 1);
                    _pageCtrl.jumpToPage(targetPage);
                    setState(() { _viewYear = pickerYear; _viewMonth = m; });
                    _HolidayService.getHolidays(pickerYear).then((h) {
                      if (mounted) setState(() => _holidays = {..._holidays, ...h});
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected ? ctx.primaryColor : ctx.subtleBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('$m월', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: isSelected ? ctx.onPrimary : ctx.textPrimary))),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final goals = app.goals;
    final _filteredGoals = _goalsForDate(goals, _selectedDate).where((g) {
      if (_filter == 'active') return !g.done;
      if (_filter == 'done') return g.done;
      return true;
    }).toList();
    _filteredGoals.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (_sort == 'alpha') return a.title.compareTo(b.title);
      final at = a.createdAt ?? DateTime(0);
      final bt = b.createdAt ?? DateTime(0);
      return bt.compareTo(at);
    });
    final selectedGoals = _filteredGoals;
    final doneCount = goals.where((g) => g.done).length;
    final activeCount = goals.where((g) => !g.done).length;

    // 오늘이면 날짜 (오늘) 형식
    final dateFormatted = _selectedDate.replaceAll('-', '.');
    final dateHeader = _selectedDate == _todayStr ? '$dateFormatted (오늘)' : dateFormatted;
    // 공휴일 이름
    final holidayName = _holidays[_selectedDate];

    // 4번: 선택된 날짜의 목표 완료도 계산
    final allGoalsForDate = _goalsForDate(goals, _selectedDate);
    final dateTotal = allGoalsForDate.length;
    final dateDone = allGoalsForDate.where((g) => g.done).length;
    final dateActive = dateTotal - dateDone;
    final datePct = dateTotal == 0 ? 0 : (dateDone / dateTotal * 100).round();

    // 현재 보이는 달의 행 수 계산 — 5주 또는 6주
    final rowCount = _calendarRowCount(_viewYear, _viewMonth);
    // 셀 높이 × 행 수 + 하단 패딩 — 6주 달도 잘리지 않게 동적 계산
    const cellHeight = 46.0;
    final calendarHeight = cellHeight * rowCount + 12;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('목표', style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w600, color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Text('진행 중 ${activeCount}개 · 완료 ${doneCount}개',
                        style: TextStyle(fontSize: 13, color: context.textSecondary)),
                  ]),
                  TapScale(
                    onTap: () => Navigator.push(context,
                        SlideUpRoute(page: AddGoalScreen(initialDate: _selectedDate))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: context.primaryColor,
                          borderRadius: BorderRadius.circular(99)),
                      child: Text('+ 추가', style: TextStyle(color: context.onPrimary,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // 달력 — PageView 좌우 스와이프
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor, width: 0.5)),
                  child: Column(children: [
                    // 년월 헤더 + 이전/다음 버튼
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        IconButton(
                          onPressed: () => _pageCtrl.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                          icon: Icon(Icons.chevron_left, color: context.textSecondary),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                        // 년월 터치 → 피커
                        GestureDetector(
                          onTap: _showYearMonthPicker,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('$_viewYear년 $_viewMonth월', style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600,
                                color: context.textPrimary)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 18, color: context.textSecondary),
                          ]),
                        ),
                        IconButton(
                          onPressed: () => _pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                          icon: Icon(Icons.chevron_right, color: context.textSecondary),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      ]),
                    ),
                    // 요일 헤더 — 일~토
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: List.generate(7, (i) => Expanded(
                        child: Center(child: Text(_weekDays[i], style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: i == 0 ? AppTheme.danger
                              : i == 6 ? const Color(0xFF3949ab)
                              : context.textSecondary,
                        ))),
                      ))),
                    ),
                    const SizedBox(height: 4),
                    // PageView — 월 단위 좌우 스와이프, 6주 달도 동적 높이
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: calendarHeight,
                      child: PageView.builder(
                        controller: _pageCtrl,
                        onPageChanged: (page) {
                          final dt = _pageToDate(page);
                          setState(() { _viewYear = dt.year; _viewMonth = dt.month; });
                          _HolidayService.getHolidays(dt.year).then((h) {
                            if (mounted) setState(() => _holidays = {..._holidays, ...h});
                          });
                        },
                        itemBuilder: (ctx, page) {
                          final dt = _pageToDate(page);
                          final y = dt.year;
                          final m = dt.month;
                          final calDays = _calendarDays(y, m);
                          // 이 페이지의 행 수 — 6주 달이면 6행
                          final pageRowCount = (calDays.length / 7).ceil();
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 7,
                              // 셀 높이를 행 수에 맞게 조정 — 6주 달은 셀이 약간 작아짐
                              childAspectRatio: 1 / (pageRowCount == 6 ? 1.05 : 0.95),
                              children: calDays.asMap().entries.map((e) {
                                final idx = e.key;
                                final day = e.value;
                                if (day == null) return const SizedBox();
                                final dateStr = _toDateStr(y, m, day);
                                final isTodayCell = dateStr == _todayStr;
                                final isSelected = dateStr == _selectedDate;
                                final dayGoals = _goalsForDate(goals, dateStr);
                                final hasGoals = dayGoals.isNotEmpty;
                                final allDone = hasGoals && dayGoals.every((g) => g.done);
                                final dow = idx % 7;
                                final isHoliday = _holidays.containsKey(dateStr);
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedDate = dateStr),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? context.primaryColor : Colors.transparent),
                                      child: Center(child: Text('$day', style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isTodayCell ? FontWeight.w700 : FontWeight.normal,
                                        color: isSelected ? context.onPrimary
                                            : isTodayCell ? context.primaryColor
                                            : dow == 0 || isHoliday ? AppTheme.danger
                                            : dow == 6 ? const Color(0xFF3949ab)
                                            : context.textPrimary,
                                      ))),
                                    ),
                                    // 목표 있는 날 점 표시 — 완료 여부에 따라 색상 분기
                                    Container(
                                      width: 4, height: 4,
                                      margin: const EdgeInsets.only(top: 3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: hasGoals
                                            ? (isSelected ? context.onPrimary
                                                : allDone ? const Color(0xFF1b8a5a)
                                                : const Color(0xFFf9a825))
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ]),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),

              // 날짜 + 공휴일 — 단독 줄
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dateHeader, style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: context.textPrimary)),
                  if (holidayName != null) ...[
                    const SizedBox(height: 2),
                    Text(holidayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.danger,
                            fontWeight: FontWeight.w500)),
                  ],
                  // 4번: 목표가 있을 때 진행중/완료/% 완료를 날짜 바로 아래 별도 줄에 표시
                  if (dateTotal > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '진행중 : $dateActive개  완료 : $dateDone개  $datePct% 완료',
                      style: TextStyle(
                        fontSize: 12,
                        color: datePct == 100
                            ? const Color(0xFF1b8a5a)
                            : context.textSecondary,
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 8),

              // 정렬/필터 버튼 — 별도 줄
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        border: Border.all(color: context.borderColor),
                        borderRadius: BorderRadius.circular(99)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sort, isDense: true,
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                        dropdownColor: context.surfaceColor,
                        icon: Icon(Icons.arrow_drop_down, size: 14, color: context.textSecondary),
                        items: const [
                          DropdownMenuItem(value: 'recent', child: Text('최근순')),
                          DropdownMenuItem(value: 'alpha', child: Text('가나다순')),
                        ],
                        onChanged: (v) {
                          if (v != null) { setState(() => _sort = v); _saveSortPref(v); }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...[['all', '전체'], ['active', '진행'], ['done', '완료']].map((f) =>
                    GestureDetector(
                      onTap: () => setState(() => _filter = f[0]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _filter == f[0] ? context.primaryColor : Colors.transparent,
                          border: Border.all(color: _filter == f[0]
                              ? context.primaryColor : context.borderColor),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(f[1], style: TextStyle(fontSize: 11,
                            color: _filter == f[0] ? context.onPrimary : context.textSecondary)),
                      ),
                    )
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              if (selectedGoals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Column(children: [
                    const Text('📅', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text('이 날의 목표가 없어요',
                        style: TextStyle(fontSize: 14, color: context.textSecondary)),
                    const SizedBox(height: 12),
                    TapScale(
                      onTap: () => Navigator.push(context,
                          SlideUpRoute(page: AddGoalScreen(initialDate: _selectedDate))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(border: Border.all(color: context.borderColor),
                            borderRadius: BorderRadius.circular(99)),
                        child: Text('+ 목표 추가',
                            style: TextStyle(fontSize: 13, color: context.textSecondary)),
                      ),
                    ),
                  ])),
                )
              else
                ...selectedGoals.map((g) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _GoalCard(
                    goal: g, willAllDone: _willAllDone(g, goals),
                    onComplete: () => app.completeGoal(g.id),
                    onUncomplete: () => app.uncompleteGoal(g.id),
                    onDelete: () => _handleDeleteRequest(g, app),
                    // 수정 버튼 — Firestore에서 최신 데이터 직접 조회 후 수정 화면 열기
                    onEdit: () async {
                      final uid = app.authUser?.uid;
                      if (uid == null) return;
                      final snap = await app.firestoreService.getGoalDoc(uid, g.id);
                      if (!context.mounted || snap == null) return;
                      // repeatId가 있으면 같은 반복 목표들의 날짜 범위 계산
                      if (g.repeatId != null) {
                        final repeatGoals = goals
                            .where((r) => r.repeatId == g.repeatId)
                            .map((r) => r.scheduledDate ?? '')
                            .where((d) => d.isNotEmpty)
                            .toList()..sort();
                        if (repeatGoals.isNotEmpty) {
                          snap['startDate'] = repeatGoals.first;
                          snap['endDate'] = repeatGoals.last;
                        }
                      }
                      Navigator.push(context, SlideUpRoute(
                        page: AddGoalScreen(editGoalId: g.id, editGoalData: snap),
                      ));
                    },
                    selectedDate: _selectedDate, todayStr: _todayStr,
                    showToast: app.showToast,
                  ),
                )),
            ]),
          ),
        ),

        if (_deleteModal != null)
          _DeleteModal(
            repeatInfo: _deleteModal!['repeatInfo'], // null이면 단일 목표 확인 UI
            onDeleteAll: () {
              // 반복 목표 전체 삭제
              app.removeRepeatGoals(_deleteModal!['repeatInfo']['repeatId']);
              setState(() => _deleteModal = null);
            },
            onDeleteOne: () {
              // 단일 삭제 (단일 목표 또는 반복 목표 하나만)
              app.removeGoal(_deleteModal!['goalId']);
              setState(() => _deleteModal = null);
            },
            onCancel: () => setState(() => _deleteModal = null),
          ),

        if (app.levelUpTo != null)
          LevelUpModal(level: app.levelUpTo!, onClose: () => app.dismissLevelUp()),
      ]),
    );
  }
}

class _GoalCard extends StatefulWidget {
  final GoalModel goal;
  final bool willAllDone;
  final VoidCallback onComplete, onUncomplete, onDelete;
  // onEdit은 async — DB 조회가 포함되므로 Future<void> Function() 타입
  final Future<void> Function() onEdit;
  final String selectedDate, todayStr;
  final void Function(String) showToast;
  const _GoalCard({
    required this.goal, required this.willAllDone,
    required this.onComplete, required this.onUncomplete,
    required this.onDelete, required this.onEdit,
    required this.selectedDate, required this.todayStr, required this.showToast,
  });
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
  void dispose() { _checkCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final tagColor = g.type == 'short' ? const Color(0xFF1b8a5a)
        : g.type == 'mid' ? const Color(0xFFf9a825) : const Color(0xFF3949ab);
    final tagLabel = g.type == 'short' ? '단기' : g.type == 'mid' ? '중기' : '장기';
    final isRepeat = g.repeatId != null;
    final displayXp = isRepeat ? (widget.willAllDone ? g.repeatXp + g.xp : g.repeatXp) : g.xp;

    return GestureDetector(
      onLongPress: widget.onEdit,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: g.done ? 0.65 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor, width: 0.5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  width: 24, height: 24, margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: g.done ? context.primaryColor : Colors.transparent,
                      border: g.done ? null : Border.all(color: context.borderColor, width: 1.5)),
                  child: g.done ? Icon(Icons.check, color: context.onPrimary, size: 13) : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: tagColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(isRepeat ? '반복' : tagLabel,
                          style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                            color: g.done ? context.textSecondary : context.textPrimary,
                            decoration: g.done ? TextDecoration.lineThrough : TextDecoration.none),
                        child: Text(g.title),
                      ),
                    ),
                  ]),
                  if (g.repeat != null) ...[
                    const SizedBox(height: 4),
                    Text('🔄 ${g.repeat!.type == 'daily' ? '매일'
                        : g.repeat!.type == 'weekly'
                            // 다중 요일 — days 배열 우선, 없으면 레거시 day 사용
                            ? '매주 ${(g.repeat!.days?.isNotEmpty == true ? g.repeat!.days! : [g.repeat!.day ?? 0]).map((d) => _weekDays[d]).join(', ')}요일'
                            // 다중 날짜 — dates 배열 우선, 없으면 레거시 date 사용
                            : '매달 ${(g.repeat!.dates?.isNotEmpty == true ? g.repeat!.dates! : [g.repeat!.date ?? 1]).join(', ')}일'}',
                        style: TextStyle(fontSize: 11, color: context.textSecondary)),
                  ],
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _expanded && g.desc.isNotEmpty
                        ? Padding(padding: const EdgeInsets.only(top: 6),
                            child: Text(g.desc, style: TextStyle(fontSize: 13,
                                color: context.textSecondary, height: 1.6)))
                        : const SizedBox(),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: g.progress / 100),
                        duration: const Duration(milliseconds: 600), curve: Curves.easeOut,
                        builder: (_, value, __) => LinearProgressIndicator(
                            value: value, minHeight: 4,
                            backgroundColor: context.borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Text('${g.progress}%', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // 수정 / 삭제 버튼 — 상단 우측에 나란히 배치
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: widget.onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: context.borderColor),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('수정', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                  ),
                ),
                const SizedBox(width: 4),
                TapScale(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    // 삭제 버튼 — 빨간색으로 강조
                    decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.danger.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('삭제', style: const TextStyle(fontSize: 11, color: AppTheme.danger)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // XP — 항상 표시 (완료 시 초록색)
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: g.done ? const Color(0xFF1b8a5a) : context.textSecondary),
                child: Text('+$displayXp XP'),
              ),
              // 취소는 왼쪽 원형 체크 버튼으로 대체 — 별도 취소 버튼 없음
            ]),
          ]),
        ),
      ),
    );
  }
}

class _DeleteModal extends StatelessWidget {
  // repeatInfo가 null이면 단일 목표 삭제 확인 UI 표시
  final Map<String, dynamic>? repeatInfo;
  final VoidCallback onDeleteAll, onDeleteOne, onCancel;
  const _DeleteModal({required this.repeatInfo, required this.onDeleteAll,
      required this.onDeleteOne, required this.onCancel});
  @override
  Widget build(BuildContext context) {
    // 단일 목표 여부
    final isSingle = repeatInfo == null;
    return Container(
      color: Colors.black54,
      child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: context.modalBg, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isSingle ? '목표 삭제' : '반복 목표 삭제',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
            const SizedBox(height: 8),
            Text(isSingle ? '이 목표를 삭제하시겠습니까?' : '반복 목표를 모두 함께 삭제하시겠습니까?',
                style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.6)),
            if (!isSingle) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(10)),
                child: Text('삭제되는 목표: ${repeatInfo!["undone"]}개',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ),
            ],
            const SizedBox(height: 16),
            // 단일 목표는 '삭제', 반복 목표는 '모두 삭제'
            _ModalBtn(label: isSingle ? '삭제' : '모두 삭제',
                color: AppTheme.danger, textColor: Colors.white,
                onTap: isSingle ? onDeleteOne : onDeleteAll),
            if (!isSingle) ...[
              const SizedBox(height: 8),
              _ModalBtn(label: '하나만 삭제', onTap: onDeleteOne),
            ],
            const SizedBox(height: 8),
            _ModalBtn(label: '취소', onTap: onCancel),
          ]),
        ),
      )),
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
            border: color == null ? Border.all(color: context.borderColor) : null,
            borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.w500, color: textColor ?? context.textPrimary))),
      ),
    );
  }
}

// 한국 공휴일 서비스 — 날짜→이름 맵, SharedPreferences 캐시 + 병렬 호출
class _HolidayService {
  static const _apiKey = '0f8987c04c97c0fd409d53ffb3912016bdc591bcc782b0523565edc9f7edcd72';
  static final Map<int, Map<String, String>> _memCache = {};

  static Future<Map<String, String>> getHolidays(int year) async {
    if (_memCache.containsKey(year)) return _memCache[year]!;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'holidays_v2_$year';
    final cached = prefs.getStringList(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      final result = <String, String>{};
      for (final s in cached) {
        final parts = s.split('|');
        if (parts.length == 2) result[parts[0]] = parts[1];
      }
      _memCache[year] = result;
      return result;
    }
    final holidays = <String, String>{};
    try {
      final futures = List.generate(12, (i) async {
        final month = i + 1;
        final mm = month.toString().padLeft(2, '0');
        final url = Uri.parse(
          'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo'
          '?serviceKey=$_apiKey&solYear=$year&solMonth=$mm&numOfRows=50&_type=json',
        );
        try {
          final res = await http.get(url).timeout(const Duration(seconds: 10));
          if (res.statusCode != 200) return <String, String>{};
          final data = jsonDecode(res.body);
          final items = data['response']?['body']?['items'];
          if (items == null || items == '') return <String, String>{};
          final itemList = items['item'];
          if (itemList == null) return <String, String>{};
          final list = itemList is List ? itemList : [itemList];
          final result = <String, String>{};
          for (final item in list) {
            final locdate = item['locdate']?.toString();
            final dateName = item['dateName']?.toString() ?? '';
            if (locdate != null && locdate.length == 8) {
              result['${locdate.substring(0,4)}-${locdate.substring(4,6)}-${locdate.substring(6,8)}'] = dateName;
            }
          }
          return result;
        } catch (_) { return <String, String>{}; }
      });
      final results = await Future.wait(futures);
      for (final r in results) holidays.addAll(r);
      await prefs.setStringList(cacheKey,
          holidays.entries.map((e) => '${e.key}|${e.value}').toList());
    } catch (e) { debugPrint('[Holiday] error: $e'); }
    _memCache[year] = holidays;
    return holidays;
  }
}