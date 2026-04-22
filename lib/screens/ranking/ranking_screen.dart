import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/goal_model.dart';

String _formatMin(int? min) {
  if (min == null || min == 0) return '0분';
  final h = min ~/ 60;
  final m = min % 60;
  if (h > 0) return '$h시간 ${m > 0 ? '${m}분' : ''}';
  return '$m분';
}

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});
  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String _tab = 'total';
  List<Map<String, dynamic>> _rankings = [];
  bool _loading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadRankings();
  }

  Future<void> _loadRankings() async {
    setState(() => _loading = true);
    try {
      _rankings = await FirestoreService().getRankings(_tab);
    } catch (e) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openProfile(Map<String, dynamic> user) async {
    final goals = await FirestoreService().getUserCompletedGoals(user['uid']);
    setState(() => _profile = {...user, 'completedGoals': goals});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final myRank = _rankings.indexWhere((r) => r['uid'] == app.userData?.uid) + 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('집중력 랭킹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(myRank > 0 ? '내 순위: $myRank위' : '랭킹에 참여하려면 집중 모드를 사용하세요',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ]),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [['total','누적'],['daily','오늘'],['average','일 평균']].map((t) =>
                      GestureDetector(
                        onTap: () { setState(() => _tab = t[0]); _loadRankings(); },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                          decoration: BoxDecoration(
                            color: _tab == t[0] ? AppTheme.primary : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(t[1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _tab == t[0] ? Colors.white : AppTheme.textSecondary)),
                        ),
                      )
                    ).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : _rankings.isEmpty
                      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('🏆', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 12),
                          Text('아직 랭킹 데이터가 없어요', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                          SizedBox(height: 4),
                          Text('집중 모드를 사용하면 랭킹에 참여돼요', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ]))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _rankings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final user = _rankings[i];
                            final isMe = user['uid'] == app.userData?.uid;
                            final focusMin = _tab == 'total' ? user['totalFocusMin']
                                : _tab == 'daily' ? user['todayFocusMin']
                                : user['avgFocusMin'];
                            final medal = user['rank'] == 1 ? '🥇' : user['rank'] == 2 ? '🥈' : user['rank'] == 3 ? '🥉' : null;

                            return GestureDetector(
                              onTap: () => _openProfile(user),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isMe ? AppTheme.primary : AppTheme.border, width: isMe ? 1.5 : 0.5),
                                ),
                                child: Row(children: [
                                  SizedBox(width: 32, child: Center(child: medal != null
                                    ? Text(medal, style: const TextStyle(fontSize: 22))
                                    : Text('${user['rank']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)))),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF0F0F0)),
                                    child: const Center(child: Text('🧑', style: TextStyle(fontSize: 18))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Text(user['name'] ?? '모험가', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(99)),
                                          child: const Text('나', style: TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                                        ),
                                      ],
                                    ]),
                                    Text('Lv.${user['level'] ?? 1}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text(_formatMin(focusMin), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    Text(_tab == 'total' ? '누적' : _tab == 'daily' ? '오늘' : '일 평균',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ]),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // 프로필 모달
          if (_profile != null)
            _ProfileModal(
              profile: _profile!,
              onClose: () => setState(() => _profile = null),
            ),
        ],
      ),
    );
  }
}

class _ProfileModal extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onClose;
  const _ProfileModal({required this.profile, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final goals = profile['completedGoals'] as List<GoalModel>? ?? [];
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(children: [
                      Container(width: 52, height: 52, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF0F0F0)),
                        child: const Center(child: Text('🧑', style: TextStyle(fontSize: 22)))),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(profile['name'] ?? '모험가', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text('Lv.${profile['level'] ?? 1}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ]),
                      const Spacer(),
                      GestureDetector(onTap: onClose, child: const Text('×', style: TextStyle(fontSize: 24, color: AppTheme.textSecondary))),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      _StatBox(label: '누적', value: _formatMin(profile['totalFocusMin'])),
                      const SizedBox(width: 10),
                      _StatBox(label: '오늘', value: _formatMin(profile['todayFocusMin'])),
                      const SizedBox(width: 10),
                      _StatBox(label: '일 평균', value: _formatMin(profile['avgFocusMin'])),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text('달성한 목표 ${goals.length}개', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: goals.isEmpty
                      ? const Center(child: Text('아직 달성한 목표가 없어요', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: goals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final g = goals[i];
                            final tagColor = g.type == 'short' ? const Color(0xFF1b8a5a) : g.type == 'mid' ? const Color(0xFFf9a825) : const Color(0xFF3949ab);
                            final tagLabel = g.type == 'short' ? '단기' : g.type == 'mid' ? '중기' : '장기';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text(tagLabel, style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(g.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                Text('+${g.xp} XP', style: const TextStyle(fontSize: 12, color: Color(0xFF1b8a5a), fontWeight: FontWeight.w500)),
                              ]),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ]),
      ),
    );
  }
}