import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import 'friends_tab.dart';
import 'feed_tab.dart';
import 'diary_tab.dart';
import 'ranking_tab.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              padding: const EdgeInsets.all(3),
              tabs: const [Tab(text: '친구'), Tab(text: '피드'), Tab(text: '다이어리'), Tab(text: '랭킹')],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [FriendsTab(), FeedTab(), DiaryTab(), RankingTab()],
            ),
          ),
        ]),
      ),
    );
  }
}