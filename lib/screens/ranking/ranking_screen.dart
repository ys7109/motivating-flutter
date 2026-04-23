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

const _skins = [
  {'id': 'default', 'emoji': '🧑'},
  {'id': 'warrior', 'emoji': '⚔️'},
  {'id': 'scholar', 'emoji': '📚'},
  {'id': 'explorer', 'emoji': '🧭'},
  {'id': 'legend', 'emoji': '🌟'},
];
const _badges = [
  {'id': 'none', 'emoji': ''},
  {'id': 'flame', 'emoji': '🔥'},
  {'id': 'lightning', 'emoji': '⚡'},
  {'id': 'crown', 'emoji': '👑'},
  {'id': 'diamond', 'emoji': '💎'},
];
const _frames = [
  {'id': 'none', 'color': 0x00000000},
  {'id': 'silver', 'color': 0xFF9e9e9e},
  {'id': 'gold', 'color': 0xFFf9a825},
  {'id': 'rainbow', 'color': 0xFFe040fb},
];

String _skinEmoji(String? skin) =>
    (_skins.firstWhere((s) => s['id'] == skin, orElse: () => _skins[0])['emoji'] as String?) ?? '🧑';

String _badgeEmoji(String? badge) =>
    (_badges.firstWhere((b) => b['id'] == badge, orElse: () => _badges[0])['emoji'] as String?) ?? '';

Color? _frameColor(String? frame) {
  if (frame == null || frame == 'none') return null;
  final f = _frames.firstWhere((f) => f['id'] == frame, orElse: () => _frames[0]);
  final c = f['color'] as int;
  return c == 0 ? null : Color(c);
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
  String? _lastCharacterHash; // 변화 감지용

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

    // 캐릭터/이름/레벨 변화 감지
    final hash = '${userData.character.skin}_${userData.character.badge}_'
        '${userData.character.frame}_${userData.name}_${userData.level}';

    if (_lastCharacterHash != null && _lastCharacterHash != hash) {
      // 변경 감지 시 Firestore 동기화 + 랭킹 새로고침
      _syncAndLoad();
    }
    _lastCharacterHash = hash;
  }

  Future<void> _syncAndLoad() async {
    final app = context.read<AppProvider>();
    if (app.userData != null && app.authUser != null) {
      // Firestore 동기화 완료 후 랭킹 로드
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
    final myUid = app.userData?.uid;
    final myRank = _rankings.indexWhere((r) => r['uid'] == myUid) + 1;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('집중력 랭킹',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      myRank > 0 ? '내 순위: $myRank위' : '랭킹에 참여하려면 집중 모드를 사용하세요',
                      style: TextStyle(fontSize: 13, color: context.textSecondary),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      ['total', '누적'],
                      ['daily', '오늘'],
                      ['average', '일 평균'],
                    ].map((t) => GestureDetector(
                      onTap: () { setState(() => _tab = t[0]); _loadRankings(); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                        decoration: BoxDecoration(
                          color: _tab == t[0] ? context.primaryColor : context.subtleBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(t[1], style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: _tab == t[0]
                                ? (context.isDark ? Colors.black : Colors.white)
                                : context.textSecondary)),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: context.primaryColor))
                      : _rankings.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Text('🏆', style: TextStyle(fontSize: 32)),
                              const SizedBox(height: 12),
                              Text('아직 랭킹 데이터가 없어요',
                                  style: TextStyle(fontSize: 15, color: context.textSecondary)),
                              const SizedBox(height: 4),
                              Text('집중 모드를 사용하면 랭킹에 참여돼요',
                                  style: TextStyle(fontSize: 13, color: context.textSecondary)),
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

                                final charMap = user['character'] as Map<String, dynamic>?;
                                final skin = charMap?['skin'] as String?;
                                final badge = charMap?['badge'] as String?;
                                final frame = charMap?['frame'] as String?;

                                return GestureDetector(
                                  onTap: () => _openProfile(user),
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
                                      SizedBox(width: 32, child: Center(
                                          child: medal != null
                                              ? Text(medal, style: const TextStyle(fontSize: 22))
                                              : Text('${user['rank']}', style: TextStyle(
                                                  fontSize: 15, fontWeight: FontWeight.w600,
                                                  color: context.textSecondary)))),
                                      const SizedBox(width: 10),
                                      _CharacterAvatar(skin: skin, badge: badge, frame: frame, size: 40),
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
                                        Text('Lv.${user['level'] ?? 1}',
                                            style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                      ])),
                                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                        Text(_formatMin(focusMin), style: TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w600,
                                            color: context.textPrimary)),
                                        Text(_tab == 'total' ? '누적'
                                            : _tab == 'daily' ? '오늘' : '일 평균',
                                            style: TextStyle(fontSize: 11, color: context.textSecondary)),
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

          if (_profile != null)
            _ProfileModal(profile: _profile!, onClose: () => setState(() => _profile = null)),
        ],
      ),
    );
  }
}

class _CharacterAvatar extends StatelessWidget {
  final String? skin, badge, frame;
  final double size;
  const _CharacterAvatar({this.skin, this.badge, this.frame, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final frameColor = _frameColor(frame);
    final skinEmoji = _skinEmoji(skin);
    final badgeEmoji = _badgeEmoji(badge);
    final innerSize = size * 0.88;

    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: frameColor ?? context.subtleBg),
        child: Center(
          child: Container(
            width: innerSize, height: innerSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: context.surfaceColor),
            child: Center(child: Text(skinEmoji, style: TextStyle(fontSize: size * 0.42))),
          ),
        ),
      ),
      if (badgeEmoji.isNotEmpty)
        Positioned(
          bottom: -2, right: -2,
          child: Container(
            width: size * 0.38, height: size * 0.38,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: context.surfaceColor,
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Center(child: Text(badgeEmoji, style: TextStyle(fontSize: size * 0.2))),
          ),
        ),
    ]);
  }
}

class _ProfileModal extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onClose;
  const _ProfileModal({required this.profile, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final goals = profile['completedGoals'] as List<GoalModel>? ?? [];
    final charMap = profile['character'] as Map<String, dynamic>?;
    final skin = charMap?['skin'] as String?;
    final badge = charMap?['badge'] as String?;
    final frame = charMap?['frame'] as String?;

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
              decoration: BoxDecoration(
                  color: context.modalBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(children: [
                    _CharacterAvatar(skin: skin, badge: badge, frame: frame, size: 52),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(profile['name'] ?? '모험가', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      Text('Lv.${profile['level'] ?? 1}',
                          style: TextStyle(fontSize: 13, color: context.textSecondary)),
                    ]),
                    const Spacer(),
                    GestureDetector(onTap: onClose,
                        child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
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
                  child: Text('달성한 목표 ${goals.length}개', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
                ),
                Expanded(
                  child: goals.isEmpty
                      ? Center(child: Text('아직 달성한 목표가 없어요',
                          style: TextStyle(fontSize: 13, color: context.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: goals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final g = goals[i];
                            final tagColor = g.type == 'short' ? const Color(0xFF1b8a5a)
                                : g.type == 'mid' ? const Color(0xFFf9a825)
                                : const Color(0xFF3949ab);
                            final tagLabel = g.type == 'short' ? '단기'
                                : g.type == 'mid' ? '중기' : '장기';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: context.subtleBg,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: tagColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(tagLabel, style: TextStyle(
                                      color: tagColor, fontSize: 10, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(g.title, style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: context.textPrimary))),
                                Text('+${g.xp} XP', style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF1b8a5a),
                                    fontWeight: FontWeight.w500)),
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
        decoration: BoxDecoration(
            color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
        ]),
      ),
    );
  }
}