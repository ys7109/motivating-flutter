import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../providers/app_provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/goals/goals_screen.dart';
import '../screens/focus/focus_screen.dart';
import '../screens/social/social_screen.dart';
import '../screens/my/my_screen.dart';
import '../services/firestore_service.dart';
import '../services/friend_service.dart';

final mainNavKey = GlobalKey<_MainNavState>();

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;
  DateTime? _lastBackPressed;

  final List<Widget> _screens = const [
    HomeScreen(), GoalsScreen(), FocusScreen(), SocialScreen(), MyScreen(),
  ];

  void switchTab(int index) {
    // 집중모드 진행 중 다른 탭으로 이동 시 경고
    final app = context.read<AppProvider>();
    if (app.isFocusing && index != 2) {
      _confirmLeaveFocus(index);
      return;
    }
    _doSwitchTab(index);
  }

  // 집중모드 종료 확인 다이얼로그
  void _confirmLeaveFocus(int targetIndex) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.modalBg,
        title: Text('집중 모드 진행 중',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: context.textPrimary)),
        content: Text('집중 모드가 진행 중이에요.\n다른 탭으로 이동하면 타이머가 일시정지돼요.',
            style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: context.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 탭 이동 전 타이머 일시정지
              context.read<AppProvider>().onPauseFocus?.call();
              _doSwitchTab(targetIndex);
            },
            child: Text('이동', style: TextStyle(color: context.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _doSwitchTab(int index) {
    setState(() => _currentIndex = index);
    // 소셜 탭 전환 시 프로필 동기화
    if (index == 3) _syncProfile();
    // 탭 전환 시 lastActivity 갱신 (3분 타임아웃 리셋)
    final uid = context.read<AppProvider>().authUser?.uid;
    if (uid != null) FriendService().updateActivity(uid);
  }

  Future<void> _syncProfile() async {
    final app = context.read<AppProvider>();
    if (app.userData != null && app.authUser != null) {
      await FirestoreService().updatePublicProfile(app.authUser!.uid, {
        'name': app.userData!.name,
        'level': app.userData!.level,
        'character': app.userData!.character.toMap(),
        'equippedAchievement': app.userData!.equippedAchievement,
      });
      await FriendService().setOnline(app.authUser!.uid);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      if (app.authUser != null) FriendService().setOnline(app.authUser!.uid);
    });
  }

  @override
  void dispose() {
    final app = context.read<AppProvider>();
    if (app.authUser != null) FriendService().setOffline(app.authUser!.uid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (_currentIndex != 0) {
          // 집중모드 탭(2번)에서 뒤로가기는 FocusScreen의 PopScope가 처리
          // 다른 탭에서 뒤로가기 시 홈으로 이동
          if (_currentIndex != 2) setState(() => _currentIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('한 번 더 누르면 종료됩니다'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
        if (app.authUser != null) await FriendService().setOffline(app.authUser!.uid);
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: Stack(children: [
          IndexedStack(index: _currentIndex, children: _screens),
          if (app.toast != null)
            Positioned(
              bottom: 90, left: 24, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFF323232), borderRadius: BorderRadius.circular(12)),
                child: Text(app.toast!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
            ),
        ]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 56,
              child: Row(children: [
                // 모든 탭 전환을 switchTab으로 통일 (집중모드 경고 처리)
                _NavItem(icon: Icons.home_rounded, label: '홈', index: 0,
                    current: _currentIndex, onTap: switchTab),
                _NavItem(icon: Icons.flag_rounded, label: '목표', index: 1,
                    current: _currentIndex, onTap: switchTab),
                _NavItem(icon: Icons.timer_rounded, label: '집중', index: 2,
                    current: _currentIndex, onTap: switchTab),
                _NavItem(
                  icon: Icons.people_rounded, label: '소셜', index: 3,
                  current: _currentIndex,
                  onTap: switchTab,
                  badge: app.unreadSocialCount, // 알림 + 채팅 미읽음 합산 배지
                ),
                _NavItem(icon: Icons.person_rounded, label: '마이', index: 4,
                    current: _currentIndex, onTap: switchTab),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  final int badge;

  const _NavItem({required this.icon, required this.label, required this.index,
      required this.current, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 24, color: isActive ? context.primaryColor : const Color(0xFFBDBDBD)),
            if (badge > 0)
              Positioned(top: -4, right: -6, child: Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                child: Center(child: Text(badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8,
                        fontWeight: FontWeight.bold))),
              )),
          ]),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10,
              color: isActive ? context.primaryColor : const Color(0xFFBDBDBD),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}