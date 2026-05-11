import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/diary_service.dart';
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
  String _lastHash = '';
  bool _syncing = false;

  final _friendsKey = GlobalKey<FriendsTabState>();
  final _feedKey = GlobalKey<FeedTabState>();
  final _diaryKey = GlobalKey<DiaryTabState>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    // 탭 전환 시 해당 탭 reload
    _tabCtrl.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    // 탭 전환 시 해당 탭 즉시 reload — 변경사항 반영
    switch (_tabCtrl.index) {
      case 0: _friendsKey.currentState?.reload(); break;
      case 2: _feedKey.currentState?.reload(); break;
      case 3: _diaryKey.currentState?.reload(); break;
    }
  }

  Future<void> _syncAndReload() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final app = context.read<AppProvider>();
      if (app.userData == null || app.authUser == null) return;
      final uid = app.authUser!.uid;
      final userData = app.userData!;

      // rankings + 게시글 작성자 정보 동기화
      await Future.wait([
        FirestoreService().updatePublicProfile(uid, {
          'name': userData.name,
          'level': userData.level,
          'character': userData.character.toMap(),
          'equippedAchievement': userData.equippedAchievement,
          'profileImageUrl': userData.profileImageUrl,
        }),
        DiaryService().updateAuthorInfo(
          uid, userData.name, userData.character.toMap(), userData.level,
          equippedAchievement: userData.equippedAchievement,
          profileImageUrl: userData.profileImageUrl,
        ),
      ]);

      if (!mounted) return;

      // 모든 탭 reload — sync 완료 후 최신 데이터 표시
      await Future.wait([
        _friendsKey.currentState?.reload() ?? Future.value(),
        _feedKey.currentState?.reload() ?? Future.value(),
        _diaryKey.currentState?.reload() ?? Future.value(),
      ]);
    } finally {
      _syncing = false;
    }
  }

  // 현재 탭만 빠르게 reload (sync 없이)
  void _reloadCurrentTab() {
    switch (_tabCtrl.index) {
      case 0: _friendsKey.currentState?.reload(); break;
      case 2: _feedKey.currentState?.reload(); break;
      case 3: _diaryKey.currentState?.reload(); break;
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
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
          '${userData.equippedAchievement ?? ''}_${userData.profileImageUrl ?? ''}';
      if (_lastHash != hash) {
        _lastHash = hash;
        // userData 변경 감지 시 sync + 현재 탭 즉시 reload
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncAndReload();
        });
      }
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
              labelColor: context.onPrimary,
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