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
    setState(() => _currentIndex = index);
    if (index == 3) _syncProfile();
  }

  Future<void> _syncProfile() async {
    final app = context.read<AppProvider>();
    if (app.userData != null && app.authUser != null) {
      await FirestoreService().updatePublicProfile(app.authUser!.uid, {
        'name': app.userData!.name,
        'level': app.userData!.level,
        'character': app.userData!.character.toMap(),
      });
      // 온라인 presence 업데이트
      await FriendService().setOnline(app.authUser!.uid);
    }
  }

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 온라인 상태 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      if (app.authUser != null) FriendService().setOnline(app.authUser!.uid);
    });
  }

  @override
  void dispose() {
    // 앱 종료 시 오프라인 상태 설정
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
        if (_currentIndex != 0) { setState(() => _currentIndex = 0); return; }
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
        // 앱 종료 전 오프라인 처리
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
                decoration: BoxDecoration(color: const Color(0xFF323232), borderRadius: BorderRadius.circular(12)),
                child: Text(app.toast!, style: const TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.center),
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
                _NavItem(icon: Icons.home_rounded, label: '홈', index: 0, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
                _NavItem(icon: Icons.flag_rounded, label: '목표', index: 1, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
                _NavItem(icon: Icons.timer_rounded, label: '집중', index: 2, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
                _NavItem(
                  icon: Icons.people_rounded,
                  label: '소셜',
                  index: 3,
                  current: _currentIndex,
                  onTap: (i) { setState(() => _currentIndex = i); _syncProfile(); },
                ),
                _NavItem(icon: Icons.person_rounded, label: '마이', index: 4, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i), badge: app.unreadMailCount),
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

  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap, this.badge = 0});

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
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
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