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
import '../services/notification_service.dart';

// GlobalKey 제거 — 재로그인 시 Element 충돌 방지
// 탭 전환은 HomeScreen에 onSwitchTab 콜백으로 전달
class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastBackPressed;

  // 현재 로그인한 uid 캐싱 — dispose 시 오프라인 처리에 사용
  String? _activeUid;

  // 화면 목록 — HomeScreen에 탭 전환 콜백 주입
  List<Widget> get _screens => [
    HomeScreen(onSwitchTab: switchTab),
    const GoalsScreen(),
    const FocusScreen(),
    const SocialScreen(),
    const MyScreen(),
  ];

  // 탭 전환 — 집중모드 중 다른 탭 이동 시 경고 다이얼로그 표시
  void switchTab(int index) {
    final app = context.read<AppProvider>();
    if (app.isFocusing && index != 2) {
      _confirmLeaveFocus(index);
      return;
    }
    _doSwitchTab(index);
  }

  // 집중모드 탭 이탈 확인 다이얼로그
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
              // 집중모드 일시정지 후 탭 전환
              context.read<AppProvider>().onPauseFocus?.call();
              _doSwitchTab(targetIndex);
            },
            child: Text('이동', style: TextStyle(color: context.primaryColor)),
          ),
        ],
      ),
    );
  }

  // 실제 탭 전환 처리 — 소셜 탭 진입 시 프로필 동기화
  void _doSwitchTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 3) _syncProfile();
    final uid = context.read<AppProvider>().authUser?.uid;
    _activeUid = uid;
    // 활동 시간 갱신
    if (uid != null) FriendService().updateActivity(uid);
  }

  // 소셜 탭 진입 시 공개 프로필 동기화 및 온라인 상태 설정
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

  // 예약된 알림 탭 이동 처리 — 앱 시작/재개 후 MainNav가 준비되면 해당 탭으로 이동
  void _handlePendingNotificationTab() {
    final pendingTab = NotificationService.pendingTab;
    if (pendingTab == null) return;
    NotificationService.pendingTab = null;
    switchTab(pendingTab);
  }

  @override
  void initState() {
    super.initState();
    // AppLifecycleState 감지를 위한 옵저버 등록
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      final uid = app.authUser?.uid;
      _activeUid = uid;
      // 앱 진입 시 온라인 상태로 설정
      if (uid != null) FriendService().setOnline(uid);
      _handlePendingNotificationTab();
      // FCM 토큰 없는 기존 유저 대응 — UI 마운트 완료 후 저장 시도
      if (uid != null) NotificationService.saveFcmToken(uid);
    });
  }

  // 앱 포그라운드/백그라운드 전환 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _activeUid;
    if (uid == null) return;
    if (state == AppLifecycleState.resumed) {
      // 앱 포그라운드 복귀 시 온라인으로
      FriendService().setOnline(uid);
    } else if (state == AppLifecycleState.paused) {
      // 앱 백그라운드 전환 시 오프라인으로
      FriendService().setOffline(uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // MainNav 제거 시 오프라인 처리
    final uid = _activeUid;
    if (uid != null) FriendService().setOffline(uid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    // build마다 uid 갱신 — 로그아웃 시 null로 초기화됨
    _activeUid = app.authUser?.uid;
    // 알림 탭 이동 예약 확인 — 이미 열린 앱에서 알림을 눌렀을 때도 다음 프레임에 반영
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handlePendingNotificationTab();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        // 홈 탭이 아니면 홈으로 이동
        if (_currentIndex != 0) {
          if (_currentIndex != 2) setState(() => _currentIndex = 0);
          return;
        }
        // 2초 이내 뒤로가기 두 번 → 앱 종료
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
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
          // 화면 콘텐츠
          IndexedStack(index: _currentIndex, children: _screens),
          // 토스트 메시지 — 화면 하단 중앙에 표시
          if (app.toast != null)
            Positioned(
              bottom: 100, left: 24, right: 24,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF323232),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(app.toast!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ),
            ),
        ]),
        // 하단 네비게이션 바
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 56,
              child: Row(children: [
                _NavItem(icon: Icons.home_rounded, label: '홈', index: 0,
                    current: _currentIndex, onTap: switchTab),
                _NavItem(icon: Icons.flag_rounded, label: '목표', index: 1,
                    current: _currentIndex, onTap: switchTab),
                _NavItem(icon: Icons.timer_rounded, label: '집중', index: 2,
                    current: _currentIndex, onTap: switchTab),
                _NavItem(
                  icon: Icons.people_rounded, label: '소셜', index: 3,
                  current: _currentIndex, onTap: switchTab,
                  // 소셜 탭 배지 = 활동 알림 + 채팅 미읽음
                  badge: app.unreadSocialCount,
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

// 하단 네비게이션 아이템 — 활성/비활성 색상 및 배지 표시
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  final int badge;

  const _NavItem({
    required this.icon, required this.label, required this.index,
    required this.current, required this.onTap, this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 24,
                color: isActive ? context.primaryColor : const Color(0xFFBDBDBD)),
            // 미읽음 배지
            if (badge > 0)
              Positioned(top: -4, right: -6, child: Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(
                    color: AppTheme.danger, shape: BoxShape.circle),
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