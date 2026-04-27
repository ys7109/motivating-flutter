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
import '../services/notification_service.dart';
import '../services/diary_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final FirestoreService _db = FirestoreService();
  final DiaryService _diaryService = DiaryService();
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
  int brokenStreakPrev = 0;
  Map<String, dynamic>? currentMilestone;

  // 토스트 큐
  final List<String> _toastQueue = [];
  bool _toastRunning = false;

  StreamSubscription? _authSub;

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
      try {
        authUser = user;
        if (user != null) {
          userData = await _db.getUser(user.uid);
          if (userData != null) {
            await Future.wait([loadGoals(), loadMailbox()]);
            await checkAttendance();
          }
        } else {
          userData = null; goals = []; mailbox = [];
          levelUpTo = null; showAttendModal = false; streakModalType = null;
        }
      } catch (e) {
        debugPrint('init 에러: $e');
      } finally {
        loading = false;
        notifyListeners();
      }
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
    notifyListeners();
  }

  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      authUser = user;
      userData = await _db.getUser(user.uid);
      if (userData != null) {
        await Future.wait([loadGoals(), loadMailbox()]);
        await checkAttendance();
      }
    } catch (e) {
      debugPrint('reloadUser 에러: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
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
      await _db.updateUser(authUser!.uid, {'lastAttendDate': today, 'streak': 1});
      userData = userData!.copyWith(lastAttendDate: today, streak: 1);
      streakModalType = 'broken';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_streak') ?? true) await NotificationService.cancelNotification(2);
      notifyListeners();
      return;
    }
    int newStreak = userData!.lastAttendDate == yesterday ? userData!.streak + 1 : 1;
    int newMaxStreak = newStreak > userData!.maxStreak ? newStreak : userData!.maxStreak;
    await _db.updateUser(authUser!.uid, {'lastAttendDate': today, 'streak': newStreak, 'maxStreak': newMaxStreak});
    await _db.sendAttendanceMail(authUser!.uid, newStreak);
    userData = userData!.copyWith(lastAttendDate: today, streak: newStreak, maxStreak: newMaxStreak);
    await loadMailbox();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_streak') ?? true) {
      await NotificationService.cancelNotification(2);
      await NotificationService.scheduleStreakRiskReminder(newStreak);
    }
    final milestone = _milestones.firstWhere((m) => m['days'] == newStreak, orElse: () => <String, Object>{});
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
    while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
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
    if (_processingGoals.contains(goalId)) return;
    _processingGoals.add(goalId);
    try {
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
      final isRepeat = goal.repeatId != null;
      int xpGain = isRepeat ? goal.repeatXp : goal.xp;
      String toastMsg = '🎉 목표 완료! +$xpGain XP 획득';

      if (isRepeat) {
        final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
        final totalCount = repeatGoals.length;
        final doneCount = repeatGoals.where((g) => g.done).length + 1;
        final isLastRound = doneCount >= totalCount;

        if (isLastRound) {
          // 전체 완료한 경우만 보너스 XP 지급
          final allDone = doneCount == totalCount;
          if (allDone) {
            xpGain += goal.xp;
            showToast('🏆 반복 목표 전체 완료! +${goal.repeatXp + goal.xp} XP 획득');
          } else {
            // 중간 미완료 있을 경우 보너스 없이 달성률만 표시
            final pct = (doneCount / totalCount * 100).round();
            showToast('🎉 목표 완료! +$xpGain XP 획득');
            showToast('달성률 $pct%로 반복 목표 종료');
          }
          // toastMsg는 이미 위에서 showToast로 처리했으므로 스킵
          int newXp = userData!.xp + xpGain;
          int newLevel = userData!.level;
          int newXpToNext = userData!.xpToNext;
          while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
          await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
          userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
          if (newLevel > prevLevel) {
            levelUpTo = newLevel;
            await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()});
          }
          await loadGoals();
          notifyListeners();
          return;
        }
      }

      // 일반 완료 처리
      showToast(toastMsg);
      int newXp = userData!.xp + xpGain;
      int newLevel = userData!.level;
      int newXpToNext = userData!.xpToNext;
      while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
      userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
      if (newLevel > prevLevel) {
        levelUpTo = newLevel;
        await _db.updatePublicProfile(authUser!.uid, {'level': newLevel, 'name': userData!.name, 'character': userData!.character.toMap()});
      }
      await loadGoals();
      notifyListeners();
    } finally {
      _processingGoals.remove(goalId);
    }
  }

  void dismissLevelUp() { levelUpTo = null; notifyListeners(); }

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
        final doneCount = repeatGoals.where((g) => g.done).length;
        final totalCount = repeatGoals.length;
        if (doneCount >= totalCount) xpDeduct += goal.xp;
      }
      int newXp = userData!.xp - xpDeduct;
      int newLevel = userData!.level;
      int newXpToNext = userData!.xpToNext;
      while (newXp < 0 && newLevel > 1) { newLevel--; newXpToNext = (newXpToNext / 1.15).round(); newXp += newXpToNext; }
      newXp = newXp.clamp(0, 999999);
      await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext});
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
    return {'repeatId': goal.repeatId, 'total': repeatGoals.length, 'undone': repeatGoals.where((g) => !g.done).length};
  }

  // 마지막 회차인지 + 전체 완료인지 여부 반환 (UI 표시용)
  Map<String, dynamic> getRepeatStatus(String goalId) {
    final goal = goals.firstWhere((g) => g.id == goalId);
    if (goal.repeatId == null) return {'isLast': false, 'willAllDone': false};
    final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList()
      ..sort((a, b) => (a.scheduledDate ?? '').compareTo(b.scheduledDate ?? ''));
    final totalCount = repeatGoals.length;
    final currentIdx = repeatGoals.indexWhere((g) => g.id == goalId);
    final isLast = currentIdx == totalCount - 1;
    if (!isLast) return {'isLast': false, 'willAllDone': false};
    // 이 목표 제외한 나머지가 모두 완료인지 확인
    final othersAllDone = repeatGoals.where((g) => g.id != goalId).every((g) => g.done);
    return {'isLast': true, 'willAllDone': othersAllDone, 'doneCount': repeatGoals.where((g) => g.done).length + 1, 'totalCount': totalCount};
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
    while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'reviveItem': newRevive});
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, reviveItem: newRevive);
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
    await _db.updatePublicProfile(authUser!.uid, {'character': newChar.toMap(), 'name': userData!.name, 'level': userData!.level});
    await _diaryService.updateAuthorInfo(authUser!.uid, userData!.name, newChar.toMap(), userData!.level);
    userData = userData!.copyWith(character: newChar);
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    if (authUser == null || userData == null) return;
    await _db.updateUser(authUser!.uid, {'name': name});
    await _db.updatePublicProfile(authUser!.uid, {'name': name});
    await _diaryService.updateAuthorInfo(authUser!.uid, name, userData!.character.toMap(), userData!.level);
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
    authUser = null; userData = null; goals = []; mailbox = [];
    notifyListeners();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }

  // 토스트 큐: 여러 메시지를 1.5초씩 순서대로 표시
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
      toast = null;
      notifyListeners();
      if (_toastQueue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    _toastRunning = false;
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
    while (newXp >= newXpToNext) { newXp -= newXpToNext; newLevel++; newXpToNext = (newXpToNext * 1.15).round(); }
    await _db.updateUser(authUser!.uid, {'xp': newXp, 'level': newLevel, 'xpToNext': newXpToNext, 'totalFocusMin': newTotalFocus});
    await _db.updateTodayFocus(authUser!.uid, minutes);
    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext, totalFocusMin: newTotalFocus);
    if (newLevel > prevLevel) levelUpTo = newLevel;
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