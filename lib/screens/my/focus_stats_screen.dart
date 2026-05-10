import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';

class FocusStatsScreen extends StatefulWidget {
  const FocusStatsScreen({super.key});
  @override
  State<FocusStatsScreen> createState() => _FocusStatsScreenState();
}

class _FocusStatsScreenState extends State<FocusStatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  DateTime? _accountCreatedAt;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadSessions() async {
    final app = context.read<AppProvider>();
    final uid = app.authUser!.uid;
    // 계정 생성일
    _accountCreatedAt = app.userData?.createdAt;

    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('focusSessions')
        .orderBy('createdAt', descending: false)
        .get();
    if (mounted) setState(() {
      _sessions = snap.docs.map((d) {
        final data = d.data();
        final ts = data['createdAt'] as Timestamp?;
        return {'minutes': data['minutes'] ?? 0, 'createdAt': ts?.toDate() ?? DateTime.now()};
      }).toList();
      _loading = false;
    });
  }

  // 일별 데이터 (최근 7일)
  List<_BarData> get _dailyData {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final dateStr = _dateStr(date);
      final mins = _sessions.where((s) => _dateStr(s['createdAt'] as DateTime) == dateStr)
          .fold<int>(0, (sum, s) => sum + (s['minutes'] as int));
      final weekDays = ['일','월','화','수','목','금','토'];
      return _BarData(label: weekDays[date.weekday % 7], minutes: mins, isToday: i == 6);
    });
  }

  // 주별 데이터 — 계정 생성일 이후 주차만 표시 (최대 8주)
  List<_BarData> get _weeklyData {
    final now = DateTime.now();
    // 이번 주 시작 (일요일 기준)
    final todayStart = DateTime(now.year, now.month, now.day);
    final thisWeekStart = todayStart.subtract(Duration(days: now.weekday % 7));

    // 최대 8주 생성 후 계정 생성일 이전 주 제거
    final weeks = <_BarData>[];
    for (int i = 7; i >= 0; i--) {
      final start = thisWeekStart.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 6));

      // 계정 생성일보다 이전 주는 스킵
      if (_accountCreatedAt != null) {
        final createdDay = DateTime(_accountCreatedAt!.year, _accountCreatedAt!.month, _accountCreatedAt!.day);
        if (end.isBefore(createdDay)) continue;
      }

      final mins = _sessions.where((s) {
        final d = s['createdAt'] as DateTime;
        final dd = DateTime(d.year, d.month, d.day);
        return !dd.isBefore(start) && !dd.isAfter(end);
      }).fold<int>(0, (sum, s) => sum + (s['minutes'] as int));

      final isThisWeek = i == 0;
      final label = isThisWeek ? '이번 주' : '${i}주 전';
      weeks.add(_BarData(label: label, minutes: mins, isToday: isThisWeek));
    }
    return weeks;
  }

  // 월별 데이터 — 계정 생성월 이후만 표시 (최대 6개월)
  List<_BarData> get _monthlyData {
    final now = DateTime.now();
    final months = <_BarData>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);

      // 계정 생성월보다 이전이면 스킵
      if (_accountCreatedAt != null) {
        final createdMonth = DateTime(_accountCreatedAt!.year, _accountCreatedAt!.month, 1);
        if (month.isBefore(createdMonth)) continue;
      }

      final mins = _sessions.where((s) {
        final d = s['createdAt'] as DateTime;
        return d.year == month.year && d.month == month.month;
      }).fold<int>(0, (sum, s) => sum + (s['minutes'] as int));

      months.add(_BarData(label: '${month.month}월', minutes: mins, isToday: i == 0));
    }
    return months;
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _formatMin(int min) {
    if (min == 0) return '0분';
    final h = min ~/ 60; final m = min % 60;
    if (h > 0 && m > 0) return '$h시간 $m분';
    if (h > 0) return '$h시간';
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    final totalMin = userData?.totalFocusMin ?? 0;
    final totalH = totalMin ~/ 60;
    final totalM = totalMin % 60;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back_ios, size: 18, color: context.textSecondary),
              ),
              const SizedBox(width: 12),
              Text('집중 통계', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.textPrimary)),
            ]),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _SummaryCard(label: '누적 집중', value: totalH > 0 ? '$totalH시간 $totalM분' : '$totalM분', icon: '⏱'),
              const SizedBox(width: 10),
              _SummaryCard(label: '총 세션', value: '${_sessions.length}회', icon: '🎯'),
              const SizedBox(width: 10),
              _SummaryCard(
                label: '평균 세션',
                value: _sessions.isEmpty ? '0분'
                    : _formatMin(_sessions.fold<int>(0, (s, e) => s + (e['minutes'] as int)) ~/ _sessions.length),
                icon: '📊',
              ),
            ]),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabCtrl,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: context.onPrimary,
                unselectedLabelColor: context.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                padding: const EdgeInsets.all(3),
                tabs: const [Tab(text: '일별'), Tab(text: '주별'), Tab(text: '월별')],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: context.primaryColor))
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _BarChart(data: _dailyData, formatMin: _formatMin),
                      _BarChart(data: _weeklyData, formatMin: _formatMin),
                      _BarChart(data: _monthlyData, formatMin: _formatMin),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

class _BarData {
  final String label;
  final int minutes;
  final bool isToday;
  const _BarData({required this.label, required this.minutes, required this.isToday});
}

class _BarChart extends StatelessWidget {
  final List<_BarData> data;
  final String Function(int) formatMin;
  const _BarChart({required this.data, required this.formatMin});

  @override
  Widget build(BuildContext context) {
    final maxMin = data.map((d) => d.minutes).fold<int>(0, (a, b) => a > b ? a : b);
    final total = data.fold<int>(0, (s, d) => s + d.minutes);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor, width: 0.5)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('기간 합계', style: TextStyle(fontSize: 13, color: context.textSecondary)),
            Text(formatMin(total), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary)),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: data.isEmpty || total == 0
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⏱', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text('아직 집중 기록이 없어요', style: TextStyle(fontSize: 14, color: context.textSecondary)),
                  const SizedBox(height: 4),
                  Text('집중 모드를 사용해보세요!', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                ]))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.map((d) {
                    final ratio = maxMin > 0 ? d.minutes / maxMin : 0.0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (d.minutes > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(formatMin(d.minutes),
                                  style: TextStyle(fontSize: 9, color: context.textSecondary),
                                  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: ratio > 0 ? (200 * ratio).clamp(4.0, 200.0) : 4,
                            decoration: BoxDecoration(
                              color: d.isToday ? context.primaryColor
                                  : d.minutes > 0 ? context.primaryColor.withOpacity(0.4)
                                  : context.borderColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(d.label, style: TextStyle(
                            fontSize: 11,
                            color: d.isToday ? context.primaryColor : context.textSecondary,
                            fontWeight: d.isToday ? FontWeight.w600 : FontWeight.normal,
                          )),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value, icon;
  const _SummaryCard({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
        ]),
      ),
    );
  }
}