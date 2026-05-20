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

  final Set<String> _processingGoals = {};

  static final navigatorKey = GlobalKey<NavigatorState>();
  FirestoreService get firestoreService => _db;

  User? authUser;
  UserModel? userData;
  List<GoalModel> goals = [];
  List<MailModel> mailbox = [];
  bool loading = true;
  String? toast;
  ThemeMode themeMode = ThemeMode.system;

  int? levelUpTo;
  bool showAttendModal = false;
  String? streakModalType;

  Color _primaryColor = AppTheme.defaultPrimary;
  Color get userPrimaryColor => _primaryColor;

  Color _bgColor = AppTheme.background;
  Color get userBgColor => _bgColor;

  bool _isCustomTheme = false;
  bool get isCustomTheme => _isCustomTheme;
  int brokenStreakPrev = 0;
  Map<String, dynamic>? currentMilestone;

  final List<String> _toastQueue = [];
  bool _toastRunning = false;

  StreamSubscription? _authSub;
  bool _isInitializing = false;

  static const List<Map<String, Object>> _milestones = [
    {'days': 7,   'xp': 100,  'label': '7일 연속',   'badge': true},
    {'days': 14,  'xp': 200,  'label': '14일 연속',  'badge': false},
    {'days': 30,  'xp': 500,  'label': '한 달 연속', 'badge': true},
    {'days': 60,  'xp': 800,  'label': '60일 연속',  'badge': false},
    {'days': 100, 'xp': 1500, 'label': '100일 연속', 'badge': true},
    {'days': 365, 'xp': 5000, 'label': '1년 연속',   'badge': true},
  ];

  double get xpPercent => userData == null ? 0 : (userData!.xp / userData!.xpToNext * 100).clamp(0, 100);

  int get goalsThisMonth {
    final now = DateTime.now();
    return goals.where((g) =>
      g.done && g.completedAt != null &&
      g.completedAt!.year == now.year && g.completedAt!.month == now.month
    ).length;
  }

  int get unreadMailCount => mailbox.where((m) => !m.read).length;

  bool isFocusing = false;
  VoidCallback? onPauseFocus;

  int _unreadNotifCount = 0;
  int get unreadNotifCount => _unreadNotifCount;

  int _unreadChatCount = 0;
  int get unreadChatCount => _unreadChatCount;
  int get unreadSocialCount => _unreadNotifCount + _unreadChatCount;

  Future<void> reloadUnreadNotifCount() async {
    if (authUser == null) return;
    _unreadNotifCount = await ActivityNotificationService().getUnreadCount(authUser!.uid);
    _unreadChatCount = await ChatService().getTotalUnreadCount(authUser!.uid);
    notifyListeners();
  }

  int get unclaimedAchievementCount {
    if (userData == null) return 0;
    return userData!.achievements
        .where((id) => !userData!.claimedAchievements.contains(id))
        .length;
  }

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

  static Map<String, dynamic>? _getLevelReward(int level) {
    if (level == 100) return {'xp': 10000, 'reviveItem': 5, 'label': '🌟 레벨 100 달성! 불멸자의 증표'};
    if (level == 50)  return {'xp': 3000,  'reviveItem': 3, 'label': '💎 레벨 50 달성! 전설의 시작'};
    if (level % 10 == 0) return {'xp': level * 20, 'reviveItem': 2, 'label': '🎊 레벨 $level 달성!'};
    if (level % 5 == 0)  return {'xp': level * 10, 'reviveItem': 1, 'label': '🎁 레벨 $level 달성!'};
    return null;
  }

  Future<void> _migrateTotalXpIfNeeded(String uid) async {
    if (userData == null) return;
    final expectedXpToNext = xpRequired(userData!.level);
    final needsMigration = (userData!.xpToNext - expectedXpToNext).abs() > 5;
    if (!needsMigration) return;
    final migratedTotal = _calcTotalXpLegacy(userData!.level, userData!.xp);
    final r = calcLevelFromTotal(migratedTotal);
    final prevLevel = userData!.level;
    await _db.updateUser(uid, {
      'totalXp': migratedTotal, 'level': r.level, 'xp': r.xp, 'xpToNext': r.xpToNext,
    });
    userData = userData!.copyWith(totalXp: migratedTotal, level: r.level, xp: r.xp, xpToNext: r.xpToNext);
    if (r.level != prevLevel) {
      await _db.updatePublicProfile(uid, {'level': r.level, 'name': userData!.name, 'character': userData!.character.toMap()});
    }
    debugPrint('마이그레이션 완료: Lv${prevLevel}→Lv${r.level}, totalXp=$migratedTotal');
  }

  static int _calcTotalXpLegacy(int level, int xp) {
    int total = xp;
    int req = 100;
    for (int i = 1; i < level; i++) { total += req; req = (req * 1.15).round(); }
    return total;
  }

  static int xpRequired(int level) {
    int req = 100;
    for (int i = 1; i < level; i++) req = (req * 1.05).round();
    return req;
  }

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

  Map<String, dynamic> _applyXp(int currentTotalXp, int gain) {
    final newTotal = currentTotalXp + gain;
    final r = calcLevelFromTotal(newTotal);
    return {'totalXp': newTotal, 'xp': r.xp, 'level': r.level, 'xpToNext': r.xpToNext};
  }

  Map<String, dynamic> _deductXp(int currentTotalXp, int loss) {
    final newTotal = (currentTotalXp - loss).clamp(0, 999999999);
    final r = calcLevelFromTotal(newTotal);
    return {'totalXp': newTotal, 'xp': r.xp, 'level': r.level, 'xpToNext': r.xpToNext};
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('themeMode') ?? 'system';
    themeMode = savedTheme == 'light' ? ThemeMode.light : savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.system;
    _isCustomTheme = prefs.getBool('isCustomTheme') ?? false;
    final colorVal = prefs.getInt('primaryColor');
    if (colorVal != null) _primaryColor = Color(colorVal);
    final bgVal = prefs.getInt('bgColor');
    if (bgVal != null) _bgColor = Color(bgVal);
    notifyListeners();

    await _authSub?.cancel();
    _authSub = _auth.authStateChanges.listen((user) async {
      _isInitializing = true;
      try {
        authUser = user;
        debugPrint('🔥 authStateChanges: user=${user?.uid}');
        if (user != null) {
          await _db.ensureUserDoc(user);
          for (int i = 0; i < 3; i++) {
            userData = await _db.getUser(user.uid);
            if (userData != null) break;
            await Future.delayed(const Duration(seconds: 1));
          }
          debugPrint('🔥 userData=${userData?.uid}, null=${userData == null}');
          if (userData != null) {
            await Future.wait([loadGoals(), loadMailbox()]);
            await checkAttendance();
            await reloadUnreadNotifCount();
            await _checkAllAchievementsSilently();
            await _migrateTotalXpIfNeeded(user.uid);
            final prefs2 = await SharedPreferences.getInstance();
            if (prefs2.getBool('notif_goal') ?? true) await NotificationService.scheduleDailyGoalReminder();
            if (prefs2.getBool('notif_streak') ?? true) await NotificationService.scheduleStreakRiskReminder(userData?.streak ?? 0);
            debugPrint('🔥 saveFcmToken 호출: ${user.uid}');
            await NotificationService.saveFcmToken(user.uid);
          }
        } else {
          userData = null; goals = []; mailbox = [];
          levelUpTo = null; showAttendModal = false; streakModalType = null;
        }
      } catch (e) {
        debugPrint('init 에러: $e');
      } finally {
        loading = false;
        _isInitializing = false;
        notifyListeners();
      }
    });
  }

  Future<void> _checkAllAchievementsSilently() async {
    if (authUser == null || userData == null) return;
    final achieved = Set<String>.from(userData!.achievements);
    final unlockedAt = Map<String, DateTime>.from(userData!.achievementUnlockedAt);
    final newOnes = <String>[];
    final now = DateTime.now();

    void check(String id, bool condition) {
      if (condition && !achieved.contains(id)) { achieved.add(id); unlockedAt[id] = now; newOnes.add(id); }
    }

    final doneCount = goals.where((g) => g.done).length;
    final shortDone = goals.where((g) => g.done && g.type == 'short').length;
    final longDone  = goals.where((g) => g.done && g.type == 'long').length;
    final repeatSets = goals.where((g) => g.done && g.repeatId != null).length;

    check('goal_first',    doneCount >= 1);
    check('goal_10',       doneCount >= 10);
    check('goal_50',       doneCount >= 50);
    check('goal_100',      doneCount >= 100);
    check('goal_300',      doneCount >= 300);
    check('repeat_first',  repeatSets >= 1);
    check('repeat_10',     repeatSets >= 10);
    check('short_goal_50', shortDone >= 50);
    check('long_goal_10',  longDone >= 10);
    check('streak_3',      userData!.streak >= 3);
    check('streak_7',      userData!.streak >= 7);
    check('streak_14',     userData!.streak >= 14);
    check('streak_30',     userData!.streak >= 30);
    check('streak_60',     userData!.streak >= 60);
    check('streak_100',    userData!.streak >= 100);
    check('streak_365',    userData!.streak >= 365);
    check('focus_1h',      userData!.totalFocusMin >= 60);
    check('focus_5h',      userData!.totalFocusMin >= 300);
    check('focus_10h',     userData!.totalFocusMin >= 600);
    check('focus_30h',     userData!.totalFocusMin >= 1800);
    check('focus_50h',     userData!.totalFocusMin >= 3000);
    check('focus_100h',    userData!.totalFocusMin >= 6000);
    check('focus_200h',    userData!.totalFocusMin >= 12000);
    check('level_5',       userData!.level >= 5);
    check('level_10',      userData!.level >= 10);
    check('level_20',      userData!.level >= 20);
    check('level_30',      userData!.level >= 30);
    check('level_50',      userData!.level >= 50);
    check('level_75',      userData!.level >= 75);
    check('level_100',     userData!.level >= 100);

    if (!achieved.contains('friend_first') || !achieved.contains('friend_5') || !achieved.contains('friend_10')) {
      final friends = await _friendService.getFriends(authUser!.uid);
      check('friend_first', friends.isNotEmpty);
      check('friend_5',     friends.length >= 5);
      check('friend_10',    friends.length >= 10);
    }
    if (!achieved.contains('diary_first') || !achieved.contains('diary_10') || !achieved.contains('diary_50')) {
      final diaries = await _diaryService.getMyDiaries(authUser!.uid);
      check('diary_first', diaries.isNotEmpty);
      check('diary_10',    diaries.length >= 10);
      check('diary_50',    diaries.length >= 50);
    }

    if (newOnes.isEmpty) return;
    final unlockedAtFirestore = unlockedAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v)));
    await _db.updateUser(authUser!.uid, {'achievements': achieved.toList(), 'achievementUnlockedAt': unlockedAtFirestore});
    userData = userData!.copyWith(achievements: achieved, achievementUnlockedAt: unlockedAt);
    notifyListeners();
  }

  Future<void> _checkAchievements({
    bool goalCompleted = false, bool repeatAllDone = false,
    bool friendAdded = false, bool diaryWritten = false,
    int? diaryCount, int? friendCount,
    bool chatStarted = false, int? rankingPosition,
  }) async {
    if (authUser == null || userData == null) return;
    final achieved = Set<String>.from(userData!.achievements);
    final unlockedAt = Map<String, DateTime>.from(userData!.achievementUnlockedAt);
    final newOnes = <String>[];
    final now = DateTime.now();

    void check(String id, bool condition) {
      if (condition && !achieved.contains(id)) { achieved.add(id); unlockedAt[id] = now; newOnes.add(id); }
    }

    final doneCount = goals.where((g) => g.done).length;
    final shortDone = goals.where((g) => g.done && g.type == 'short').length;
    final longDone  = goals.where((g) => g.done && g.type == 'long').length;
    final repeatSets = goals.where((g) => g.done && g.repeatId != null).length;

    check('goal_first',    goalCompleted && doneCount >= 1);
    check('goal_10',       doneCount >= 10);
    check('goal_50',       doneCount >= 50);
    check('goal_100',      doneCount >= 100);
    check('goal_300',      doneCount >= 300);
    check('repeat_first',  repeatAllDone);
    check('repeat_10',     repeatSets >= 10);
    check('short_goal_50', shortDone >= 50);
    check('long_goal_10',  longDone >= 10);
    check('streak_3',      userData!.streak >= 3);
    check('streak_7',      userData!.streak >= 7);
    check('streak_14',     userData!.streak >= 14);
    check('streak_30',     userData!.streak >= 30);
    check('streak_60',     userData!.streak >= 60);
    check('streak_100',    userData!.streak >= 100);
    check('streak_365',    userData!.streak >= 365);
    check('focus_1h',      userData!.totalFocusMin >= 60);
    check('focus_5h',      userData!.totalFocusMin >= 300);
    check('focus_10h',     userData!.totalFocusMin >= 600);
    check('focus_30h',     userData!.totalFocusMin >= 1800);
    check('focus_50h',     userData!.totalFocusMin >= 3000);
    check('focus_100h',    userData!.totalFocusMin >= 6000);
    check('focus_200h',    userData!.totalFocusMin >= 12000);
    check('level_5',       userData!.level >= 5);
    check('level_10',      userData!.level >= 10);
    check('level_20',      userData!.level >= 20);
    check('level_30',      userData!.level >= 30);
    check('level_50',      userData!.level >= 50);
    check('level_75',      userData!.level >= 75);
    check('level_100',     userData!.level >= 100);
    check('friend_first',  friendAdded);
    check('friend_5',      (friendCount ?? 0) >= 5);
    check('friend_10',     (friendCount ?? 0) >= 10);
    check('diary_first',   diaryWritten);
    check('diary_10',      (diaryCount ?? 0) >= 10);
    check('diary_50',      (diaryCount ?? 0) >= 50);
    check('chat_first',    chatStarted);
    check('ranking_top3',  rankingPosition != null && rankingPosition! <= 3);
    check('ranking_top1',  rankingPosition != null && rankingPosition! == 1);

    if (newOnes.isEmpty) return;
    final unlockedAtFirestore = unlockedAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v)));
    await _db.updateUser(authUser!.uid, {'achievements': achieved.toList(), 'achievementUnlockedAt': unlockedAtFirestore});
    userData = userData!.copyWith(achievements: achieved, achievementUnlockedAt: unlockedAt);
    for (final id in newOnes) {
      final a = Achievements.findById(id);
      if (a != null) showToast('🏆 업적 달성! ${a.emoji} ${a.title}');
    }
    notifyListeners();
  }

  Future<void> claimAchievementReward(String achievementId) async {
    if (authUser == null || userData == null) return;
    if (userData!.claimedAchievements.contains(achievementId)) return;
    final a = Achievements.findById(achievementId);
    if (a == null) return;

    final claimed = Set<String>.from(userData!.claimedAchievements)..add(achievementId);
    final prevLevel = userData!.level;
    final r1 = _applyXp(userData!.totalXp, a.xpReward);
    int newXp = r1['xp'] as int;
    int newLevel = r1['level'] as int;
    int newXpToNext = r1['xpToNext'] as int;
    final newTotalXp = r1['totalXp'] as int;

    final unlockedSkins = List<String>.from(userData!.streakBadges['unlockedAchieveSkins'] as List? ?? []);
    if (!unlockedSkins.contains(a.id)) unlockedSkins.add(a.id);
    final newStreakBadges = {...userData!.streakBadges, 'unlockedAchieveSkins': unlockedSkins};

    await _db.updateUser(authUser!.uid, {
      'claimedAchievements': claimed.toList(),
      'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp,
      'streakBadges': newStreakBadges,
    });
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
    await _db.updatePublicProfile(authUser!.uid, {
      'name': userData!.name, 'level': newLevel,
      'character': userData!.character.toMap(), 'equippedAchievement': userData!.equippedAchievement,
    });
    await _diaryService.updateAuthorInfo(authUser!.uid, userData!.name, userData!.character.toMap(), newLevel, equippedAchievement: userData!.equippedAchievement);
    if (newLevel > prevLevel) { levelUpTo = newLevel; await _handleLevelUpReward(prevLevel, newLevel); }
    showToast('🎁 보상 수령! +${a.xpReward} XP · ${a.emoji} 스킨 해금');
    notifyListeners();
  }

  Future<void> addReviveItem(int count) async {
    if (authUser == null || userData == null) return;
    final newCount = userData!.reviveItem + count;
    await _db.updateUser(authUser!.uid, {'reviveItem': newCount});
    userData = userData!.copyWith(reviveItem: newCount);
    notifyListeners();
  }

  Future<void> equipAchievement(String? achievementId) async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'equippedAchievement': achievementId});
    await _db.updatePublicProfile(authUser!.uid, {'equippedAchievement': achievementId, 'name': userData!.name, 'level': userData!.level, 'character': userData!.character.toMap()});
    await _diaryService.updateAuthorInfo(authUser!.uid, userData!.name, userData!.character.toMap(), userData!.level, equippedAchievement: achievementId);
    userData = userData!.copyWith(equippedAchievement: achievementId);
    notifyListeners();
  }

  List<String> get unlockedAchieveSkins {
    if (userData == null) return [];
    return List<String>.from(userData!.streakBadges['unlockedAchieveSkins'] as List? ?? []);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
    notifyListeners();
  }

  Future<void> setCustomTheme(bool enabled) async {
    _isCustomTheme = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCustomTheme', enabled);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', color.value);
    notifyListeners();
  }

  Future<void> setBgColor(Color color) async {
    _bgColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bgColor', color.value);
    notifyListeners();
  }

  Future<void> resetCustomColors() async {
    _primaryColor = AppTheme.defaultPrimary;
    _bgColor = AppTheme.background;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('primaryColor');
    await prefs.remove('bgColor');
    notifyListeners();
  }

  Future<void> forceReloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      userData = await _db.getUser(user.uid);
      notifyListeners();
    } catch (e) { debugPrint('forceReloadUser 에러: $e'); }
  }

  Future<void> reloadUser() async {
    if (_isInitializing) {
      while (_isInitializing) { await Future.delayed(const Duration(milliseconds: 100)); }
      return;
    }
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
    } catch (e) { debugPrint('reloadUser 에러: $e'); }
    finally { loading = false; notifyListeners(); }
  }

  Future<void> loadGoals() async {
    if (authUser == null) return;
    goals = await _db.getGoals(authUser!.uid);
    notifyListeners();
  }

  Future<void> loadMailbox() async {
    if (authUser == null) return;
    mailbox = await _db.getMailbox(authUser!.uid);
    notifyListeners();
  }

  Future<void> checkAttendance() async {
    if (userData == null || authUser == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (userData!.lastAttendDate == today) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_streak') ?? true) await NotificationService.cancelNotification(2);
      return;
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    if (userData!.lastAttendDate.isNotEmpty && userData!.lastAttendDate != yesterday && userData!.streak > 0) {
      brokenStreakPrev = userData!.streak;
      await _db.updateUser(authUser!.uid, {
        'lastAttendDate': today, 'lastLogin': FieldValue.serverTimestamp(), 'streak': 1,
      });
      userData = userData!.copyWith(lastAttendDate: today, streak: 1);
      streakModalType = 'broken';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_streak') ?? true) await NotificationService.cancelNotification(2);
      notifyListeners();
      return;
    }
    int newStreak = userData!.lastAttendDate == yesterday ? userData!.streak + 1 : 1;
    int newMaxStreak = newStreak > userData!.maxStreak ? newStreak : userData!.maxStreak;
    await _db.updateUser(authUser!.uid, {
      'lastAttendDate': today, 'lastLogin': FieldValue.serverTimestamp(),
      'streak': newStreak, 'maxStreak': newMaxStreak,
    });
    await _db.sendAttendanceMail(authUser!.uid, newStreak);
    userData = userData!.copyWith(lastAttendDate: today, streak: newStreak, maxStreak: newMaxStreak);
    await loadMailbox();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_streak') ?? true) {
      await NotificationService.cancelNotification(2);
      await NotificationService.scheduleStreakRiskReminder(newStreak);
    }
    final milestone = _milestones.firstWhere((m) => m['days'] == newStreak, orElse: () => <String, Object>{});
    if (milestone.isNotEmpty) { currentMilestone = milestone.map((k, v) => MapEntry(k, v)); streakModalType = 'milestone'; }
    // 출석 처리 완료 — 출석 모달 표시
    showAttendModal = true;
    await _checkAchievements();
    notifyListeners();
  }

  void dismissAttendModal() { showAttendModal = false; notifyListeners(); }
  void dismissStreakModal() { streakModalType = null; currentMilestone = null; notifyListeners(); }

  Future<void> claimMilestoneXp() async {
    if (authUser == null || userData == null || currentMilestone == null) return;
    final xpGain = currentMilestone!['xp'] as int;
    final prevLevel = userData!.level;
    final r2 = _applyXp(userData!.totalXp, xpGain);
    int newXp = r2['xp'] as int; int newLevel = r2['level'] as int;
    int newXpToNext = r2['xpToNext'] as int; final newTotalXp = r2['totalXp'] as int;
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
    if (newLevel > prevLevel) { levelUpTo = newLevel; await _handleLevelUpReward(prevLevel, newLevel); }
    streakModalType = null; currentMilestone = null;
    notifyListeners();
  }

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
    showAttendModal = true;
    notifyListeners();
  }

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
    showAttendModal = true;
    notifyListeners();
  }

  Future<void> resetStreak() async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'streak': 1});
    userData = userData!.copyWith(streak: 1);
    streakModalType = null; notifyListeners();
  }

  Future<void> completeGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    if (_processingGoals.contains(goalId)) return;
    _processingGoals.add(goalId);
    try {
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
            xpGain += goal.xp; repeatAllDone = true;
            showToast('🏆 반복 목표 전체 완료! +${goal.repeatXp + goal.xp} XP 획득');
          } else {
            final pct = (doneCount / totalCount * 100).round();
            showToast('🎉 목표 완료! +$xpGain XP 획득');
            showToast('달성률 $pct%로 반복 목표 종료');
          }
          final rg1 = _applyXp(userData!.totalXp, xpGain);
          int newXp = rg1['xp'] as int; int newLevel = rg1['level'] as int;
          int newXpToNext = rg1['xpToNext'] as int; final newTotalXp = rg1['totalXp'] as int;
          await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp});
          userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
          if (newLevel > prevLevel) { levelUpTo = newLevel; await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()}); await _handleLevelUpReward(prevLevel, newLevel); }
          await loadGoals();
          await _checkAchievements(goalCompleted: true, repeatAllDone: repeatAllDone);
          notifyListeners(); return;
        }
      }

      showToast('🎉 목표 완료! +$xpGain XP 획득');
      final newXpResult = _applyXp(userData!.totalXp, xpGain);
      int newXp = newXpResult['xp'] as int; int newLevel = newXpResult['level'] as int;
      int newXpToNext = newXpResult['xpToNext'] as int; final newTotalXp = newXpResult['totalXp'] as int;
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp});
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
      if (newLevel > prevLevel) { levelUpTo = newLevel; await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()}); await _handleLevelUpReward(prevLevel, newLevel); }
      await loadGoals();
      await _checkAchievements(goalCompleted: true);
      notifyListeners();
    } finally { _processingGoals.remove(goalId); }
  }

  Future<void> _checkSingleAchievement(String id, bool condition) async {
    if (authUser == null || userData == null) return;
    if (!condition || userData!.achievements.contains(id)) return;
    final achieved = Set<String>.from(userData!.achievements)..add(id);
    final unlockedAt = Map<String, DateTime>.from(userData!.achievementUnlockedAt)..[id] = DateTime.now();
    final unlockedAtFs = unlockedAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v)));
    await _db.updateUser(authUser!.uid, {'achievements': achieved.toList(), 'achievementUnlockedAt': unlockedAtFs});
    userData = userData!.copyWith(achievements: achieved, achievementUnlockedAt: unlockedAt);
    final a = Achievements.findById(id);
    if (a != null) showToast('🏆 업적 달성! ${a.emoji} ${a.title}');
    notifyListeners();
  }

  void dismissLevelUp() { levelUpTo = null; notifyListeners(); }

  Future<void> _handleLevelUpReward(int prevLevel, int newLevel) async {
    if (authUser == null) return;
    for (int lv = prevLevel + 1; lv <= newLevel; lv++) {
      final reward = _getLevelReward(lv);
      if (reward != null) await _db.sendLevelUpMail(authUser!.uid, lv, reward);
    }
  }

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
      if (isRepeat) {
        final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
        if (repeatGoals.where((g) => g.done).length >= repeatGoals.length) xpDeduct += goal.xp;
      }
      final r4b = _deductXp(userData!.totalXp, xpDeduct);
      int newXp = r4b['xp'] as int; int newLevel = r4b['level'] as int;
      int newXpToNext = r4b['xpToNext'] as int; final newTotalXp = r4b['totalXp'] as int;
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp});
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp);
      showToast('목표 완료를 취소했어요');
      await loadGoals(); notifyListeners();
    } finally { _processingGoals.remove(goalId); }
  }

  Future<void> removeGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    final goal = goals.firstWhere((g) => g.id == goalId, orElse: () => throw Exception('goal not found'));
    if (goal.done) {
      final freshUser = await _db.getUser(authUser!.uid);
      if (freshUser != null) userData = freshUser;
      final isRepeat = goal.repeatId != null;
      int xpDeduct = isRepeat ? goal.repeatXp : goal.xp;
      if (isRepeat) {
        final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
        if (repeatGoals.where((g) => g.done).length >= repeatGoals.length) xpDeduct += goal.xp;
      }
      final deducted = _deductXp(userData!.totalXp, xpDeduct);
      await _db.updateUser(authUser!.uid, {
        'xp': deducted['xp'], 'level': deducted['level'],
        'xpToNext': deducted['xpToNext'], 'totalXp': deducted['totalXp'],
      });
      userData = userData!.copyWith(
        xp: deducted['xp'] as int, level: deducted['level'] as int,
        xpToNext: deducted['xpToNext'] as int, totalXp: deducted['totalXp'] as int,
      );
    }
    await _db.deleteGoal(authUser!.uid, goalId);
    showToast('목표를 삭제했어요');
    await loadGoals(); notifyListeners();
  }

  // 4번: 반복 목표 전체 삭제 — 완료/미완료 모두 삭제 + 완료된 목표 XP 차감
  Future<void> removeRepeatGoals(String repeatId) async {
    if (authUser == null || userData == null) return;
    // 최신 유저 데이터로 XP 계산
    final freshUser = await _db.getUser(authUser!.uid);
    if (freshUser != null) userData = freshUser;
    // 완료/미완료 전체 삭제 후 삭제된 목록 반환 — XP 차감 계산용
    final deleted = await _db.deleteRepeatGoalsAndReturn(authUser!.uid, repeatId);
    // 완료된 목표들의 XP 합산 후 차감
    final doneGoals = deleted.where((g) => g.done).toList();
    if (doneGoals.isNotEmpty) {
      final anyAllDone = deleted.every((g) => g.done);
      int totalDeduct = 0;
      for (final g in doneGoals) totalDeduct += g.repeatXp;
      // 전체 완료 보너스 XP도 차감
      if (anyAllDone) totalDeduct += doneGoals.first.xp;
      final deducted = _deductXp(userData!.totalXp, totalDeduct);
      await _db.updateUser(authUser!.uid, {
        'xp': deducted['xp'], 'level': deducted['level'],
        'xpToNext': deducted['xpToNext'], 'totalXp': deducted['totalXp'],
      });
      userData = userData!.copyWith(
        xp: deducted['xp'] as int, level: deducted['level'] as int,
        xpToNext: deducted['xpToNext'] as int, totalXp: deducted['totalXp'] as int,
      );
    }
    showToast('반복 목표를 삭제했어요');
    await loadGoals();
    notifyListeners();
  }

  Map<String, dynamic>? getRepeatInfo(String goalId) {
    final goal = goals.firstWhere((g) => g.id == goalId);
    if (goal.repeatId == null) return null;
    final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
    return {'repeatId': goal.repeatId, 'total': repeatGoals.length, 'undone': repeatGoals.where((g) => !g.done).length};
  }

  Future<void> claimMailReward(String mailId) async {
    if (authUser == null || userData == null) return;
    final mail = mailbox.firstWhere((m) => m.id == mailId);
    if (mail.claimed) return;
    await _db.claimMail(authUser!.uid, mailId);
    final prevLevel = userData!.level;
    final r3b = _applyXp(userData!.totalXp, mail.reward.xp);
    int newXp = r3b['xp'] as int; int newRevive = userData!.reviveItem + mail.reward.reviveItem;
    int newLevel = r3b['level'] as int; int newXpToNext = r3b['xpToNext'] as int;
    final newTotalXp = r3b['totalXp'] as int;
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp, 'reviveItem': newRevive});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp, reviveItem: newRevive);
    if (newLevel > prevLevel) { levelUpTo = newLevel; await _handleLevelUpReward(prevLevel, newLevel); }
    showToast('보상을 수령했어요!');
    await loadMailbox(); notifyListeners();
  }

  Future<void> deleteMailItem(String mailId) async {
    if (authUser == null) return;
    await _db.deleteMail(authUser!.uid, mailId);
    await loadMailbox(); notifyListeners();
  }

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

  Future<void> updateName(String name) async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'name': name});
    await _db.updatePublicProfile(authUser!.uid, {'name': name});
    await _diaryService.updateAuthorInfo(authUser!.uid, name, userData!.character.toMap(), userData!.level, equippedAchievement: userData!.equippedAchievement);
    userData = userData!.copyWith(name: name);
    notifyListeners();
  }

  Future<void> completeOnboarding(String nickname) async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'name': nickname, 'onboardingDone': true});
    userData = userData!.copyWith(name: nickname, onboardingDone: true);
    await NotificationService.saveFcmToken(authUser!.uid);
    notifyListeners();
  }

  Future<void> onFriendAdded() async => _checkAchievements(friendAdded: true);
  Future<void> onDiaryWritten(int diaryCount) async => _checkAchievements(diaryWritten: true, diaryCount: diaryCount);

  Future<void> signOut() async {
    final uid = authUser?.uid;
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    authUser = null; userData = null; goals = []; mailbox = [];
    notifyListeners();
    if (uid != null) NotificationService.deleteFcmToken(uid);
    await _auth.signOut();
  }

  void showToast(String message) {
    _toastQueue.add(message);
    if (!_toastRunning) _processToastQueue();
  }

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

  Future<void> saveFocusSession(int minutes) async {
    if (authUser == null || userData == null) return;
    await _db.saveFocusSession(authUser!.uid, minutes);
    final prevLevel = userData!.level;
    final xpGain = minutes + (minutes ~/ 10) * minutes;
    final r5 = _applyXp(userData!.totalXp, xpGain);
    int newXp = r5['xp'] as int; int newLevel = r5['level'] as int;
    int newXpToNext = r5['xpToNext'] as int; final newTotalXp = r5['totalXp'] as int;
    int newTotalFocus = userData!.totalFocusMin + minutes;
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalXp': newTotalXp, 'totalFocusMin': newTotalFocus});
    await _db.updateTodayFocus(authUser!.uid, minutes);
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalXp: newTotalXp, totalFocusMin: newTotalFocus);
    if (newLevel > prevLevel) { levelUpTo = newLevel; await _handleLevelUpReward(prevLevel, newLevel); }
    final sessionSnap = await _db.getFocusSessionCount(authUser!.uid);
    await _checkAchievements();
    if (sessionSnap >= 10) _checkSingleAchievement('focus_session_10', sessionSnap >= 10);
    if (sessionSnap >= 50) _checkSingleAchievement('focus_session_50', sessionSnap >= 50);
    notifyListeners();
  }

  Future<void> scheduleWithdraw() async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'withdrawScheduledAt': DateTime.now().add(const Duration(days: 30))});
    await signOut();
  }

  Future<void> cancelWithdraw() async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'withdrawScheduledAt': null});
    userData = userData!.copyWith(withdrawScheduledAt: null);
    notifyListeners();
  }
}