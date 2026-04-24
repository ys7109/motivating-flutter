import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../config.dart';
import 'goal_pickers.dart';

// 타입별 고정 XP (직접 입력)
const _fixedXp = {'short': 100, 'mid': 300, 'long': 600};
const _repeatXpFixed = 100; // 반복 1회 완료 XP
const _singleXp = 100; // 단일 목표 XP

// 날짜 차이 → 타입 자동 계산
String _calcType(String start, String end) {
  if (start.isEmpty || end.isEmpty) return 'short';
  final days = DateTime.parse(end).difference(DateTime.parse(start)).inDays;
  if (days <= 30) return 'short';
  if (days <= 180) return 'mid';
  return 'long';
}

String _typeLabel(String type) => type == 'short' ? '단기' : type == 'mid' ? '중기' : '장기';
Color _typeColor(String type) => type == 'short' ? const Color(0xFF2e7d32) : type == 'mid' ? const Color(0xFFf57f17) : const Color(0xFF3949ab);

class AddGoalScreen extends StatefulWidget {
  final String? initialDate;
  const AddGoalScreen({super.key, this.initialDate});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _titleError = false;
  bool _saving = false;

  // XP 모드: 'manual' | 'ai'
  String _xpMode = 'manual';
  int _xp = _singleXp;
  int _repeatXp = _repeatXpFixed;
  bool _aiLoading = false;
  bool _aiDone = false;
  String _aiReason = '';

  // 반복 설정
  String _repeatType = 'none';
  Set<int> _repeatDays = {1}; // 매주: 다중 선택 (0=일~6=토)
  Set<int> _repeatDates = {1}; // 매달: 다중 선택 (1~31)
  String _startDate = '';
  String _endDate = '';

  // 알림 설정
  bool _alarmEnabled = false;
  String _alarmAmPm = '오전';
  int _alarmHour = 9;
  int _alarmMin = 0;
  bool _showAlarmPicker = false;

  // 날짜 피커
  late String _scheduledDate;
  bool _showDatePicker = false;
  bool _showStartPicker = false;
  bool _showEndPicker = false;

  // 진입 애니메이션
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _scheduledDate = widget.initialDate ??
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
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

  String get _alarmDisplay {
    final h = _alarmHour.toString().padLeft(2, '0');
    final m = _alarmMin.toString().padLeft(2, '0');
    return '$_alarmAmPm $h:$m';
  }

  // 현재 타입 (반복 있으면 날짜 기반, 없으면 short)
  String get _currentType {
    if (_repeatType != 'none' && _startDate.isNotEmpty && _endDate.isNotEmpty) {
      return _calcType(_startDate, _endDate);
    }
    return 'short';
  }

  // 직접 입력 XP 업데이트
  void _updateManualXp() {
    if (_xpMode == 'manual') {
      setState(() {
        _xp = _repeatType == 'none' ? _singleXp : _fixedXp[_currentType]!;
        _repeatXp = _repeatXpFixed;
      });
    }
  }

  // Gemini API로 XP 분석
  Future<void> _analyzeXP() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      if (mounted) context.read<AppProvider>().showToast('목표 제목을 먼저 입력하세요.');
      return;
    }
    if (_repeatType != 'none' && (_startDate.isEmpty || _endDate.isEmpty)) {
      if (mounted) context.read<AppProvider>().showToast('시작일과 종료일을 먼저 설정해주세요.');
      return;
    }
    final app = context.read<AppProvider>();
    setState(() { _aiLoading = true; _aiDone = false; _titleError = false; });
    try {
      final type = _currentType;
      final typeLabel = _typeLabel(type);
      final daysInfo = (_repeatType != 'none' && _startDate.isNotEmpty && _endDate.isNotEmpty)
          ? '기간: $_startDate ~ $_endDate (${DateTime.parse(_endDate).difference(DateTime.parse(_startDate)).inDays}일)'
          : '단일 목표';
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${Config.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text':
            'You are an XP scoring expert for a goal achievement game app. '
            'Analyze the user goal and return ONLY a JSON object with no markdown. '
            'Format: {"xp": number, "repeatXp": number, "reason": "15자 이내 한국어 이유"}. '
            'xp = total bonus XP when ALL goals completed (or single goal). '
            'repeatXp = XP per one completion (short-term basis, 50~150 range). '
            'xp range by type: short(단기)=100~200, mid(중기)=200~400, long(장기)=400~800. '
            'Higher type MUST have higher xp. Consider specific difficulty.\n\n'
            '목표 유형: $typeLabel\n$daysInfo\n목표 제목: "$title"\nReturn JSON only.'
          }]}],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 200,
            'thinkingConfig': {'thinkingBudget': 0},
          },
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
        if (!clean.contains('{') || !clean.contains('}')) { _setDefaultXP(); return; }
        final jsonStr = clean.substring(clean.indexOf('{'), clean.lastIndexOf('}') + 1);
        final parsed = jsonDecode(jsonStr);
        if (mounted) setState(() {
          _xp = (parsed['xp'] as num).toInt();
          _repeatXp = (parsed['repeatXp'] as num?)?.toInt() ?? _repeatXpFixed;
          _aiReason = parsed['reason'] ?? 'AI 분석 완료';
          _aiDone = true;
        });
      } else {
        debugPrint('응답 오류: ${response.statusCode} / ${response.body}');
        app.showToast('AI 분석 실패, 기본값으로 설정됐어요');
        _setDefaultXP();
      }
    } catch (e) {
      debugPrint('에러: $e');
      _setDefaultXP();
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _setDefaultXP() {
    if (mounted) setState(() {
      _xp = _repeatType == 'none' ? _singleXp : _fixedXp[_currentType]!;
      _repeatXp = _repeatXpFixed;
      _aiReason = '기본값으로 설정됐어요';
      _aiDone = true;
    });
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _titleError = true);
      context.read<AppProvider>().showToast('목표 제목을 입력하세요.');
      return;
    }
    if (_xpMode == 'ai' && !_aiDone) {
      context.read<AppProvider>().showToast('AI 분석을 먼저 실행해주세요.');
      return;
    }
    if (_repeatType == 'weekly' && _repeatDays.isEmpty) {
      context.read<AppProvider>().showToast('반복 요일을 선택해주세요.');
      return;
    }
    if (_repeatType == 'monthly' && _repeatDates.isEmpty) {
      context.read<AppProvider>().showToast('반복 날짜를 선택해주세요.');
      return;
    }
    setState(() { _titleError = false; _saving = true; });
    try {
      final app = context.read<AppProvider>();
      final uid = app.authUser!.uid;
      final type = _currentType;
      final effectiveXp = _xpMode == 'manual'
          ? (_repeatType == 'none' ? _singleXp : _fixedXp[type]!)
          : _xp;
      final effectiveRepeatXp = _repeatType == 'none' ? effectiveXp : (_xpMode == 'manual' ? _repeatXpFixed : _repeatXp);

      if (_repeatType == 'none') {
        await app.firestoreService.addGoal(uid, {
          'title': _titleCtrl.text.trim(), 'desc': _descCtrl.text.trim(),
          'type': type, 'xp': effectiveXp, 'repeatXp': effectiveRepeatXp,
          'scheduledDate': _scheduledDate,
        });
      } else {
        if (_startDate.isEmpty || _endDate.isEmpty) {
          app.showToast('시작일과 종료일을 설정해주세요.');
          setState(() => _saving = false);
          return;
        }
        final repeatId = DateTime.now().millisecondsSinceEpoch.toString();
        final repeatData = {
          'type': _repeatType,
          if (_repeatType == 'weekly') 'days': _repeatDays.toList()..sort(),
          if (_repeatType == 'monthly') 'dates': _repeatDates.toList()..sort(),
        };
        final goalList = _generateDates().map((date) => {
          'title': _titleCtrl.text.trim(), 'desc': _descCtrl.text.trim(),
          'type': type, 'xp': effectiveXp, 'repeatXp': effectiveRepeatXp,
          'scheduledDate': date, 'repeatId': repeatId,
          'repeat': repeatData,
        }).toList();
        await app.firestoreService.addGoalsBatch(uid, goalList);
      }
      await app.loadGoals();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _generateDates() {
    final dates = <String>[];
    var cur = DateTime.parse(_startDate);
    final end = DateTime.parse(_endDate);
    while (!cur.isAfter(end)) {
      bool match = false;
      if (_repeatType == 'daily') {
        match = true;
      } else if (_repeatType == 'weekly') {
        match = _repeatDays.contains(cur.weekday % 7); // 0=일,1=월,...,6=토
      } else if (_repeatType == 'monthly') {
        match = _repeatDates.contains(cur.day);
      }
      if (match) dates.add(_fmt(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return dates;
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 반복 요일 요약 텍스트
  String get _repeatDaysText {
    if (_repeatType == 'daily') return '매일';
    if (_repeatType == 'weekly') {
      if (_repeatDays.isEmpty) return '요일 미선택';
      final sorted = _repeatDays.toList()..sort();
      return '매주 ${sorted.map((d) => weekDays[d]).join(', ')}요일';
    }
    if (_repeatType == 'monthly') {
      if (_repeatDates.isEmpty) return '날짜 미선택';
      final sorted = _repeatDates.toList()..sort();
      return '매달 ${sorted.join(', ')}일';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isRepeat = _repeatType != 'none';
    final type = _currentType;
    final tColor = _typeColor(type);
    final manualXp = isRepeat ? _fixedXp[type]! : _singleXp;
    final displayXp = _xpMode == 'manual' ? manualXp : (_aiDone ? _xp : manualXp);
    final displayRepeatXp = _xpMode == 'manual' ? _repeatXpFixed : (_aiDone ? _repeatXp : _repeatXpFixed);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Stack(children: [
              Column(children: [
                // 상단 바
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: context.textSecondary)),
                    Text('목표 추가', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.textPrimary)),
                    GestureDetector(
                      onTap: _saving ? null : _submit,
                      child: _saving
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.primaryColor))
                          : Text('저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.primaryColor)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // 제목 입력
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
                          controller: _titleCtrl, maxLength: 50,
                          style: TextStyle(fontSize: 15, color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText: '예: 매일 아침 30분 독서', hintStyle: TextStyle(color: context.textSecondary),
                            counterText: '', border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (_) {
                            if (_titleError) setState(() => _titleError = false);
                            if (_aiDone && _xpMode == 'ai') setState(() { _aiDone = false; _aiReason = ''; });
                          },
                        ),
                      ),
                      Align(alignment: Alignment.centerRight, child: Text('${_titleCtrl.text.length}/50', style: TextStyle(fontSize: 11, color: context.textSecondary))),
                      const SizedBox(height: 20),

                      // 설명 입력
                      Text('상세 설명 (선택)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(color: context.surfaceColor, border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(12)),
                        child: TextField(
                          controller: _descCtrl, maxLines: 3,
                          style: TextStyle(fontSize: 14, color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText: '구체적인 계획이나 메모를 남겨보세요', hintStyle: TextStyle(color: context.textSecondary),
                            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 반복 설정
                      Text('반복 설정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [['none', '반복 안 함'], ['daily', '매일'], ['weekly', '매주'], ['monthly', '매달']].map((t) {
                          final isSelected = _repeatType == t[0];
                          return GestureDetector(
                            onTap: () { setState(() => _repeatType = t[0]); _updateManualXp(); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: isSelected ? context.primaryColor : context.subtleBg, borderRadius: BorderRadius.circular(99)),
                              child: Text(t[1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary)),
                            ),
                          );
                        }).toList(),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: isRepeat ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(14)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                              // 매주: 요일 다중 선택
                              if (_repeatType == 'weekly') ...[
                                Text('반복 요일 (중복 선택 가능)', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                const SizedBox(height: 8),
                                Row(children: List.generate(7, (i) {
                                  final isSelected = _repeatDays.contains(i);
                                  return Expanded(child: GestureDetector(
                                    onTap: () => setState(() {
                                      if (isSelected && _repeatDays.length > 1) {
                                        _repeatDays.remove(i);
                                      } else {
                                        _repeatDays.add(i);
                                      }
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.only(right: 4), height: 36,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? context.primaryColor : context.borderColor),
                                      child: Center(child: Text(weekDays[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary))),
                                    ),
                                  ));
                                })),
                                const SizedBox(height: 14),
                              ],

                              // 매달: 날짜 다중 선택
                              if (_repeatType == 'monthly') ...[
                                Text('반복 날짜 (중복 선택 가능)', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6, runSpacing: 6,
                                  children: List.generate(31, (i) {
                                    final d = i + 1;
                                    final isSelected = _repeatDates.contains(d);
                                    return GestureDetector(
                                      onTap: () => setState(() {
                                        if (isSelected && _repeatDates.length > 1) {
                                          _repeatDates.remove(d);
                                        } else {
                                          _repeatDates.add(d);
                                        }
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: isSelected ? context.primaryColor : context.borderColor),
                                        child: Center(child: Text('$d', style: TextStyle(fontSize: 12, color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary))),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 6),
                                Text('* 해당 날짜가 없는 달은 건너뜁니다', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                const SizedBox(height: 14),
                              ],

                              // 시작일 ~ 종료일 (크게, ~ 표시)
                              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('시작일', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _showStartPicker = true),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: context.surfaceColor,
                                        border: Border.all(color: _startDate.isEmpty ? context.borderColor : context.primaryColor.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _startDate.isEmpty ? '날짜 선택' : _startDate.replaceAll('-', '.'),
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _startDate.isEmpty ? context.textSecondary : context.textPrimary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ])),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14, left: 8, right: 8),
                                  child: Text('~', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: context.textSecondary)),
                                ),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('종료일', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _showEndPicker = true),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: context.surfaceColor,
                                        border: Border.all(color: _endDate.isEmpty ? context.borderColor : context.primaryColor.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _endDate.isEmpty ? '날짜 선택' : _endDate.replaceAll('-', '.'),
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _endDate.isEmpty ? context.textSecondary : context.textPrimary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ])),
                              ]),

                              // 날짜 기반 타입 표시
                              if (_startDate.isNotEmpty && _endDate.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: tColor.withOpacity(0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: tColor)),
                                    child: Text(_typeLabel(type), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tColor)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('목표로 분류됐어요 (${DateTime.parse(_endDate).difference(DateTime.parse(_startDate)).inDays}일)', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                ]),
                              ],
                            ]),
                          ),
                        ) : const SizedBox(),
                      ),
                      const SizedBox(height: 20),

                      // 단일 날짜 선택
                      if (!isRepeat) ...[
                        Text('날짜', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() => _showDatePicker = true),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(_scheduledDate.replaceAll('-', '.'), style: TextStyle(fontSize: 15, color: context.textPrimary)),
                              Icon(Icons.calendar_today_outlined, size: 18, color: context.textSecondary),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // XP 획득 방법 선택
                      Text('XP 획득 방법', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () { setState(() { _xpMode = 'manual'; _aiDone = false; _aiReason = ''; }); _updateManualXp(); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _xpMode == 'manual' ? context.primaryColor.withOpacity(0.1) : context.subtleBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _xpMode == 'manual' ? context.primaryColor : context.borderColor, width: _xpMode == 'manual' ? 1.5 : 1),
                              ),
                              child: Column(children: [
                                Icon(Icons.edit_outlined, size: 18, color: _xpMode == 'manual' ? context.primaryColor : context.textSecondary),
                                const SizedBox(height: 4),
                                Text('직접 입력', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _xpMode == 'manual' ? context.primaryColor : context.textPrimary)),
                                const SizedBox(height: 2),
                                Text('기간별 고정 XP', style: TextStyle(fontSize: 10, color: context.textSecondary)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() { _xpMode = 'ai'; _aiDone = false; _aiReason = ''; }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _xpMode == 'ai' ? context.primaryColor.withOpacity(0.1) : context.subtleBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _xpMode == 'ai' ? context.primaryColor : context.borderColor, width: _xpMode == 'ai' ? 1.5 : 1),
                              ),
                              child: Column(children: [
                                Icon(Icons.auto_awesome, size: 18, color: _xpMode == 'ai' ? context.primaryColor : context.textSecondary),
                                const SizedBox(height: 4),
                                Text('AI 분석', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _xpMode == 'ai' ? context.primaryColor : context.textPrimary)),
                                const SizedBox(height: 2),
                                Text('목표 난이도 자동 분석', style: TextStyle(fontSize: 10, color: context.textSecondary)),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // XP 표시 영역
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.subtleBg, borderRadius: BorderRadius.circular(14),
                          border: (_xpMode == 'ai' && _aiDone) ? Border.all(color: context.primaryColor.withOpacity(0.4)) : null,
                        ),
                        child: _xpMode == 'manual'
                            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('+$displayXp', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                  const SizedBox(width: 4),
                                  Text('XP', style: TextStyle(fontSize: 16, color: context.textSecondary)),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                  isRepeat
                                      ? '1회 완료 시 +$_repeatXpFixed XP · 모든 목표 완료 시 +$displayXp XP 추가 지급'
                                      : '단일 목표 고정 XP',
                                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                                ),
                              ])
                            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (!_aiDone) ...[
                                  GestureDetector(
                                    onTap: _aiLoading ? null : _analyzeXP,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(10)),
                                      child: _aiLoading
                                          ? Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.isDark ? Colors.black : Colors.white)))
                                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                              Icon(Icons.auto_awesome, size: 14, color: context.isDark ? Colors.black : Colors.white),
                                              const SizedBox(width: 6),
                                              Text('AI로 XP 분석하기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.isDark ? Colors.black : Colors.white)),
                                            ]),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('목표 제목${isRepeat ? '과 기간' : ''}을 입력하고 AI 분석을 실행하세요', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                ] else ...[
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Row(children: [
                                      Text('+$displayXp', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                      const SizedBox(width: 4),
                                      Text('XP', style: TextStyle(fontSize: 16, color: context.textSecondary)),
                                    ]),
                                    GestureDetector(
                                      onTap: _analyzeXP,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(color: context.surfaceColor, border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(8)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.refresh, size: 12, color: context.textSecondary),
                                          const SizedBox(width: 4),
                                          Text('다시 분석', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                        ]),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    Icon(Icons.auto_awesome, size: 12, color: context.primaryColor),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(_aiReason, style: TextStyle(fontSize: 12, color: context.textSecondary))),
                                  ]),
                                  if (isRepeat) ...[
                                    const SizedBox(height: 6),
                                    Text('1회 완료 시 +$displayRepeatXp XP · 모든 목표 완료 시 +$displayXp XP 추가 지급', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                  ],
                                ],
                              ]),
                      ),
                      const SizedBox(height: 20),

                      // 목표 알림 토글
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('목표 알림', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
                        GestureDetector(
                          onTap: () => setState(() => _alarmEnabled = !_alarmEnabled),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44, height: 26,
                            decoration: BoxDecoration(color: _alarmEnabled ? context.primaryColor : context.borderColor, borderRadius: BorderRadius.circular(99)),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 200),
                              alignment: _alarmEnabled ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(margin: const EdgeInsets.all(3), width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
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
                            decoration: BoxDecoration(color: context.subtleBg, border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text('🔔 $_alarmDisplay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: context.textPrimary))),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // XP 미리보기 요약
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('달성 시 획득 XP', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                            const SizedBox(height: 2),
                            isRepeat
                                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('1회 +$displayRepeatXp XP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                    Text('전체 완료 +$displayXp XP 추가', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                                  ])
                                : Text('+$displayXp XP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: context.textPrimary)),
                            if (isRepeat && _startDate.isNotEmpty && _endDate.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('🔄 $_repeatDaysText', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                              Text('📅 ${_startDate.replaceAll('-', '.')} ~ ${_endDate.replaceAll('-', '.')}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                            ],
                            if (_alarmEnabled) Text('🔔 $_alarmDisplay 알림', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                          ])),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(color: tColor.withOpacity(0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: tColor)),
                            child: Text(_typeLabel(type), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tColor)),
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
                          decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(14)),
                          child: Center(child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('목표 추가하기', style: TextStyle(color: context.isDark ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ]),

              // 날짜/시간 피커 오버레이
              if (_showDatePicker)
                DrumDatePicker(title: '날짜 선택', value: _scheduledDate,
                    onConfirm: (date) => setState(() { _scheduledDate = date; _showDatePicker = false; }),
                    onClose: () => setState(() => _showDatePicker = false)),
              if (_showStartPicker)
                DrumDatePicker(title: '시작일', value: _startDate.isEmpty ? _scheduledDate : _startDate,
                    onConfirm: (date) { setState(() { _startDate = date; _showStartPicker = false; }); _updateManualXp(); },
                    onClose: () => setState(() => _showStartPicker = false)),
              if (_showEndPicker)
                DrumDatePicker(title: '종료일', value: _endDate.isEmpty ? _scheduledDate : _endDate,
                    onConfirm: (date) { setState(() { _endDate = date; _showEndPicker = false; }); _updateManualXp(); },
                    onClose: () => setState(() => _showEndPicker = false)),
              if (_showAlarmPicker)
                AlarmPicker(amPm: _alarmAmPm, hour: _alarmHour, min: _alarmMin,
                    onConfirm: (amPm, hour, min) => setState(() { _alarmAmPm = amPm; _alarmHour = hour; _alarmMin = min; _showAlarmPicker = false; }),
                    onClose: () => setState(() => _showAlarmPicker = false)),
            ]),
          ),
        ),
      ),
    );
  }
}