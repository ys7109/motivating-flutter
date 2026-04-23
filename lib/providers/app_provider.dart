import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../models/mail_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final FirestoreService _db = FirestoreService();
  final Set<String> _processingGoals = {}; // 중복 처리 방지

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
  int brokenStreakPrev = 0;
  Map<String, dynamic>? currentMilestone;

  StreamSubscription? _authSub;

  static const List<Map<String, Object>> _milestones = [
    {'days': 7,   'xp': 100,  'label': '7일 연속',   'badge': true},
    {'days': 14,  'xp': 200,  'label': '14일 연속',  'badge': false},
    {'days': 30,  'xp': 500,  'label': '한 달 연속', 'badge': true},
    {'days': 60,  'xp': 800,  'label': '60일 연속',  'badge': false},
    {'days': 100, 'xp': 1500, 'label': '100일 연속', 'badge': true},
    {'days': 365, 'xp': 5000, 'label': '1년 연속',   'badge': true},
  ];

  double get xpPercent => userData == null ? 0
      : (userData!.xp / userData!.xpToNext * 100).clamp(0, 100);

  int get goalsThisMonth {
    final now = DateTime.now();
    return goals.where((g) =>
      g.done && g.completedAt != null &&
      g.completedAt!.year == now.year &&
      g.completedAt!.month == now.month
    ).length;
  }

  int get unreadMailCount => mailbox.where((m) => !m.read).length;

  String levelTitle(int level) {
    if (level >= 20) return '전설의 모험가';
    if (level >= 15) return '영웅';
    if (level >= 10) return '탐험가';
    if (level >= 6)  return '학자';
    if (level >= 3)  return '전사';
    return '초보 모험가';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('themeMode') ?? 'system';
    themeMode = savedTheme == 'light' ? ThemeMode.light
        : savedTheme == 'dark' ? ThemeMode.dark
        : ThemeMode.system;
    notifyListeners();

    await _authSub?.cancel();
    _authSub = _auth.authStateChanges.listen((user) async {
      authUser = user;
      if (user != null) {
        userData = await _db.getUser(user.uid);
        if (userData != null) {
          await Future.wait([loadGoals(), loadMailbox()]);
          await checkAttendance();
        }
      } else {
        userData = null;
        goals = [];
        mailbox = [];
        levelUpTo = null;
        showAttendModal = false;
        streakModalType = null;
      }
      loading = false;
      notifyListeners();
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    final key = mode == ThemeMode.light ? 'light'
        : mode == ThemeMode.dark ? 'dark'
        : 'system';
    await prefs.setString('themeMode', key);
    notifyListeners();
  }

  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    authUser = user;
    userData = await _db.getUser(user.uid);
    if (userData != null) {
      await Future.wait([loadGoals(), loadMailbox()]);
      await checkAttendance();
    }
    loading = false;
    notifyListeners();
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
    if (userData!.lastAttendDate == today) return;

    final yesterday = DateTime.now().subtract(const Duration(days: 1))
        .toIso8601String().substring(0, 10);

    if (userData!.lastAttendDate.isNotEmpty &&
        userData!.lastAttendDate != yesterday &&
        userData!.streak > 0) {
      brokenStreakPrev = userData!.streak;
      await _db.updateUser(authUser!.uid, {
        'lastAttendDate': today, 'streak': 1,
      });
      userData = userData!.copyWith(lastAttendDate: today, streak: 1);
      streakModalType = 'broken';
      notifyListeners();
      return;
    }

    int newStreak = userData!.lastAttendDate == yesterday
        ? userData!.streak + 1 : 1;
    int newMaxStreak = newStreak > userData!.maxStreak
        ? newStreak : userData!.maxStreak;

    await _db.updateUser(authUser!.uid, {
      'lastAttendDate': today,
      'streak': newStreak,
      'maxStreak': newMaxStreak,
    });
    await _db.sendAttendanceMail(authUser!.uid, newStreak);

    userData = userData!.copyWith(
      lastAttendDate: today,
      streak: newStreak,
      maxStreak: newMaxStreak,
    );
    await loadMailbox();

    final milestone = _milestones.firstWhere(
      (m) => m['days'] == newStreak,
      orElse: () => <String, Object>{},
    );
    if (milestone.isNotEmpty) {
      currentMilestone = milestone.map((k, v) => MapEntry(k, v));
      streakModalType = 'milestone';
    } else {
      showAttendModal = true;
    }
    notifyListeners();
  }

  void dismissAttendModal() { showAttendModal = false; notifyListeners(); }
  void dismissStreakModal() { streakModalType = null; currentMilestone = null; notifyListeners(); }

  Future<void> claimMilestoneXp() async {
    if (authUser == null || userData == null || currentMilestone == null) return;
    final xpGain = currentMilestone!['xp'] as int;
    final prevLevel = userData!.level;
    int newXp = userData!.xp + xpGain;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;
    while (newXp >= newXpToNext) {
      newXp -= newXpToNext; newLevel++;
      newXpToNext = (newXpToNext * 1.3).round();
    }
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
    if (newLevel > prevLevel) levelUpTo = newLevel;
    streakModalType = null; currentMilestone = null;
    notifyListeners();
  }

  Future<void> reviveStreakByItem() async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'streak': brokenStreakPrev, 'reviveItem': userData!.reviveItem - 1});
    userData = userData!.copyWith(streak: brokenStreakPrev, reviveItem: userData!.reviveItem - 1);
    streakModalType = null;
    notifyListeners();
  }

  Future<void> reviveStreakByAd() async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'streak': brokenStreakPrev});
    userData = userData!.copyWith(streak: brokenStreakPrev);
    streakModalType = null;
    notifyListeners();
  }

  Future<void> resetStreak() async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'streak': 1});
    userData = userData!.copyWith(streak: 1);
    streakModalType = null;
    notifyListeners();
  }

  Future<void> completeGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    if (_processingGoals.contains(goalId)) return; // 중복 방지
    _processingGoals.add(goalId);

    try {
      // Firestore 최신값 기준으로 처리
      final freshUser = await _db.getUser(authUser!.uid);
      if (freshUser == null) return;
      userData = freshUser;

      final goal = goals.firstWhere((g) => g.id == goalId);
      if (goal.done) return;

      await _db.updateGoal(authUser!.uid, goalId, {
        'done': true, 'progress': 100,
        'completedAt': FieldValue.serverTimestamp(),
      });

      final prevLevel = userData!.level;
      int newXp = userData!.xp + goal.xp;
      int newLevel = userData!.level;
      int newXpToNext = userData!.xpToNext;

      while (newXp >= newXpToNext) {
        newXp -= newXpToNext; newLevel++;
        newXpToNext = (newXpToNext * 1.3).round();
      }

      await _db.updateUser(authUser!.uid, {
        'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext,
      });
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
      if (newLevel > prevLevel) levelUpTo = newLevel;
      showToast('🎉 목표 완료! +${goal.xp} XP 획득');
      await loadGoals();
      notifyListeners();
    } finally {
      _processingGoals.remove(goalId);
    }
  }

  void dismissLevelUp() { levelUpTo = null; notifyListeners(); }

  Future<void> uncompleteGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    if (_processingGoals.contains(goalId)) return; // 중복 방지
    _processingGoals.add(goalId);

    try {
      // Firestore 최신값 기준으로 처리 (누적 오차 방지 핵심)
      final freshUser = await _db.getUser(authUser!.uid);
      if (freshUser == null) return;
      userData = freshUser;

      final goal = goals.firstWhere((g) => g.id == goalId);
      if (!goal.done) return;

      await _db.updateGoal(authUser!.uid, goalId, {
        'done': false, 'progress': 0, 'completedAt': null,
      });

      int newXp = userData!.xp - goal.xp;
      int newLevel = userData!.level;
      int newXpToNext = userData!.xpToNext;

      while (newXp < 0 && newLevel > 1) {
        newLevel--;
        newXpToNext = (newXpToNext / 1.3).round();
        newXp += newXpToNext;
      }
      newXp = newXp.clamp(0, 999999);

      await _db.updateUser(authUser!.uid, {
        'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext,
      });
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
      showToast('목표 완료를 취소했어요');
      await loadGoals();
      notifyListeners();
    } finally {
      _processingGoals.remove(goalId);
    }
  }

  Future<void> removeGoal(String goalId) async {
    if (authUser == null) return;
    await _db.deleteGoal(authUser!.uid, goalId);
    showToast('목표를 삭제했어요');
    await loadGoals();
    notifyListeners();
  }

  Future<void> removeRepeatGoals(String repeatId) async {
    if (authUser == null) return;
    await _db.deleteRepeatGoals(authUser!.uid, repeatId);
    showToast('반복 목표를 삭제했어요');
    await loadGoals();
    notifyListeners();
  }

  Map<String, dynamic>? getRepeatInfo(String goalId) {
    final goal = goals.firstWhere((g) => g.id == goalId);
    if (goal.repeatId == null) return null;
    final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
    final undone = repeatGoals.where((g) => !g.done).length;
    return {'repeatId': goal.repeatId, 'total': repeatGoals.length, 'undone': undone};
  }

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

    while (newXp >= newXpToNext) {
      newXp -= newXpToNext; newLevel++;
      newXpToNext = (newXpToNext * 1.3).round();
    }

    await _db.updateUser(authUser!.uid, {
      'xp': newXp, 'level': newLevel,
      'xpToNext': newXpToNext, 'reviveItem': newRevive,
    });
    userData = userData!.copyWith(
      xp: newXp, level: newLevel, xpToNext: newXpToNext, reviveItem: newRevive,
    );
    if (newLevel > prevLevel) levelUpTo = newLevel;
    showToast('보상을 수령했어요!');
    await loadMailbox();
    notifyListeners();
  }

  Future<void> deleteMailItem(String mailId) async {
    if (authUser == null) return;
    await _db.deleteMail(authUser!.uid, mailId);
    await loadMailbox();
    notifyListeners();
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
    userData = userData!.copyWith(character: newChar);
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'name': name});
    userData = userData!.copyWith(name: name);
    notifyListeners();
  }

  Future<void> completeOnboarding(String nickname) async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'name': nickname, 'onboardingDone': true});
    userData = userData!.copyWith(name: nickname, onboardingDone: true);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    authUser = null;
    userData = null;
    goals = [];
    mailbox = [];
    notifyListeners();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }

  void showToast(String message) {
    toast = message;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      toast = null;
      notifyListeners();
    });
  }

  Future<void> saveFocusSession(int minutes) async {
    if (authUser == null || userData == null) return;
    await _db.saveFocusSession(authUser!.uid, minutes);

    final prevLevel = userData!.level;
    final xpGain = minutes + (minutes ~/ 10) * minutes;
    int newXp = userData!.xp + xpGain;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;
    int newTotalFocus = userData!.totalFocusMin + minutes;

    while (newXp >= newXpToNext) {
      newXp -= newXpToNext; newLevel++;
      newXpToNext = (newXpToNext * 1.3).round();
    }

    await _db.updateUser(authUser!.uid, {
      'xp': newXp, 'level': newLevel,
      'xpToNext': newXpToNext, 'totalFocusMin': newTotalFocus,
    });
    await _db.updateTodayFocus(authUser!.uid, minutes);
    userData = userData!.copyWith(
      xp: newXp, level: newLevel, xpToNext: newXpToNext, totalFocusMin: newTotalFocus,
    );
    if (newLevel > prevLevel) levelUpTo = newLevel;
    notifyListeners();
  }

  Future<void> scheduleWithdraw() async {
    if (authUser == null) return;
    final scheduleDate = DateTime.now().add(const Duration(days: 30));
    await _db.updateUser(authUser!.uid, {'withdrawScheduledAt': scheduleDate});
    await signOut();
  }

  Future<void> cancelWithdraw() async {
    if (authUser == null) return;
    await _db.updateUser(authUser!.uid, {'withdrawScheduledAt': null});
    userData = userData!.copyWith(withdrawScheduledAt: null);
    notifyListeners();
  }
}
