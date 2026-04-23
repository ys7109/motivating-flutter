import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';

const _xpMap = {
  'short': [30, 50, 80],
  'mid': [200, 350, 500],
  'long': [800, 1500, 2500],
};
const _xpLabel = ['소', '중', '대'];
const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

class AddGoalScreen extends StatefulWidget {
  final String? initialDate;
  const AddGoalScreen({super.key, this.initialDate});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'short';
  int _xpIdx = 1;
  bool _titleError = false;
  bool _saving = false;

  String _repeatType = 'none';
  int _repeatDay = 1;
  int _repeatDate = 1;
  String _startDate = '';
  String _endDate = '';

  bool _alarmEnabled = false;
  String _alarmAmPm = '오전';
  int _alarmHour = 9;
  int _alarmMin = 0;
  bool _showAlarmPicker = false;

  late String _scheduledDate;
  bool _showDatePicker = false;
  bool _showStartPicker = false;
  bool _showEndPicker = false;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _scheduledDate = widget.initialDate ??
        '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  int get _xp => _xpMap[_type]![_xpIdx];

  String get _alarmDisplay {
    final h = _alarmHour.toString().padLeft(2, '0');
    final m = _alarmMin.toString().padLeft(2, '0');
    return '$_alarmAmPm $h:$m';
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _titleError = true);
      context.read<AppProvider>().showToast('목표 제목을 입력하세요.');
      return;
    }
    setState(() { _titleError = false; _saving = true; });

    try {
      final app = context.read<AppProvider>();
      final uid = app.authUser!.uid;

      if (_repeatType == 'none') {
        await app.firestoreService.addGoal(uid, {
          'title': _titleCtrl.text.trim(),
          'desc': _descCtrl.text.trim(),
          'type': _type,
          'xp': _xp,
          'scheduledDate': _scheduledDate,
        });
      } else {
        if (_startDate.isEmpty || _endDate.isEmpty) {
          app.showToast('시작일과 종료일을 설정해주세요.');
          setState(() => _saving = false);
          return;
        }
        final repeatId = DateTime.now().millisecondsSinceEpoch.toString();
        final dates = _generateDates();
        for (final date in dates) {
          await app.firestoreService.addGoal(uid, {
            'title': _titleCtrl.text.trim(),
            'desc': _descCtrl.text.trim(),
            'type': _type,
            'xp': _xp,
            'scheduledDate': date,
            'repeatId': repeatId,
            'repeat': {
              'type': _repeatType,
              if (_repeatType == 'weekly') 'day': _repeatDay,
              if (_repeatType == 'monthly') 'date': _repeatDate,
            },
          });
        }
      }
      await app.loadGoals();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _generateDates() {
    final dates = <String>[];
    final start = _parseDate(_startDate);
    final end = _parseDate(_endDate);
    var cur = start;
    while (!cur.isAfter(end)) {
      bool match = false;
      if (_repeatType == 'daily') match = true;
      else if (_repeatType == 'weekly') match = cur.weekday % 7 == _repeatDay;
      else if (_repeatType == 'monthly') match = cur.day == _repeatDate;
      if (match) dates.add(_formatDate(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return dates;
  }

  DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final typeConfig = {
      'short': {'label': '단기', 'sub': '1주 ~ 1개월', 'color': const Color(0xFF2e7d32)},
      'mid':   {'label': '중기', 'sub': '1~6개월',     'color': const Color(0xFFf57f17)},
      'long':  {'label': '장기', 'sub': '6개월 이상',   'color': const Color(0xFF3949ab)},
    };

    return Scaffold(
      backgroundColor: context.bgColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.close, color: context.textSecondary),
                          ),
                          Text('목표 추가', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.textPrimary)),
                          GestureDetector(
                            onTap: _saving ? null : _submit,
                            child: _saving
                                ? SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: context.primaryColor))
                                : Text('저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.primaryColor)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제목
                            Text('목표 제목', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                            const SizedBox(height: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                border: Border.all(color: _titleError ? AppTheme.danger : context.borderColor, width: _titleError ? 1.5 : 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _titleCtrl,
                                maxLength: 50,
                                style: TextStyle(fontSize: 15, color: context.textPrimary),
                                decoration: InputDecoration(
                                  hintText: '예: 매일 아침 30분 독서',
                                  hintStyle: TextStyle(color: context.textSecondary),
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onChanged: (_) { if (_titleError) setState(() => _titleError = false); },
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('${_titleCtrl.text.length}/50',
                                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
                            ),
                            const SizedBox(height: 20),

                            // 설명
                            Text('상세 설명 (선택)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                border: Border.all(color: context.borderColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _descCtrl,
                                maxLines: 3,
                                style: TextStyle(fontSize: 14, color: context.textPrimary),
                                decoration: InputDecoration(
                                  hintText: '구체적인 계획이나 메모를 남겨보세요',
                                  hintStyle: TextStyle(color: context.textSecondary),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 목표 유형
                            Text('목표 유형', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                            const SizedBox(height: 10),
                            Row(
                              children: ['short', 'mid', 'long'].map((t) {
                                final cfg = typeConfig[t]!;
                                final isSelected = _type == t;
                                final color = cfg['color'] as Color;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() { _type = t; _xpIdx = 1; }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? color.withOpacity(0.1) : context.subtleBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isSelected ? color : context.borderColor, width: isSelected ? 1.5 : 1),
                                      ),
                                      child: Column(children: [
                                        Text(cfg['label'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? color : context.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(cfg['sub'] as String, style: TextStyle(fontSize: 10, color: isSelected ? color : context.textSecondary)),
                                      ]),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // 난이도
                            Text('난이도 (획득 XP)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                            const SizedBox(height: 10),
                            Row(
                              children: List.generate(3, (i) {
                                final xpVal = _xpMap[_type]![i];
                                final isSelected = _xpIdx == i;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _xpIdx = i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? context.primaryColor : context.surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isSelected ? context.primaryColor : context.borderColor, width: isSelected ? 2 : 1),
                                      ),
                                      child: Column(children: [
                                        Text(_xpLabel[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                            color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text('+$xpVal XP', style: TextStyle(fontSize: 12,
                                            color: isSelected ? (context.isDark ? Colors.black54 : Colors.white70) : context.textSecondary)),
                                      ]),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20),

                            // 반복 설정
                            Text('반복 설정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: [
                                ['none', '반복 안 함'],
                                ['daily', '매일'],
                                ['weekly', '매주'],
                                ['monthly', '매달'],
                              ].map((t) {
                                final isSelected = _repeatType == t[0];
                                return GestureDetector(
                                  onTap: () => setState(() => _repeatType = t[0]),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected ? context.primaryColor : context.subtleBg,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(t[1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                        color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary)),
                                  ),
                                );
                              }).toList(),
                            ),

                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              child: _repeatType != 'none' ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(14)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    if (_repeatType == 'weekly') ...[
                                      Text('반복 요일', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: List.generate(7, (i) {
                                          final isSelected = _repeatDay == i;
                                          return Expanded(
                                            child: GestureDetector(
                                              onTap: () => setState(() => _repeatDay = i),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 150),
                                                margin: const EdgeInsets.only(right: 4),
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isSelected ? context.primaryColor : context.borderColor,
                                                ),
                                                child: Center(child: Text(_weekDays[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                                    color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary))),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    if (_repeatType == 'monthly') ...[
                                      Text('반복 날짜', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6, runSpacing: 6,
                                        children: List.generate(31, (i) {
                                          final d = i + 1;
                                          final isSelected = _repeatDate == d;
                                          return GestureDetector(
                                            onTap: () => setState(() => _repeatDate = d),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              width: 36, height: 36,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: isSelected ? context.primaryColor : context.borderColor,
                                              ),
                                              child: Center(child: Text('$d', style: TextStyle(fontSize: 12,
                                                  color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary))),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('* 해당 날짜가 없는 달은 마지막 날에 생성됩니다',
                                          style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                      const SizedBox(height: 14),
                                    ],

                                    Row(children: [
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('시작일', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () => setState(() => _showStartPicker = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(color: context.surfaceColor, border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(10)),
                                            child: Text(_startDate.isEmpty ? '날짜 선택' : _startDate,
                                                style: TextStyle(fontSize: 13, color: _startDate.isEmpty ? context.textSecondary : context.textPrimary)),
                                          ),
                                        ),
                                      ])),
                                      const SizedBox(width: 8),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('종료일', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () => setState(() => _showEndPicker = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(color: context.surfaceColor, border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(10)),
                                            child: Text(_endDate.isEmpty ? '날짜 선택' : _endDate,
                                                style: TextStyle(fontSize: 13, color: _endDate.isEmpty ? context.textSecondary : context.textPrimary)),
                                          ),
                                        ),
                                      ])),
                                    ]),
                                    if (_startDate.isNotEmpty && _endDate.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('📅 $_startDate ~ $_endDate 기간 내 생성',
                                          style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                    ],
                                  ]),
                                ),
                              ) : const SizedBox(),
                            ),
                            const SizedBox(height: 20),

                            // 단일 날짜
                            if (_repeatType == 'none') ...[
                              Text('날짜', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => setState(() => _showDatePicker = true),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: context.subtleBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: context.borderColor),
                                  ),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text(_scheduledDate.replaceAll('-', '.'),
                                        style: TextStyle(fontSize: 15, color: context.textPrimary)),
                                    Icon(Icons.calendar_today_outlined, size: 18, color: context.textSecondary),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // 알림
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('목표 알림', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                              GestureDetector(
                                onTap: () => setState(() => _alarmEnabled = !_alarmEnabled),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44, height: 26,
                                  decoration: BoxDecoration(
                                    color: _alarmEnabled ? context.primaryColor : context.borderColor,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: _alarmEnabled ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(margin: const EdgeInsets.all(3), width: 20, height: 20,
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                                  ),
                                ),
                              ),
                            ]),

                            if (_alarmEnabled) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => setState(() => _showAlarmPicker = true),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: context.subtleBg,
                                    border: Border.all(color: context.borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(child: Text('🔔 $_alarmDisplay',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: context.textPrimary))),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // XP 미리보기
                            Container(
                              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                              decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('달성 시 획득 XP', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text('+$_xp XP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                  if (_repeatType != 'none') ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '🔄 ${_repeatType == 'daily' ? '매일' : _repeatType == 'weekly' ? '매주 ${_weekDays[_repeatDay]}요일' : '매달 ${_repeatDate}일'}'
                                      '${_startDate.isNotEmpty && _endDate.isNotEmpty ? ' ($_startDate~$_endDate)' : ''}',
                                      style: TextStyle(fontSize: 11, color: context.textSecondary),
                                    ),
                                  ],
                                  if (_alarmEnabled)
                                    Text('🔔 $_alarmDisplay 알림',
                                        style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (_type == 'short' ? const Color(0xFF2e7d32) : _type == 'mid' ? const Color(0xFFf57f17) : const Color(0xFF3949ab)).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: _type == 'short' ? const Color(0xFF2e7d32) : _type == 'mid' ? const Color(0xFFf57f17) : const Color(0xFF3949ab)),
                                  ),
                                  child: Text(
                                    _type == 'short' ? '단기' : _type == 'mid' ? '중기' : '장기',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                        color: _type == 'short' ? const Color(0xFF2e7d32) : _type == 'mid' ? const Color(0xFFf57f17) : const Color(0xFF3949ab)),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 20),

                            // 저장 버튼
                            GestureDetector(
                              onTap: _saving ? null : _submit,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: context.primaryColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(child: _saving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('목표 추가하기', style: TextStyle(
                                        color: context.isDark ? Colors.black : Colors.white,
                                        fontSize: 16, fontWeight: FontWeight.w600))),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (_showDatePicker)
                  _DrumDatePicker(
                    title: '날짜 선택', value: _scheduledDate,
                    onConfirm: (date) => setState(() { _scheduledDate = date; _showDatePicker = false; }),
                    onClose: () => setState(() => _showDatePicker = false),
                  ),
                if (_showStartPicker)
                  _DrumDatePicker(
                    title: '시작일', value: _startDate.isEmpty ? _scheduledDate : _startDate,
                    onConfirm: (date) => setState(() { _startDate = date; _showStartPicker = false; }),
                    onClose: () => setState(() => _showStartPicker = false),
                  ),
                if (_showEndPicker)
                  _DrumDatePicker(
                    title: '종료일', value: _endDate.isEmpty ? _scheduledDate : _endDate,
                    onConfirm: (date) => setState(() { _endDate = date; _showEndPicker = false; }),
                    onClose: () => setState(() => _showEndPicker = false),
                  ),
                if (_showAlarmPicker)
                  _AlarmPicker(
                    amPm: _alarmAmPm, hour: _alarmHour, min: _alarmMin,
                    onConfirm: (amPm, hour, min) => setState(() {
                      _alarmAmPm = amPm; _alarmHour = hour; _alarmMin = min;
                      _showAlarmPicker = false;
                    }),
                    onClose: () => setState(() => _showAlarmPicker = false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrumDatePicker extends StatefulWidget {
  final String title, value;
  final ValueChanged<String> onConfirm;
  final VoidCallback onClose;
  const _DrumDatePicker({required this.title, required this.value, required this.onConfirm, required this.onClose});

  @override
  State<_DrumDatePicker> createState() => _DrumDatePickerState();
}

class _DrumDatePickerState extends State<_DrumDatePicker> {
  late int _year, _month, _day;
  late FixedExtentScrollController _yearCtrl, _monthCtrl, _dayCtrl;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    DateTime init;
    try {
      final p = widget.value.split('-');
      init = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) { init = today; }
    _year = init.year; _month = init.month; _day = init.day;
    final yearList = List.generate(5, (i) => today.year + i);
    _yearCtrl = FixedExtentScrollController(initialItem: yearList.indexOf(_year).clamp(0, 4));
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose(); _monthCtrl.dispose(); _dayCtrl.dispose();
    super.dispose();
  }

  int get _maxDay => DateTime(_year, _month + 1, 0).day;

  void _confirm() {
    final d = _day.clamp(1, _maxDay);
    widget.onConfirm('$_year-${_month.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}');
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final years = List.generate(5, (i) => '${today.year + i}년');
    final months = List.generate(12, (i) => '${i + 1}월');
    final days = List.generate(_maxDay, (i) => '${i + 1}일');

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: BoxDecoration(color: context.modalBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  GestureDetector(onTap: widget.onClose, child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
                ]),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _DrumColumn(controller: _yearCtrl, items: years, width: 90,
                      onSelected: (i) => setState(() => _year = today.year + i)),
                  const SizedBox(width: 8),
                  _DrumColumn(controller: _monthCtrl, items: months, width: 72,
                      onSelected: (i) => setState(() { _month = i + 1; if (_day > _maxDay) _day = _maxDay; })),
                  const SizedBox(width: 8),
                  _DrumColumn(controller: _dayCtrl, items: days, width: 72,
                      onSelected: (i) => setState(() => _day = i + 1)),
                ]),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _confirm,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('확인', style: TextStyle(
                        color: context.isDark ? Colors.black : Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrumColumn extends StatelessWidget {
  final FixedExtentScrollController controller;
  final List<String> items;
  final double width;
  final ValueChanged<int> onSelected;

  const _DrumColumn({required this.controller, required this.items, required this.width, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const itemH = 52.0;
    final bgColor = context.modalBg;
    final transparent = bgColor.withOpacity(0);
    return SizedBox(
      width: width, height: itemH * 3,
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: itemH,
          child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [bgColor, transparent])))),
        Positioned(top: itemH, left: 4, right: 4, height: itemH,
          child: Container(decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: context.borderColor))))),
        Positioned(bottom: 0, left: 0, right: 0, height: itemH,
          child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [bgColor, transparent])))),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: itemH,
          perspective: 0.003,
          diameterRatio: 2.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) {
              if (index < 0 || index >= items.length) return null;
              final isSelected = controller.selectedItem == index;
              return Center(
                child: Text(items[index], style: TextStyle(
                  fontSize: 22,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                  color: isSelected ? context.textPrimary : context.textSecondary,
                )),
              );
            },
            childCount: items.length,
          ),
        ),
      ]),
    );
  }
}

class _AlarmPicker extends StatefulWidget {
  final String amPm;
  final int hour, min;
  final void Function(String, int, int) onConfirm;
  final VoidCallback onClose;
  const _AlarmPicker({required this.amPm, required this.hour, required this.min, required this.onConfirm, required this.onClose});

  @override
  State<_AlarmPicker> createState() => _AlarmPickerState();
}

class _AlarmPickerState extends State<_AlarmPicker> {
  late String _amPm;
  late int _hour, _min;
  late FixedExtentScrollController _amPmCtrl, _hourCtrl, _minCtrl;

  @override
  void initState() {
    super.initState();
    _amPm = widget.amPm; _hour = widget.hour; _min = widget.min;
    _amPmCtrl = FixedExtentScrollController(initialItem: _amPm == '오전' ? 0 : 1);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour - 1);
    _minCtrl = FixedExtentScrollController(initialItem: _min ~/ 5);
  }

  @override
  void dispose() {
    _amPmCtrl.dispose(); _hourCtrl.dispose(); _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amPmItems = ['오전', '오후'];
    final hourItems = List.generate(12, (i) => '${i + 1}');
    final minItems = List.generate(12, (i) => '${(i * 5).toString().padLeft(2,'0')}');

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: BoxDecoration(color: context.modalBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('알림 시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  GestureDetector(onTap: widget.onClose, child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
                ]),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _DrumColumn(controller: _amPmCtrl, items: amPmItems, width: 72,
                      onSelected: (i) => setState(() => _amPm = amPmItems[i])),
                  const SizedBox(width: 8),
                  _DrumColumn(controller: _hourCtrl, items: hourItems, width: 60,
                      onSelected: (i) => setState(() => _hour = i + 1)),
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(':', style: TextStyle(fontSize: 24, color: context.textSecondary))),
                  _DrumColumn(controller: _minCtrl, items: minItems, width: 60,
                      onSelected: (i) => setState(() => _min = i * 5)),
                ]),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => widget.onConfirm(_amPm, _hour, _min),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('확인', style: TextStyle(
                        color: context.isDark ? Colors.black : Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
