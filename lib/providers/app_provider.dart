import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
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

  // 사용자 포인트 색상 — 기본값은 검정
  Color _primaryColor = AppTheme.defaultPrimary;
  Color get userPrimaryColor => _primaryColor;

  // 사용자 배경 색상 — 기본값은 라이트 배경
  Color _bgColor = AppTheme.background;
  Color get userBgColor => _bgColor;

  // 커스텀 테마 사용 여부 — 사용자 설정 테마 모드
  bool _isCustomTheme = false;
  bool get isCustomTheme => _isCustomTheme;
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
  // 레벨별 호칭 — 10단계 구간
  static String levelTitle(int level) {
    if (level >= 100) return '불멸자';
    if (level >= 76)  return '신화의 존재';
    if (level >= 51)  return '전설';
    if (level >= 36)  return '영웅';
    if (level >= 21)  return '탐험가';
    if (level >= 11)  return '학자';
    if (level >= 6)   return '전사';
    if (level >= 3)   return '견습생';
    return '초보 모험가';
  }

  // 레벨업 보상 우편 발송 — 특정 레벨 달성 시 특별 보상
  static Map<String, dynamic>? _getLevelReward(int level) {
    // 5레벨마다 보상, 10레벨마다 더 큰 보상, 50/100은 특별 보상
    if (level == 100) return {'xp': 10000, 'reviveItem': 5, 'label': '🌟 레벨 100 달성! 불멸자의 증표'};
    if (level == 50)  return {'xp': 3000,  'reviveItem': 3, 'label': '💎 레벨 50 달성! 전설의 시작'};
    if (level % 10 == 0) return {'xp': level * 20, 'reviveItem': 2, 'label': '🎊 레벨 $level 달성!'};
    if (level % 5 == 0)  return {'xp': level * 10, 'reviveItem': 1, 'label': '🎁 레벨 $level 달성!'};
    return null;
  }



  // 기존 유저 마이그레이션 — totalXp 없으면 1.15배 역산 → 1.05배 재계산
  Future<void> _migrateTotalXpIfNeeded(String uid) async {
    if (userData == null) return;
    // fromMap에서 totalXp가 없으면 역산값이 들어있음
    // Firestore에 실제로 저장됐는지 확인하기 위해 xpToNext로 판단
    // 1.05배 기준 xpToNext와 다르면 마이그레이션 필요
    final expectedXpToNext = xpRequired(userData!.level);
    final needsMigration = (userData!.xpToNext - expectedXpToNext).abs() > 5;
    if (!needsMigration) return;

    // 1.15배 기준으로 totalXp 역산
    final migratedTotal = _calcTotalXpLegacy(userData!.level, userData!.xp);
    // 1.05배 기준으로 level/xp/xpToNext 재계산
    final r = calcLevelFromTotal(migratedTotal);
    final prevLevel = userData!.level;
    await _db.updateUser(uid, {
      'totalXp': migratedTotal,
      'level': r.level,
      'xp': r.xp,
      'xpToNext': r.xpToNext,
    });
    userData = userData!.copyWith(
      totalXp: migratedTotal,
      level: r.level,
      xp: r.xp,
      xpToNext: r.xpToNext,
    );
    if (r.level != prevLevel) {
      await _db.updatePublicProfile(uid, {
        'level': r.level,
        'name': userData!.name,
        'character': userData!.character.toMap(),
      });
    }
    debugPrint('마이그레이션 완료: Lv${prevLevel}→Lv${r.level}, totalXp=$migratedTotal');
  }

  // 1.15배 기준 totalXp 역산 (마이그레이션용)
  static int _calcTotalXpLegacy(int level, int xp) {
    int total = xp;
    int req = 100;
    for (int i = 1; i < level; i++) {
      total += req;
      req = (req * 1.15).round();
    }
    return total;
  }

  // ── XP / 레벨 헬퍼 ──────────────────────────────────────────────────────

  // 레벨 n에서 다음 레벨까지 필요한 XP (1.05배 배율)
  static int xpRequired(int level) {
    int req = 100;
    for (int i = 1; i < level; i++) req = (req * 1.05).round();
    return req;
  }

  // totalXp로 level, xp, xpToNext 계산
  static ({int level, int xp, int xpToNext}) calcLevelFromTotal(int totalXp) {
    int level = 1;
    int remaining = totalXp;
    while (true) {
      final req = xpRequired(level);
      if (remaining < req) return (level: level, xp: remaining, xpToNext: req);
      remaining -= req;
      level++;
    }
  }

  // XP 획득 — totalXp 기반으로 level/xp/xpToNext 재계산
  Map<String, dynamic> _applyXp(int currentTotalXp, int gain) {
    final newTotal = currentTotalXp + gain;
    final r = calcLevelFromTotal(newTotal);
    return {'totalXp': newTotal, 'xp': r.xp, 'level': r.level, 'xpToNext': r.xpToNext};
  }

  // XP 차감 — totalXp 기반으로 level/xp/xpToNext 재계산
  Map<String, dynamic> _deductXp(int currentTotalXp, int loss) {
    final newTotal = (currentTotalXp - loss).clamp(0, 999999999);
    final r = calcLevelFromTotal(newTotal);
    return {'totalXp': newTotal, 'xp': r.xp, 'level': r.level, 'xpToNext': r.xpToNext};
  }

  // 앱 초기화 — 테마 로드 후 Auth 상태 구독 시작
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('themeMode') ?? 'system';
    themeMode = savedTheme == 'light' ? ThemeMode.light
        : savedTheme == 'dark' ? ThemeMode.dark
        : ThemeMode.system;
    // 커스텀 테마 로드
    _isCustomTheme = prefs.getBool('isCustomTheme') ?? false;
    // 포인트 색상 로드
    final colorVal = prefs.getInt('primaryColor');
    if (colorVal != null) _primaryColor = Color(colorVal);
    // 배경 색상 로드
    final bgVal = prefs.getInt('bgColor');
    if (bgVal != null) _bgColor = Color(bgVal);
    notifyListeners();

    await _authSub?.cancel();
    _authSub = _auth.authStateChanges.listen((user) async {
      // 초기화 시작 — reloadUser 중복 실행 방지
      _isInitializing = true;
      try {
        authUser = user;
        debugPrint('🔥 authStateChanges: user=${user?.uid}');
        if (user != null) {
          // 유저 데이터 로드 — 신규 회원가입 시 문서 생성 지연 대응해 최대 3회 재시도
          for (int i = 0; i < 3; i++) {
            userData = await _db.getUser(user.uid);
            if (userData != null) break;
            await Future.delayed(const Duration(seconds: 1));
          }
          debugPrint('🔥 userData=${userData?.uid}, null=${userData == null}');
          if (userData != null) {
            // 목표/우편함 병렬 로드
            await Future.wait([loadGoals(), loadMailbox()]);
            // 출석 체크 (스트릭, 출석 보상)
            await checkAttendance();
            // 미읽음 알림/채팅 수 갱신
            await reloadUnreadNotifCount();
            // 업적 조용히 체크 (토스트 없이)
            await _checkAllAchievementsSilently();
            // 기존 유저 totalXp 마이그레이션
            // totalXp가 없으면 1.15배 기준으로 역산 후 1.05배 기준으로 재계산
            await _migrateTotalXpIfNeeded(user.uid);
            // FCM 토큰 저장
            debugPrint('🔥 saveFcmToken 호출: ${user.uid}');
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
    final shortDone = goals.where((g) => g.done && g.type == 'short').length;
    final longDone  = goals.where((g) => g.done && g.type == 'long').length;
    final repeatSets = goals.where((g) => g.done && g.repeatId != null).length;

    // 목표 업적
    check('goal_first',      doneCount >= 1);
    check('goal_10',         doneCount >= 10);
    check('goal_50',         doneCount >= 50);
    check('goal_100',        doneCount >= 100);
    check('goal_300',        doneCount >= 300);
    check('repeat_first',    repeatSets >= 1);
    check('repeat_10',       repeatSets >= 10);
    check('short_goal_50',   shortDone >= 50);
    check('long_goal_10',    longDone >= 10);

    // 스트릭 업적
    check('streak_3',        userData!.streak >= 3);
    check('streak_7',        userData!.streak >= 7);
    check('streak_14',       userData!.streak >= 14);
    check('streak_30',       userData!.streak >= 30);
    check('streak_60',       userData!.streak >= 60);
    check('streak_100',      userData!.streak >= 100);
    check('streak_365',      userData!.streak >= 365);

    // 집중 업적
    check('focus_1h',        userData!.totalFocusMin >= 60);
    check('focus_5h',        userData!.totalFocusMin >= 300);
    check('focus_10h',       userData!.totalFocusMin >= 600);
    check('focus_30h',       userData!.totalFocusMin >= 1800);
    check('focus_50h',       userData!.totalFocusMin >= 3000);
    check('focus_100h',      userData!.totalFocusMin >= 6000);
    check('focus_200h',      userData!.totalFocusMin >= 12000);

    // 레벨 업적
    check('level_5',         userData!.level >= 5);
    check('level_10',        userData!.level >= 10);
    check('level_20',        userData!.level >= 20);
    check('level_30',        userData!.level >= 30);
    check('level_50',        userData!.level >= 50);
    check('level_75',        userData!.level >= 75);
    check('level_100',       userData!.level >= 100);

    // 소셜 업적 — 이미 달성됐으면 Firestore 조회 스킵
    if (!achieved.contains('friend_first') || !achieved.contains('friend_5') || !achieved.contains('friend_10')) {
      final friends = await _friendService.getFriends(authUser!.uid);
      check('friend_first',  friends.isNotEmpty);
      check('friend_5',      friends.length >= 5);
      check('friend_10',     friends.length >= 10);
    }
    if (!achieved.contains('diary_first') || !achieved.contains('diary_10') || !achieved.contains('diary_50')) {
      final diaries = await _diaryService.getMyDiaries(authUser!.uid);
      check('diary_first',   diaries.isNotEmpty);
      check('diary_10',      diaries.length >= 10);
      check('diary_50',      diaries.length >= 50);
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
    int? friendCount,
    bool chatStarted = false,
    int? rankingPosition,
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
    final shortDone = goals.where((g) => g.done && g.type == 'short').length;
    final longDone  = goals.where((g) => g.done && g.type == 'long').length;
    final repeatSets = goals.where((g) => g.done && g.repeatId != null).length;

    // 목표 업적
    check('goal_first',      goalCompleted && doneCount >= 1);
    check('goal_10',         doneCount >= 10);
    check('goal_50',         doneCount >= 50);
    check('goal_100',        doneCount >= 100);
    check('goal_300',        doneCount >= 300);
    check('repeat_first',    repeatAllDone);
    check('repeat_10',       repeatSets >= 10);
    check('short_goal_50',   shortDone >= 50);
    check('long_goal_10',    longDone >= 10);

    // 스트릭 업적
    check('streak_3',        userData!.streak >= 3);
    check('streak_7',        userData!.streak >= 7);
    check('streak_14',       userData!.streak >= 14);
    check('streak_30',       userData!.streak >= 30);
    check('streak_60',       userData!.streak >= 60);
    check('streak_100',      userData!.streak >= 100);
    check('streak_365',      userData!.streak >= 365);

    // 집중 업적
    check('focus_1h',        userData!.totalFocusMin >= 60);
    check('focus_5h',        userData!.totalFocusMin >= 300);
    check('focus_10h',       userData!.totalFocusMin >= 600);
    check('focus_30h',       userData!.totalFocusMin >= 1800);
    check('focus_50h',       userData!.totalFocusMin >= 3000);
    check('focus_100h',      userData!.totalFocusMin >= 6000);
    check('focus_200h',      userData!.totalFocusMin >= 12000);

    // 레벨 업적
    check('level_5',         userData!.level >= 5);
    check('level_10',        userData!.level >= 10);
    check('level_20',        userData!.level >= 20);
    check('level_30',        userData!.level >= 30);
    check('level_50',        userData!.level >= 50);
    check('level_75',        userData!.level >= 75);
    check('level_100',       userData!.level >= 100);

    // 소셜 업적
    check('friend_first',    friendAdded);
    check('friend_5',        (friendCount ?? 0) >= 5);
    check('friend_10',       (friendCount ?? 0) >= 10);
    check('diary_first',     diaryWritten);
    check('diary_10',        (diaryCount ?? 0) >= 10);
    check('diary_50',        (diaryCount ?? 0) >= 50);
    check('chat_first',      chatStarted);
    check('ranking_top3',    rankingPosition != null && rankingPosition! <= 3);
    check('ranking_top1',    rankingPosition != null && rankingPosition! == 1);

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
    final _r1 = _applyXp(userData!.totalXp, a.xpReward);
    int newXp = _r1['xp'] as int;
    int newLevel = _r1['level'] as int;
    int newXpToNext = _r1['xpToNext'] as int;
    final newTotalXp = _r1['totalXp'] as int;

    // 업적 전용 스킨 해금 목록에 추가
    final unlockedSkins = List<String>.from(userData!.streakBadges['unlockedAchieveSkins'] as List? ?? []);
    if (!unlockedSkins.contains(a.id)) unlockedSkins.add(a.id);
    final newStreakBadges = {...userData!.streakBadges, 'unlockedAchieveSkins': unlockedSkins};

    await _db.updateUser(authUser!.uid, {
      'claimedAchievements': claimed.toList(),
      'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp,
      'streakBadges': newStreakBadges,
    });
    // streakBadges는 copyWith에 없으므로 UserModel 직접 재생성
    userData = UserModel(
      uid: userData!.uid, name: userData!.name, email: userData!.email,
      photoURL: userData!.photoURL, level: newLevel, xp: newXp,
      xpToNext: newXpToNext, totalXp: newTotalXp, streak: userData!.streak, maxStreak: userData!.maxStreak,
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
    // 업적 스킨 해금 후 공개 프로필 + 다이어리 작성자 정보 업데이트
    await _db.updatePublicProfile(authUser!.uid, {
      'name': userData!.name,
      'level': newLevel,
      'character': userData!.character.toMap(),
      'equippedAchievement': userData!.equippedAchievement,
    });
    await _diaryService.updateAuthorInfo(
      authUser!.uid, userData!.name, userData!.character.toMap(), newLevel,
      equippedAchievement: userData!.equippedAchievement,
    );
    // 레벨업 발생 시 모달 표시
    if (newLevel > prevLevel) {
      levelUpTo = newLevel;
      await _handleLevelUpReward(prevLevel, newLevel);
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

  // 업적 칭호 장착/해제 — 공개 프로필 + 다이어리 글 작성자 정보 동시 업데이트
  Future<void> equipAchievement(String? achievementId) async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'equippedAchievement': achievementId});
    await _db.updatePublicProfile(authUser!.uid, {'equippedAchievement': achievementId, 'name': userData!.name, 'level': userData!.level, 'character': userData!.character.toMap()});
    // 게시판 글 작성자 칭호도 업데이트
    await _diaryService.updateAuthorInfo(authUser!.uid, userData!.name, userData!.character.toMap(), userData!.level, equippedAchievement: achievementId);
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

  // 커스텀 테마 모드 설정
  Future<void> setCustomTheme(bool enabled) async {
    _isCustomTheme = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCustomTheme', enabled);
    notifyListeners();
  }

  // 포인트 색상 변경 — SharedPreferences에 저장
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', color.value);
    notifyListeners();
  }

  // 배경 색상 변경 — SharedPreferences에 저장
  Future<void> setBgColor(Color color) async {
    _bgColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bgColor', color.value);
    notifyListeners();
  }

  // 커스텀 테마 색상 초기화
  Future<void> resetCustomColors() async {
    _primaryColor = AppTheme.defaultPrimary;
    _bgColor = AppTheme.background;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('primaryColor');
    await prefs.remove('bgColor');
    notifyListeners();
  }

  // 수동 유저 데이터 리로드 — authStateChanges 완료 후 실행
  // 강제 사용자 데이터 갱신 — 프로필 이미지 등 변경 후 호출
  Future<void> forceReloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      userData = await _db.getUser(user.uid);
      notifyListeners();
    } catch (e) {
      debugPrint('forceReloadUser 에러: \$e');
    }
  }

  Future<void> reloadUser() async {
    // authStateChanges가 처리 중이면 완료될 때까지 대기
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    // 이미 로드 완료된 경우 스킵 — forceReload 없을 때만
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
    final _r2 = _applyXp(userData!.totalXp, xpGain);
    int newXp = _r2['xp'] as int;
    int newLevel = _r2['level'] as int;
    int newXpToNext = _r2['xpToNext'] as int;
    final newTotalXp = _r2['totalXp'] as int;
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
    if (newLevel > prevLevel) { levelUpTo = newLevel; await _handleLevelUpReward(prevLevel, newLevel); }
    streakModalType = null; currentMilestone = null;
    notifyListeners();
  }

  // 부활 아이템으로 스트릭 복구 — 복구 후 출석 모달 표시 + 보상 우편 발송
  Future<void> reviveStreakByItem() async {
    if (authUser == null || userData == null) return;
    final revivedStreak = brokenStreakPrev;
    await _db.updateUser(authUser!.uid, {'streak': revivedStreak, 'reviveItem': userData!.reviveItem - 1});
    userData = userData!.copyWith(streak: revivedStreak, reviveItem: userData!.reviveItem - 1);
    await _db.sendAttendanceMail(authUser!.uid, revivedStreak);
    await loadMailbox();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_streak') ?? true) {
      await NotificationService.cancelNotification(2);
      await NotificationService.scheduleStreakRiskReminder(revivedStreak);
    }
    streakModalType = null;
    // 복구 후 출석 모달 표시
    showAttendModal = true;
    notifyListeners();
  }

  // 광고 시청으로 스트릭 복구 — 복구 후 출석 모달 표시 + 보상 우편 발송
  Future<void> reviveStreakByAd() async {
    if (authUser == null || userData == null) return;
    final revivedStreak = brokenStreakPrev;
    await _db.updateUser(authUser!.uid, {'streak': revivedStreak});
    userData = userData!.copyWith(streak: revivedStreak);
    await _db.sendAttendanceMail(authUser!.uid, revivedStreak);
    await loadMailbox();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_streak') ?? true) {
      await NotificationService.cancelNotification(2);
      await NotificationService.scheduleStreakRiskReminder(revivedStreak);
    }
    streakModalType = null;
    // 복구 후 출석 모달 표시
    showAttendModal = true;
    notifyListeners();
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
          final _rg1 = _applyXp(userData!.totalXp, xpGain);
          int newXp = _rg1['xp'] as int;
          int newLevel = _rg1['level'] as int;
          int newXpToNext = _rg1['xpToNext'] as int;
          final newTotalXp = _rg1['totalXp'] as int;
          await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp, 'totalXp': newTotalXp});
          userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
          if (newLevel > prevLevel) { levelUpTo = newLevel; await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()}); await _handleLevelUpReward(prevLevel, newLevel); }
          await loadGoals();
          await _checkAchievements(goalCompleted: true, repeatAllDone: repeatAllDone);
          notifyListeners(); return;
        }
      }

      showToast('🎉 목표 완료! +$xpGain XP 획득');
      final newXpResult = _applyXp(userData!.totalXp, xpGain);
      int newXp = newXpResult['xp'] as int;
      int newLevel = newXpResult['level'] as int;
      int newXpToNext = newXpResult['xpToNext'] as int;
      final newTotalXp = newXpResult['totalXp'] as int;
      while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.05).round(); }
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp, 'totalXp': newTotalXp});
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
      if (newLevel > prevLevel) { levelUpTo = newLevel; await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()}); await _handleLevelUpReward(prevLevel, newLevel); }
      await loadGoals();
      await _checkAchievements(goalCompleted: true);
      notifyListeners();
    } finally {
      _processingGoals.remove(goalId);
    }
  }

  // 단일 업적 체크 헬퍼 — 세션 카운트 등 별도 체크용
  Future<void> _checkSingleAchievement(String id, bool condition) async {
    if (authUser == null || userData == null) return;
    if (!condition || userData!.achievements.contains(id)) return;
    final achieved = Set<String>.from(userData!.achievements)..add(id);
    final unlockedAt = Map<String, DateTime>.from(userData!.achievementUnlockedAt)
      ..[id] = DateTime.now();
    final unlockedAtFs = unlockedAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v)));
    await _db.updateUser(authUser!.uid, {'achievements': achieved.toList(), 'achievementUnlockedAt': unlockedAtFs});
    await _db.incrementAchievementStat(id);
    userData = userData!.copyWith(achievements: achieved, achievementUnlockedAt: unlockedAt);
    final a = Achievements.findById(id);
    if (a != null) showToast('🏆 업적 달성! ${a.emoji} ${a.title}');
    notifyListeners();
  }

  // 레벨업 모달 닫기
  void dismissLevelUp() { levelUpTo = null; notifyListeners(); }

  // 레벨업 보상 처리 — 특정 레벨 달성 시 보상 우편 발송
  Future<void> _handleLevelUpReward(int prevLevel, int newLevel) async {
    if (authUser == null) return;
    for (int lv = prevLevel + 1; lv <= newLevel; lv++) {
      final reward = _getLevelReward(lv);
      if (reward != null) {
        await _db.sendLevelUpMail(authUser!.uid, lv, reward);
      }
    }
  }

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
      final _r4b = _deductXp(userData!.totalXp, xpDeduct);
      int newXp = _r4b['xp'] as int;
      int newLevel = _r4b['level'] as int;
      int newXpToNext = _r4b['xpToNext'] as int;
      final newTotalXp = _r4b['totalXp'] as int;
      // 레벨 다운 처리
      while (newXp < 0 && newLevel > 1) { newLevel--; newXpToNext = (newXpToNext / 1.05).round(); newXp += newXpToNext; }
      newXp = newXp.clamp(0, 999999);
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp, 'totalXp': newTotalXp});
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
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
    final _r3b = _applyXp(userData!.totalXp, mail.reward.xp);
    int newXp = _r3b['xp'] as int;
    int newRevive = userData!.reviveItem + mail.reward.reviveItem;
    int newLevel = _r3b['level'] as int;
    int newXpToNext = _r3b['xpToNext'] as int;
    final newTotalXp = _r3b['totalXp'] as int;
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp, 'reviveItem': newRevive});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp, reviveItem: newRevive);
    if (newLevel > prevLevel) { levelUpTo = newLevel; await _handleLevelUpReward(prevLevel, newLevel); }
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

  // 온보딩 완료 처리 — 닉네임 저장 후 FCM 토큰 발급
  Future<void> completeOnboarding(String nickname) async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'name': nickname, 'onboardingDone': true});
    userData = userData!.copyWith(name: nickname, onboardingDone: true);
    // 신규 회원은 이 시점에 FCM 토큰 저장 (authStateChanges 타이밍 문제 우회)
    await NotificationService.saveFcmToken(authUser!.uid);
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

  // 로그아웃 — Navigator 스택 초기화 후 상태 초기화
  Future<void> signOut() async {
    final uid = authUser?.uid;
    // Navigator 스택을 루트로 초기화 — 설정 화면 등 모든 스택 제거
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    // 상태 초기화 — RootScreen이 LoginScreen으로 전환
    authUser = null; userData = null; goals = []; mailbox = [];
    notifyListeners();
    // FCM 토큰 삭제 및 Firebase 로그아웃 (백그라운드)
    if (uid != null) NotificationService.deleteFcmToken(uid);
    await _auth.signOut();
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
    final _r5 = _applyXp(userData!.totalXp, xpGain);
    int newXp = _r5['xp'] as int;
    int newLevel = _r5['level'] as int;
    int newXpToNext = _r5['xpToNext'] as int;
    final newTotalXp = _r5['totalXp'] as int;
    int newTotalFocus = userData!.totalFocusMin + minutes;
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp, 'totalFocusMin': newTotalFocus});
    // 오늘 집중 시간 랭킹 업데이트
    await _db.updateTodayFocus(authUser!.uid, minutes);
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp, totalFocusMin: newTotalFocus);
    if (newLevel > prevLevel) { levelUpTo = newLevel; await _handleLevelUpReward(prevLevel, newLevel); }
    // 집중 세션 횟수 조회 후 업적 체크
    final sessionSnap = await _db.getFocusSessionCount(authUser!.uid);
    await _checkAchievements();
    // 세션 수 업적 체크
    if (sessionSnap >= 10) { _checkSingleAchievement('focus_session_10', sessionSnap >= 10); }
    if (sessionSnap >= 50) { _checkSingleAchievement('focus_session_50', sessionSnap >= 50); }
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