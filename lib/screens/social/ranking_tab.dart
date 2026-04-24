import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/goal_model.dart';
import '../../services/friend_service.dart';
import 'character_avatar.dart';

String _formatMin(int? min) {
  if (min == null || min == 0) return '0분';
  final h = min ~/ 60;
  final m = min % 60;
  if (h > 0) return '$h시간 ${m > 0 ? '${m}분' : ''}';
  return '$m분';
}

class RankingTab extends StatefulWidget {
  const RankingTab({super.key});
  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  String _tab = 'total';
  List<Map<String, dynamic>> _rankings = [];
  bool _loading = true;
  Map<String, dynamic>? _profile;
  String? _lastCharacterHash;

  @override
  void initState() {
    super.initState();
    _syncAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppProvider>();
    final userData = app.userData;
    if (userData == null) return;
    final hash = '${userData.character.skin}_${userData.character.badge}_'
        '${userData.character.frame}_${userData.name}_${userData.level}';
    if (_lastCharacterHash != null && _lastCharacterHash != hash) _syncAndLoad();
    _lastCharacterHash = hash;
  }

  Future<void> _syncAndLoad() async {
    final app = context.read<AppProvider>();
    if (app.userData != null && app.authUser != null) {
      await FirestoreService().updatePublicProfile(app.authUser!.uid, {
        'name': app.userData!.name,
        'level': app.userData!.level,
        'character': app.userData!.character.toMap(),
      });
    }
    await _loadRankings();
  }

  Future<void> _loadRankings() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try { _rankings = await FirestoreService().getRankings(_tab); } catch (e) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openProfile(Map<String, dynamic> user) async {
    final myUid = context.read<AppProvider>().authUser!.uid;
    final goals = await FirestoreService().getUserCompletedGoals(user['uid']);
    final status = user['uid'] == myUid ? 'me' : await FriendService().getFriendshipStatus(myUid, user['uid']);
    setState(() => _profile = {...user, 'completedGoals': goals, 'friendStatus': status});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final myUid = app.userData?.uid;
    final myRank = _rankings.indexWhere((r) => r['uid'] == myUid) + 1;

    return Stack(children: [
      Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            myRank > 0 ? '내 순위: $myRank위' : '집중 모드를 사용하면 랭킹에 참여돼요',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            ['total', '누적'], ['daily', '오늘'], ['average', '일 평균'],
          ].map((t) => GestureDetector(
            onTap: () { setState(() => _tab = t[0]); _loadRankings(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _tab == t[0] ? context.primaryColor : context.subtleBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(t[1], style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: _tab == t[0] ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary)),
            ),
          )).toList()),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: context.primaryColor))
              : _rankings.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🏆', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 12),
                      Text('아직 랭킹 데이터가 없어요', style: TextStyle(fontSize: 15, color: context.textSecondary)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _rankings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final user = _rankings[i];
                        final isMe = user['uid'] == myUid;
                        final focusMin = _tab == 'total' ? user['totalFocusMin']
                            : _tab == 'daily' ? user['todayFocusMin']
                            : user['avgFocusMin'];
                        final medal = user['rank'] == 1 ? '🥇' : user['rank'] == 2 ? '🥈' : user['rank'] == 3 ? '🥉' : null;
                        return GestureDetector(
                          onTap: () => _openProfile(user),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isMe ? context.primaryColor : context.borderColor, width: isMe ? 1.5 : 0.5),
                            ),
                            child: Row(children: [
                              SizedBox(width: 32, child: Center(child: medal != null
                                  ? Text(medal, style: const TextStyle(fontSize: 22))
                                  : Text('${user['rank']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textSecondary)))),
                              const SizedBox(width: 10),
                              CharacterAvatar(character: user['character'] as Map<String, dynamic>?, size: 40),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(user['name'] ?? '모험가', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(99)),
                                      child: Text('나', style: TextStyle(fontSize: 11, color: context.textPrimary)),
                                    ),
                                  ],
                                ]),
                                Text('Lv.${user['level'] ?? 1}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(_formatMin(focusMin), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                Text(_tab == 'total' ? '누적' : _tab == 'daily' ? '오늘' : '일 평균',
                                    style: TextStyle(fontSize: 11, color: context.textSecondary)),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
      if (_profile != null)
        _ProfileModal(
          profile: _profile!,
          onClose: () => setState(() => _profile = null),
          onFriendAction: (uid) async {
            final myUid = context.read<AppProvider>().authUser!.uid;
            final status = _profile!['friendStatus'];
            if (status == null) {
              await FriendService().sendRequest(myUid, uid);
              if (mounted) context.read<AppProvider>().showToast('친구 요청을 보냈어요!');
            } else if (status == 'accepted') {
              await FriendService().removeFriend(myUid, uid);
              if (mounted) context.read<AppProvider>().showToast('친구를 삭제했어요');
            }
            await _openProfile(_profile!);
          },
        ),
    ]);
  }
}

class _ProfileModal extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onClose;
  final ValueChanged<String> onFriendAction;
  const _ProfileModal({required this.profile, required this.onClose, required this.onFriendAction});

  @override
  Widget build(BuildContext context) {
    final goals = profile['completedGoals'] as List<GoalModel>? ?? [];
    final friendStatus = profile['friendStatus'] as String?;
    final isMe = friendStatus == 'me';

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
              decoration: BoxDecoration(color: context.modalBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(children: [
                    CharacterAvatar(character: profile['character'] as Map<String, dynamic>?, size: 52),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(profile['name'] ?? '모험가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      Text('Lv.${profile['level'] ?? 1}', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                    ])),
                    if (!isMe) ...[
                      GestureDetector(
                        onTap: () => onFriendAction(profile['uid']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: friendStatus == 'accepted' ? context.subtleBg : context.primaryColor,
                            borderRadius: BorderRadius.circular(99),
                            border: friendStatus == 'accepted' ? Border.all(color: context.borderColor) : null,
                          ),
                          child: Text(
                            friendStatus == 'accepted' ? '친구 삭제' : friendStatus == 'pending' ? '요청 중' : '친구 추가',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                color: friendStatus == 'accepted' ? context.textSecondary : (context.isDark ? Colors.black : Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    GestureDetector(onTap: onClose, child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
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
                  child: Align(alignment: Alignment.centerLeft, child: Text('달성한 목표 ${goals.length}개',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary))),
                ),
                Expanded(
                  child: goals.isEmpty
                      ? Center(child: Text('아직 달성한 목표가 없어요', style: TextStyle(fontSize: 13, color: context.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: goals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final g = goals[i];
                            final tagColor = g.type == 'short' ? const Color(0xFF1b8a5a)
                                : g.type == 'mid' ? const Color(0xFFf9a825)
                                : const Color(0xFF3949ab);
                            final tagLabel = g.type == 'short' ? '단기' : g.type == 'mid' ? '중기' : '장기';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text(tagLabel, style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(g.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textPrimary))),
                                Text('+${g.xp} XP', style: const TextStyle(fontSize: 12, color: Color(0xFF1b8a5a), fontWeight: FontWeight.w500)),
                              ]),
                            );
                          },
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

class _StatBox extends StatelessWidget {
  final String label, value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
        ]),
      ),
    );
  }
}