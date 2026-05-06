import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../models/mail_model.dart';
import '../models/achievement_definitions.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/diary_service.dart';
import '../services/activity_notification_service.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final FirestoreService _db = FirestoreService();
  final DiaryService _diaryService = DiaryService();
  final FriendService _friendService = FriendService();

  // 목표 완료 중복 처리 방지용 Set
  final Set<String> _processingGoals = {};

  // 전역 Navigator 키 — 알림 탭, signOut 화면 전환 등에서 사용
  static final navigatorKey = GlobalKey<NavigatorState>();
  FirestoreService get firestoreService => _db;

  // 인증 및 유저 상태
  User? authUser;
  UserModel? userData;
  List<GoalModel> goals = [];
  List<MailModel> mailbox = [];
  bool loading = true;
  String? toast;
  ThemeMode themeMode = ThemeMode.system;

  // 레벨업 / 출석 / 스트릭 모달 상태
  int? levelUpTo;
  bool showAttendModal = false;
  String? streakModalType;
  int brokenStreakPrev = 0;
  Map<String, dynamic>? currentMilestone;

  // 토스트 큐 — 연속 토스트를 순서대로 1.5초씩 표시
  final List<String> _toastQueue = [];
  bool _toastRunning = false;

  // Firebase Auth 상태 구독
  StreamSubscription? _authSub;

  // authStateChanges 초기화 진행 중 여부 — reloadUser 중복 실행 방지
  bool _isInitializing = false;

  // 스트릭 마일스톤 정의 — 일수별 XP 보상
  static const List<Map<String, Object>> _milestones = [
    {'days': 7,   'xp': 100,  'label': '7일 연속',   'badge': true},
    {'days': 14,  'xp': 200,  'label': '14일 연속',  'badge': false},
    {'days': 30,  'xp': 500,  'label': '한 달 연속', 'badge': true},
    {'days': 60,  'xp': 800,  'label': '60일 연속',  'badge': false},
    {'days': 100, 'xp': 1500, 'label': '100일 연속', 'badge': true},
    {'days': 365, 'xp': 5000, 'label': '1년 연속',   'badge': true},
  ];

  // XP 진행률 (0~100%)
  double get xpPercent => userData == null ? 0 : (userData!.xp / userData!.xpToNext * 100).clamp(0, 100);

  // 이번 달 완료된 목표 수
  int get goalsThisMonth {
    final now = DateTime.now();
    return goals.where((g) =>
      g.done && g.completedAt != null &&
      g.completedAt!.year == now.year && g.completedAt!.month == now.month
    ).length;
  }

  // 읽지 않은 우편 수
  int get unreadMailCount => mailbox.where((m) => !m.read).length;

  // 집중모드 진행 중 여부 — main_nav 탭 전환 경고에 사용
  bool isFocusing = false;

  // 집중모드 일시정지 콜백 — FocusScreen에서 등록, main_nav 탭 전환 시 호출
  VoidCallback? onPauseFocus;

  // 소셜 탭 배지 = 활동 알림 + 채팅 미읽음 합산
  int _unreadNotifCount = 0;
  int get unreadNotifCount => _unreadNotifCount;

  int _unreadChatCount = 0;
  int get unreadChatCount => _unreadChatCount;
  int get unreadSocialCount => _unreadNotifCount + _unreadChatCount;

  // 미읽음 알림/채팅 수 갱신
  Future<void> reloadUnreadNotifCount() async {
    if (authUser == null) return;
    _unreadNotifCount = await ActivityNotificationService().getUnreadCount(authUser!.uid);
    _unreadChatCount = await ChatService().getTotalUnreadCount(authUser!.uid);
    notifyListeners();
  }

  // 수령 대기 중인 업적 보상 수
  int get unclaimedAchievementCount {
    if (userData == null) return 0;
    return userData!.achievements
        .where((id) => !userData!.claimedAchievements.contains(id))
        .length;
  }

  // 레벨별 칭호
  String levelTitle(int level) {
    if (level >= 20) return '전설의 모험가';
    if (level >= 15) return '영웅';
    if (level >= 10) return '탐험가';
    if (level >= 6)  return '학자';
    if (level >= 3)  return '전사';
    return '초보 모험가';
  }

  // 앱 초기화 — 테마 로드 후 Auth 상태 구독 시작
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('themeMode') ?? 'system';
    themeMode = savedTheme == 'light' ? ThemeMode.light
        : savedTheme == 'dark' ? ThemeMode.dark
        : ThemeMode.system;
    notifyListeners();

    await _authSub?.cancel();
    _authSub = _auth.authStateChanges.listen((user) async {
      // 초기화 시작 — reloadUser 중복 실행 방지
      _isInitializing = true;
      try {
        authUser = user;
        if (user != null) {
          // 유저 데이터 로드
          userData = await _db.getUser(user.uid);
          if (userData != null) {
            // 목표/우편함 병렬 로드
            await Future.wait([loadGoals(), loadMailbox()]);
            // 출석 체크 (스트릭, 출석 보상)
            await checkAttendance();
            // 미읽음 알림/채팅 수 갱신
            await reloadUnreadNotifCount();
            // 업적 조용히 체크 (토스트 없이)
            await _checkAllAchievementsSilently();
            // FCM 토큰 저장
            await NotificationService.saveFcmToken(user.uid);
          }
        } else {
          // 로그아웃 시 상태 초기화
          userData = null; goals = []; mailbox = [];
          levelUpTo = null; showAttendModal = false; streakModalType = null;
        }
      } catch (e) {
        debugPrint('init 에러: $e');
      } finally {
        // 로딩 완료 — RootScreen에서 화면 전환 트리거
        loading = false;
        _isInitializing = false;
        notifyListeners();
      }
    });
  }

  // 로그인 시 기존 달성 조건 전체 체크 (토스트 없이 조용히)
  // 소셜 업적은 이미 달성된 경우 Firestore 조회 스킵
  Future<void> _checkAllAchievementsSilently() async {
    if (authUser == null || userData == null) return;
    final achieved = Set<String>.from(userData!.achievements);
    final unlockedAt = Map<String, DateTime>.from(userData!.achievementUnlockedAt);
    final newOnes = <String>[];
    final now = DateTime.now();

    void check(String id, bool condition) {
      if (condition && !achieved.contains(id)) {
        achieved.add(id);
        unlockedAt[id] = now;
        newOnes.add(id);
      }
    }

    final doneCount = goals.where((g) => g.done).length;
    check('goal_first',   doneCount >= 1);
    check('goal_10',      doneCount >= 10);
    check('goal_50',      doneCount >= 50);
    check('goal_100',     doneCount >= 100);
    check('streak_7',     userData!.streak >= 7);
    check('streak_30',    userData!.streak >= 30);
    check('streak_100',   userData!.streak >= 100);
    check('streak_365',   userData!.streak >= 365);
    check('focus_1h',     userData!.totalFocusMin >= 60);
    check('focus_10h',    userData!.totalFocusMin >= 600);
    check('focus_50h',    userData!.totalFocusMin >= 3000);
    check('focus_100h',   userData!.totalFocusMin >= 6000);
    check('level_5',      userData!.level >= 5);
    check('level_10',     userData!.level >= 10);
    check('level_20',     userData!.level >= 20);

    // 소셜 업적 — 이미 달성됐으면 Firestore 조회 스킵
    if (!achieved.contains('friend_first')) {
      final friends = await _friendService.getFriends(authUser!.uid);
      check('friend_first', friends.isNotEmpty);
    }
    if (!achieved.contains('diary_first') || !achieved.contains('diary_10')) {
      final diaries = await _diaryService.getMyDiaries(authUser!.uid);
      check('diary_first', diaries.isNotEmpty);
      check('diary_10',    diaries.length >= 10);
    }

    if (newOnes.isEmpty) return;

    // Timestamp Map으로 변환 후 Firestore 업데이트
    final unlockedAtFirestore = unlockedAt.map((k, v) =>
        MapEntry(k, Timestamp.fromDate(v)));

    await _db.updateUser(authUser!.uid, {
      'achievements': achieved.toList(),
      'achievementUnlockedAt': unlockedAtFirestore,
    });
    // 업적 통계 업데이트
    for (final id in newOnes) {
      await _db.incrementAchievementStat(id);
    }
    userData = userData!.copyWith(achievements: achieved, achievementUnlockedAt: unlockedAt);
    notifyListeners();
  }

  // 신규 액션 시 업적 체크 (토스트 표시)
  Future<void> _checkAchievements({
    bool goalCompleted = false,
    bool repeatAllDone = false,
    bool friendAdded = false,
    bool diaryWritten = false,
    int? diaryCount,
  }) async {
    if (authUser == null || userData == null) return;
    final achieved = Set<String>.from(userData!.achievements);
    final unlockedAt = Map<String, DateTime>.from(userData!.achievementUnlockedAt);
    final newOnes = <String>[];
    final now = DateTime.now();

    void check(String id, bool condition) {
      if (condition && !achieved.contains(id)) {
        achieved.add(id);
        unlockedAt[id] = now;
        newOnes.add(id);
      }
    }

    final doneCount = goals.where((g) => g.done).length;
    check('goal_first',   goalCompleted && doneCount >= 1);
    check('goal_10',      doneCount >= 10);
    check('goal_50',      doneCount >= 50);
    check('goal_100',     doneCount >= 100);
    check('repeat_first', repeatAllDone);
    check('streak_7',     userData!.streak >= 7);
    check('streak_30',    userData!.streak >= 30);
    check('streak_100',   userData!.streak >= 100);
    check('streak_365',   userData!.streak >= 365);
    check('focus_1h',     userData!.totalFocusMin >= 60);
    check('focus_10h',    userData!.totalFocusMin >= 600);
    check('focus_50h',    userData!.totalFocusMin >= 3000);
    check('focus_100h',   userData!.totalFocusMin >= 6000);
    check('level_5',      userData!.level >= 5);
    check('level_10',     userData!.level >= 10);
    check('level_20',     userData!.level >= 20);
    check('friend_first', friendAdded);
    check('diary_first',  diaryWritten);
    check('diary_10',     (diaryCount ?? 0) >= 10);

    if (newOnes.isEmpty) return;

    final unlockedAtFirestore = unlockedAt.map((k, v) =>
        MapEntry(k, Timestamp.fromDate(v)));

    await _db.updateUser(authUser!.uid, {
      'achievements': achieved.toList(),
      'achievementUnlockedAt': unlockedAtFirestore,
    });
    for (final id in newOnes) {
      await _db.incrementAchievementStat(id);
    }
    userData = userData!.copyWith(achievements: achieved, achievementUnlockedAt: unlockedAt);

    // 신규 달성 업적 토스트 표시
    for (final id in newOnes) {
      final a = Achievements.findById(id);
      if (a != null) showToast('🏆 업적 달성! ${a.emoji} ${a.title}');
    }
    notifyListeners();
  }

  // 업적 보상 수령 — XP 지급 및 전용 스킨 해금
  Future<void> claimAchievementReward(String achievementId) async {
    if (authUser == null || userData == null) return;
    if (userData!.claimedAchievements.contains(achievementId)) return;
    final a = Achievements.findById(achievementId);
    if (a == null) return;

    final claimed = Set<String>.from(userData!.claimedAchievements)..add(achievementId);
    final prevLevel = userData!.level;
    int newXp = userData!.xp + a.xpReward;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;
    // 레벨업 계산
    while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }

    // 업적 전용 스킨 해금 목록에 추가
    final unlockedSkins = List<String>.from(userData!.streakBadges['unlockedAchieveSkins'] as List? ?? []);
    if (!unlockedSkins.contains(a.id)) unlockedSkins.add(a.id);
    final newStreakBadges = {...userData!.streakBadges, 'unlockedAchieveSkins': unlockedSkins};

    await _db.updateUser(authUser!.uid, {
      'claimedAchievements': claimed.toList(),
      'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext,
      'streakBadges': newStreakBadges,
    });
    // streakBadges는 copyWith에 없으므로 UserModel 직접 재생성
    userData = UserModel(
      uid: userData!.uid, name: userData!.name, email: userData!.email,
      photoURL: userData!.photoURL, level: newLevel, xp: newXp,
      xpToNext: newXpToNext, streak: userData!.streak, maxStreak: userData!.maxStreak,
      lastStreakDate: userData!.lastStreakDate, reviveItem: userData!.reviveItem,
      streakBadges: newStreakBadges, totalFocusMin: userData!.totalFocusMin,
      lastAttendDate: userData!.lastAttendDate, character: userData!.character,
      onboardingDone: userData!.onboardingDone,
      withdrawScheduledAt: userData!.withdrawScheduledAt,
      createdAt: userData!.createdAt,
      achievements: userData!.achievements,
      claimedAchievements: claimed,
      equippedAchievement: userData!.equippedAchievement,
      achievementUnlockedAt: userData!.achievementUnlockedAt,
    );
    // 레벨업 발생 시 모달 표시 및 공개 프로필 업데이트
    if (newLevel > prevLevel) {
      levelUpTo = newLevel;
      await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()});
    }
    showToast('🎁 보상 수령! +${a.xpReward} XP · ${a.emoji} 스킨 해금');
    notifyListeners();
  }

  // 광고 시청으로 스트릭 부활 아이템 지급
  Future<void> addReviveItem(int count) async {
    if (authUser == null || userData == null) return;
    final newCount = userData!.reviveItem + count;
    await _db.updateUser(authUser!.uid, {'reviveItem': newCount});
    userData = userData!.copyWith(reviveItem: newCount);
    notifyListeners();
  }

  // 업적 칭호 장착/해제
  Future<void> equipAchievement(String? achievementId) async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'equippedAchievement': achievementId});
    await _db.updatePublicProfile(authUser!.uid, {'equippedAchievement': achievementId, 'name': userData!.name, 'level': userData!.level, 'character': userData!.character.toMap()});
    userData = userData!.copyWith(equippedAchievement: achievementId);
    notifyListeners();
  }

  // 해금된 업적 전용 스킨 목록
  List<String> get unlockedAchieveSkins {
    if (userData == null) return [];
    return List<String>.from(userData!.streakBadges['unlockedAchieveSkins'] as List? ?? []);
  }

  // 테마 변경 및 SharedPreferences 저장
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
    notifyListeners();
  }

  // 수동 유저 데이터 리로드 — authStateChanges 완료 후 실행
  Future<void> reloadUser() async {
    // authStateChanges가 처리 중이면 완료될 때까지 대기
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    // 이미 로드 완료된 경우 스킵
    if (!loading && userData != null) return;
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      authUser = user;
      userData = await _db.getUser(user.uid);
      if (userData != null) {
        await Future.wait([loadGoals(), loadMailbox()]);
        await checkAttendance();
        await _checkAllAchievementsSilently();
      }
    } catch (e) {
      debugPrint('reloadUser 에러: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // 목표 목록 로드
  Future<void> loadGoals() async {
    if (authUser == null) return;
    goals = await _db.getGoals(authUser!.uid);
    notifyListeners();
  }

  // 우편함 로드
  Future<void> loadMailbox() async {
    if (authUser == null) return;
    mailbox = await _db.getMailbox(authUser!.uid);
    notifyListeners();
  }

  // 출석 체크 — 스트릭 계산, 마일스톤 확인, 출석 보상 발송
  Future<void> checkAttendance() async {
    if (userData == null || authUser == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    // 오늘 이미 출석했으면 스킵
    if (userData!.lastAttendDate == today) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_streak') ?? true) await NotificationService.cancelNotification(2);
      return;
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    // 어제도 아니고 오늘도 아니면 스트릭 끊김
    if (userData!.lastAttendDate.isNotEmpty && userData!.lastAttendDate != yesterday && userData!.streak > 0) {
      brokenStreakPrev = userData!.streak;
      await _db.updateUser(authUser!.uid, {'lastAttendDate': today, 'streak': 1});
      userData = userData!.copyWith(lastAttendDate: today, streak: 1);
      streakModalType = 'broken';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_streak') ?? true) await NotificationService.cancelNotification(2);
      notifyListeners();
      return;
    }
    // 스트릭 증가
    int newStreak = userData!.lastAttendDate == yesterday ? userData!.streak + 1 : 1;
    int newMaxStreak = newStreak > userData!.maxStreak ? newStreak : userData!.maxStreak;
    await _db.updateUser(authUser!.uid, {'lastAttendDate': today, 'streak': newStreak, 'maxStreak': newMaxStreak});
    // 출석 보상 우편 발송
    await _db.sendAttendanceMail(authUser!.uid, newStreak);
    userData = userData!.copyWith(lastAttendDate: today, streak: newStreak, maxStreak: newMaxStreak);
    await loadMailbox();
    // 스트릭 위기 알림 재스케줄
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_streak') ?? true) {
      await NotificationService.cancelNotification(2);
      await NotificationService.scheduleStreakRiskReminder(newStreak);
    }
    // 마일스톤 도달 시 모달 표시
    final milestone = _milestones.firstWhere((m) => m['days'] == newStreak, orElse: () => <String, Object>{});
    if (milestone.isNotEmpty) {
      currentMilestone = milestone.map((k, v) => MapEntry(k, v));
      streakModalType = 'milestone';
    } else {
      showAttendModal = true;
    }
    await _checkAchievements();
    notifyListeners();
  }

  void dismissAttendModal() { showAttendModal = false; notifyListeners(); }
  void dismissStreakModal() { streakModalType = null; currentMilestone = null; notifyListeners(); }

  // 마일스톤 XP 수령
  Future<void> claimMilestoneXp() async {
    if (authUser == null || userData == null || currentMilestone == null) return;
    final xpGain = currentMilestone!['xp'] as int;
    final prevLevel = userData!.level;
    int newXp = userData!.xp + xpGain;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;
    while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
    if (newLevel > prevLevel) levelUpTo = newLevel;
    streakModalType = null; currentMilestone = null;
    notifyListeners();
  }

  // 부활 아이템으로 스트릭 복구
  Future<void> reviveStreakByItem() async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'streak': brokenStreakPrev, 'reviveItem': userData!.reviveItem - 1});
    userData = userData!.copyWith(streak: brokenStreakPrev, reviveItem: userData!.reviveItem - 1);
    streakModalType = null; notifyListeners();
  }

  // 광고 시청으로 스트릭 복구
  Future<void> reviveStreakByAd() async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'streak': brokenStreakPrev});
    userData = userData!.copyWith(streak: brokenStreakPrev);
    streakModalType = null; notifyListeners();
  }

  // 스트릭 포기 (1로 초기화)
  Future<void> resetStreak() async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'streak': 1});
    userData = userData!.copyWith(streak: 1);
    streakModalType = null; notifyListeners();
  }

  // 목표 완료 처리 — XP 지급, 레벨업, 업적 체크
  Future<void> completeGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    // 중복 처리 방지
    if (_processingGoals.contains(goalId)) return;
    _processingGoals.add(goalId);
    try {
      // 최신 유저 데이터로 XP 계산 (동시 완료 시 정합성 보장)
      final freshUser = await _db.getUser(authUser!.uid);
      if (freshUser == null) return;
      userData = freshUser;
      final goal = goals.firstWhere((g) => g.id == goalId);
      if (goal.done) return;
      await _db.updateGoal(authUser!.uid, goalId, {'done': true, 'progress': 100, 'completedAt': FieldValue.serverTimestamp()});
      final prevLevel = userData!.level;
      final isRepeat = goal.repeatId != null;
      int xpGain = isRepeat ? goal.repeatXp : goal.xp;
      bool repeatAllDone = false;

      if (isRepeat) {
        final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
        final totalCount = repeatGoals.length;
        final doneCount = repeatGoals.where((g) => g.done).length + 1;
        if (doneCount >= totalCount) {
          if (doneCount == totalCount) {
            // 전체 완료 보너스 XP 추가
            xpGain += goal.xp; repeatAllDone = true;
            showToast('🏆 반복 목표 전체 완료! +${goal.repeatXp + goal.xp} XP 획득');
          } else {
            final pct = (doneCount / totalCount * 100).round();
            showToast('🎉 목표 완료! +$xpGain XP 획득');
            showToast('달성률 $pct%로 반복 목표 종료');
          }
          int newXp = userData!.xp + xpGain;
          int newLevel = userData!.level;
          int newXpToNext = userData!.xpToNext;
          while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
          await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
          userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
          if (newLevel > prevLevel) { levelUpTo = newLevel; await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()}); }
          await loadGoals();
          await _checkAchievements(goalCompleted: true, repeatAllDone: repeatAllDone);
          notifyListeners(); return;
        }
      }

      showToast('🎉 목표 완료! +$xpGain XP 획득');
      int newXp = userData!.xp + xpGain;
      int newLevel = userData!.level;
      int newXpToNext = userData!.xpToNext;
      while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
      if (newLevel > prevLevel) { levelUpTo = newLevel; await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()}); }
      await loadGoals();
      await _checkAchievements(goalCompleted: true);
      notifyListeners();
    } finally {
      _processingGoals.remove(goalId);
    }
  }

  // 레벨업 모달 닫기
  void dismissLevelUp() { levelUpTo = null; notifyListeners(); }

  // 목표 완료 취소 — XP 차감
  Future<void> uncompleteGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    if (_processingGoals.contains(goalId)) return;
    _processingGoals.add(goalId);
    try {
      final freshUser = await _db.getUser(authUser!.uid);
      if (freshUser == null) return;
      userData = freshUser;
      final goal = goals.firstWhere((g) => g.id == goalId);
      if (!goal.done) return;
      await _db.updateGoal(authUser!.uid, goalId, {'done': false, 'progress': 0, 'completedAt': null});
      final isRepeat = goal.repeatId != null;
      int xpDeduct = isRepeat ? goal.repeatXp : goal.xp;
      // 전체 완료 보너스 XP도 함께 차감
      if (isRepeat) {
        final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
        if (repeatGoals.where((g) => g.done).length >= repeatGoals.length) xpDeduct += goal.xp;
      }
      int newXp = userData!.xp - xpDeduct;
      int newLevel = userData!.level;
      int newXpToNext = userData!.xpToNext;
      // 레벨 다운 처리
      while (newXp < 0 && newLevel > 1) { newLevel--; newXpToNext = (newXpToNext / 1.15).round(); newXp += newXpToNext; }
      newXp = newXp.clamp(0, 999999);
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
      showToast('목표 완료를 취소했어요');
      await loadGoals(); notifyListeners();
    } finally {
      _processingGoals.remove(goalId);
    }
  }

  // 단일 목표 삭제
  Future<void> removeGoal(String goalId) async {
    if (authUser == null) return;
    await _db.deleteGoal(authUser!.uid, goalId);
    showToast('목표를 삭제했어요');
    await loadGoals(); notifyListeners();
  }

  // 반복 목표 전체 삭제
  Future<void> removeRepeatGoals(String repeatId) async {
    if (authUser == null) return;
    await _db.deleteRepeatGoals(authUser!.uid, repeatId);
    showToast('반복 목표를 삭제했어요');
    await loadGoals(); notifyListeners();
  }

  // 반복 목표 삭제 시 팝업용 정보 반환
  Map<String, dynamic>? getRepeatInfo(String goalId) {
    final goal = goals.firstWhere((g) => g.id == goalId);
    if (goal.repeatId == null) return null;
    final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
    return {'repeatId': goal.repeatId, 'total': repeatGoals.length, 'undone': repeatGoals.where((g) => !g.done).length};
  }

  // 우편 보상 수령 — XP 지급 및 부활 아이템 지급
  Future<void> claimMailReward(String mailId) async {
    if (authUser == null || userData == null) return;
    final mail = mailbox.firstWhere((m) => m.id == mailId);
    if (mail.claimed) return;
    await _db.claimMail(authUser!.uid, mailId);
    final prevLevel = userData!.level;
    int newXp = userData!.xp + mail.reward.xp;
    int newRevive = userData!.reviveItem + mail.reward.reviveItem;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;
    while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'reviveItem': newRevive});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, reviveItem: newRevive);
    if (newLevel > prevLevel) levelUpTo = newLevel;
    showToast('보상을 수령했어요!');
    await loadMailbox(); notifyListeners();
  }

  // 우편 삭제
  Future<void> deleteMailItem(String mailId) async {
    if (authUser == null) return;
    await _db.deleteMail(authUser!.uid, mailId);
    await loadMailbox(); notifyListeners();
  }

  // 캐릭터 변경 — 공개 프로필 및 다이어리 일괄 업데이트
  Future<void> updateCharacter(Map<String, dynamic> updates) async {
    if (authUser == null || userData == null) return;
    final current = userData!.character;
    final newChar = CharacterModel(
      skin: updates['skin'] ?? current.skin,
      badge: updates['badge'] ?? current.badge,
      frame: updates['frame'] ?? current.frame,
    );
    await _db.updateUser(authUser!.uid, {'character': newChar.toMap()});
    await _db.updatePublicProfile(authUser!.uid, {'character': newChar.toMap(), 'name': userData!.name, 'level': userData!.level});
    await _diaryService.updateAuthorInfo(authUser!.uid, userData!.name, newChar.toMap(), userData!.level, equippedAchievement: userData!.equippedAchievement);
    userData = userData!.copyWith(character: newChar);
    notifyListeners();
  }

  // 닉네임 변경 — 공개 프로필 및 다이어리 일괄 업데이트
  Future<void> updateName(String name) async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'name': name});
    await _db.updatePublicProfile(authUser!.uid, {'name': name});
    await _diaryService.updateAuthorInfo(authUser!.uid, name, userData!.character.toMap(), userData!.level, equippedAchievement: userData!.equippedAchievement);
    userData = userData!.copyWith(name: name);
    notifyListeners();
  }

  // 온보딩 완료 처리
  Future<void> completeOnboarding(String nickname) async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'name': nickname, 'onboardingDone': true});
    userData = userData!.copyWith(name: nickname, onboardingDone: true);
    notifyListeners();
  }

  // 친구 추가 시 업적 체크
  Future<void> onFriendAdded() async {
    await _checkAchievements(friendAdded: true);
  }

  // 다이어리 작성 시 업적 체크
  Future<void> onDiaryWritten(int diaryCount) async {
    await _checkAchievements(diaryWritten: true, diaryCount: diaryCount);
  }

  // 로그아웃 — 먼저 루트로 이동 후 FCM 토큰 삭제, 상태 초기화
  // GlobalKey 충돌 방지를 위해 popUntil을 signOut 전에 먼저 실행
  Future<void> signOut() async {
    final uid = authUser?.uid;
    // 먼저 루트 라우트로 이동 — MainNav가 트리에서 제거된 후 상태 초기화
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (uid != null) await NotificationService.deleteFcmToken(uid);
    await _auth.signOut();
    authUser = null; userData = null; goals = []; mailbox = [];
    notifyListeners();
  }

  // 토스트 메시지 큐에 추가
  void showToast(String message) {
    _toastQueue.add(message);
    if (!_toastRunning) _processToastQueue();
  }

  // notifyListeners 방식 토스트 — main_nav Stack에서 렌더링
  Future<void> _processToastQueue() async {
    if (_toastQueue.isEmpty) { _toastRunning = false; return; }
    _toastRunning = true;
    while (_toastQueue.isNotEmpty) {
      toast = _toastQueue.removeAt(0);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1500));
      toast = null; notifyListeners();
      if (_toastQueue.isNotEmpty) await Future.delayed(const Duration(milliseconds: 200));
    }
    _toastRunning = false;
  }

  // 집중 세션 저장 — XP 지급 및 랭킹 반영
  Future<void> saveFocusSession(int minutes) async {
    if (authUser == null || userData == null) return;
    await _db.saveFocusSession(authUser!.uid, minutes);
    final prevLevel = userData!.level;
    // 집중 시간 XP: 분 + (분 / 10) * 분 (긴 집중일수록 보너스)
    final xpGain = minutes + (minutes ~/ 10) * minutes;
    int newXp = userData!.xp + xpGain;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;
    int newTotalFocus = userData!.totalFocusMin + minutes;
    while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalFocusMin': newTotalFocus});
    // 오늘 집중 시간 랭킹 업데이트
    await _db.updateTodayFocus(authUser!.uid, minutes);
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalFocusMin: newTotalFocus);
    if (newLevel > prevLevel) levelUpTo = newLevel;
    await _checkAchievements();
    notifyListeners();
  }

  // 회원 탈퇴 예약 — 30일 유예기간 후 삭제
  Future<void> scheduleWithdraw() async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'withdrawScheduledAt': DateTime.now().add(const Duration(days: 30))});
    await signOut();
  }

  // 회원 탈퇴 취소
  Future<void> cancelWithdraw() async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'withdrawScheduledAt': null});
    userData = userData!.copyWith(withdrawScheduledAt: null);
    notifyListeners();
  }
}