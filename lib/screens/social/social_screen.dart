import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import 'friends_tab.dart';
import 'feed_tab.dart';
import 'diary_tab.dart';
import 'ranking_tab.dart';
import 'chat_list_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String? _lastHash;

  final _friendsKey = GlobalKey<FriendsTabState>();
  final _feedKey = GlobalKey<FeedTabState>();
  final _diaryKey = GlobalKey<DiaryTabState>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  Future<void> _syncAndReload() async {
    final app = context.read<AppProvider>();
    if (app.userData != null && app.authUser != null) {
      await FirestoreService().updatePublicProfile(app.authUser!.uid, {
        'name': app.userData!.name,
        'level': app.userData!.level,
        'character': app.userData!.character.toMap(),
        'equippedAchievement': app.userData!.equippedAchievement,
      });
    }
    _friendsKey.currentState?.reload();
    _feedKey.currentState?.reload();
    _diaryKey.currentState?.reload();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;

    if (userData != null) {
      final hash = '${userData.character.skin}_${userData.character.badge}_'
          '${userData.character.frame}_${userData.name}_${userData.level}_'
          '${userData.equippedAchievement ?? ''}';
      if (_lastHash != null && _lastHash != hash) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncAndReload());
      }
      _lastHash = hash;
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text('소셜', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: context.textPrimary)),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabCtrl,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: context.isDark ? Colors.black : Colors.white,
              unselectedLabelColor: context.textSecondary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(text: '친구'),
                Tab(text: '채팅'),
                Tab(text: '피드'),
                Tab(text: '게시판'),
                Tab(text: '랭킹'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                FriendsTab(key: _friendsKey),
                const ChatListScreen(),
                FeedTab(key: _feedKey),
                DiaryTab(key: _diaryKey),
                RankingTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}