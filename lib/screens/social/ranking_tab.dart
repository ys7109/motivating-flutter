import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/achievement_definitions.dart';
import '../../services/friend_service.dart';
import 'character_avatar.dart';
import 'user_profile_sheet.dart';

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
  String? _lastHash;

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
        '${userData.character.frame}_${userData.name}_${userData.level}_'
        '${userData.equippedAchievement ?? ''}';
    if (_lastHash != null && _lastHash != hash) _syncAndLoad();
    _lastHash = hash;
  }

  Future<void> _syncAndLoad() async {
    final app = context.read<AppProvider>();
    if (app.userData != null && app.authUser != null) {
      await FirestoreService().updatePublicProfile(app.authUser!.uid, {
        'name': app.userData!.name,
        'level': app.userData!.level,
        'character': app.userData!.character.toMap(),
        'equippedAchievement': app.userData!.equippedAchievement,
        // 랭킹에서도 프로필 이미지 표시
        'profileImageUrl': app.userData!.profileImageUrl,
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

  // 프로필 터치 시 — showUserProfileSheet 사용 (user_profile_sheet.dart와 동일한 UI)
  void _openProfile(BuildContext context, String uid) {
    showUserProfileSheet(context, uid);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final myUid = app.userData?.uid;
    final myRank = _rankings.indexWhere((r) => r['uid'] == myUid) + 1;

    return Column(children: [
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
                color: _tab == t[0] ? context.onPrimary : context.textSecondary)),
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
                    Text('아직 랭킹 데이터가 없어요',
                        style: TextStyle(fontSize: 15, color: context.textSecondary)),
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
                      final medal = user['rank'] == 1 ? '🥇'
                          : user['rank'] == 2 ? '🥈'
                          : user['rank'] == 3 ? '🥉' : null;
                      final equippedId = user['equippedAchievement'] as String?;
                      final achievement = equippedId != null
                          ? Achievements.findById(equippedId) : null;
                      return GestureDetector(
                        // 프로필 터치 시 showUserProfileSheet 호출
                        onTap: () => _openProfile(context, user['uid'] as String),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isMe ? context.primaryColor : context.borderColor,
                                width: isMe ? 1.5 : 0.5),
                          ),
                          child: Row(children: [
                            SizedBox(width: 32, child: Center(child: medal != null
                                ? Text(medal, style: const TextStyle(fontSize: 22))
                                : Text('${user['rank']}', style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600,
                                    color: context.textSecondary)))),
                            const SizedBox(width: 10),
                            CharacterAvatar(
                                character: user['character'] as Map<String, dynamic>?,
                                size: 40,
                                profileImageUrl: user['profileImageUrl'] as String?),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(user['name'] ?? '모험가', style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500,
                                    color: context.textPrimary)),
                                if (isMe) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: context.subtleBg,
                                        borderRadius: BorderRadius.circular(99)),
                                    child: Text('나', style: TextStyle(
                                        fontSize: 11, color: context.textPrimary)),
                                  ),
                                ],
                              ]),
                              // 업적 칭호 (닉네임 아래, 레벨 위)
                              if (achievement != null) ...[
                                const SizedBox(height: 2),
                                _AchievementTitle(achievement: achievement),
                                const SizedBox(height: 2),
                              ],
                              Text('Lv.${user["level"] ?? 1}',
                                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(_formatMin(focusMin), style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: context.textPrimary)),
                              Text(_tab == 'total' ? '누적' : _tab == 'daily' ? '오늘' : '일 평균',
                                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

// 칭호 뱃지 위젯
class _AchievementTitle extends StatelessWidget {
  final Achievement achievement;
  const _AchievementTitle({required this.achievement});
  @override
  Widget build(BuildContext context) {
    final diffColor = Color(Achievements.difficultyColor[achievement.difficulty]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: diffColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: diffColor.withOpacity(0.3)),
      ),
      child: Text(achievement.title,
          style: TextStyle(fontSize: 10, color: diffColor, fontWeight: FontWeight.w600)),
    );
  }
}