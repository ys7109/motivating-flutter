import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/friend_service.dart';
import '../../services/firestore_service.dart';
import 'character_avatar.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});
  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  final _friendService = FriendService();
  List<Map<String, dynamic>> _feeds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AppProvider>().authUser!.uid;
    setState(() => _loading = true);
    try {
      final friends = await _friendService.getFriends(uid);
      final friendUids = friends.map((f) => f['uid'] as String).toList();
      if (friendUids.isEmpty) {
        if (mounted) setState(() { _feeds = []; _loading = false; });
        return;
      }
      final allFeeds = <Map<String, dynamic>>[];
      for (final fUid in friendUids) {
        final goals = await FirestoreService().getUserCompletedGoals(fUid);
        final friendInfo = friends.firstWhere((f) => f['uid'] == fUid);
        for (final g in goals.take(3)) {
          if (g.completedAt != null && DateTime.now().difference(g.completedAt!).inDays < 7) {
            allFeeds.add({
              'type': 'goal_complete',
              'uid': fUid,
              'name': friendInfo['name'],
              'character': friendInfo['character'],
              'level': friendInfo['level'],
              'title': g.title,
              'xp': g.xp,
              'createdAt': g.completedAt,
            });
          }
        }
      }
      allFeeds.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
      if (mounted) setState(() { _feeds = allFeeds; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator(color: context.primaryColor));
    if (_feeds.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📰', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text('친구 활동이 없어요', style: TextStyle(fontSize: 15, color: context.textSecondary)),
        const SizedBox(height: 4),
        Text('친구가 목표를 달성하면 여기에 표시돼요', style: TextStyle(fontSize: 13, color: context.textSecondary)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: context.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _feeds.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _FeedItem(feed: _feeds[i]),
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  final Map<String, dynamic> feed;
  const _FeedItem({required this.feed});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = feed['createdAt'] as DateTime?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor, width: 0.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CharacterAvatar(character: feed['character'] as Map<String, dynamic>?, size: 40),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(feed['name'] ?? '모험가', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
            const SizedBox(width: 4),
            Text('Lv.${feed['level'] ?? 1}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
          ]),
          const SizedBox(height: 4),
          RichText(text: TextSpan(children: [
            TextSpan(text: '🎉 목표 ', style: TextStyle(fontSize: 13, color: context.textSecondary)),
            TextSpan(text: '"${feed['title']}"', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textPrimary)),
            TextSpan(text: ' 완료!', style: TextStyle(fontSize: 13, color: context.textSecondary)),
          ])),
          const SizedBox(height: 4),
          Text('+${feed['xp']} XP 획득', style: TextStyle(fontSize: 12, color: context.primaryColor, fontWeight: FontWeight.w500)),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(_timeAgo(createdAt), style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ],
        ])),
      ]),
    );
  }
}