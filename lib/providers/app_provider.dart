import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../models/mail_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final FirestoreService _db = FirestoreService();

  User? authUser;
  UserModel? userData;
  List<GoalModel> goals = [];
  List<MailModel> mailbox = [];
  bool loading = true;
  String? toast;

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
    _auth.authStateChanges.listen((user) async {
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
      }
      loading = false;
      notifyListeners();
    });
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
    int newStreak = userData!.lastAttendDate == yesterday
        ? userData!.streak + 1 : 1;
    int newMaxStreak = newStreak > userData!.maxStreak ? newStreak : userData!.maxStreak;

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
    notifyListeners();
  }

  Future<void> completeGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    final goal = goals.firstWhere((g) => g.id == goalId);
    if (goal.done) return;

    await _db.updateGoal(authUser!.uid, goalId, {
      'done': true,
      'progress': 100,
      'completedAt': FieldValue.serverTimestamp(),
    });

    int newXp = userData!.xp + goal.xp;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;

    while (newXp >= newXpToNext) {
      newXp -= newXpToNext;
      newLevel++;
      newXpToNext = (newXpToNext * 1.3).round();
    }

    await _db.updateUser(authUser!.uid, {
      'xp': newXp,
      'level': newLevel,
      'xpToNext': newXpToNext,
    });

    userData = userData!.copyWith(xp: newXp, level: newLevel, xpToNext: newXpToNext);
    await loadGoals();
    notifyListeners();
  }

  Future<void> uncompleteGoal(String goalId) async {
    if (authUser == null || userData == null) return;
    final goal = goals.firstWhere((g) => g.id == goalId);
    if (!goal.done) return;

    await _db.updateGoal(authUser!.uid, goalId, {
      'done': false,
      'progress': 0,
      'completedAt': null,
    });

    int newXp = (userData!.xp - goal.xp).clamp(0, 999999);
    await _db.updateUser(authUser!.uid, {'xp': newXp});
    userData = userData!.copyWith(xp: newXp);
    await loadGoals();
    notifyListeners();
  }

  Future<void> removeGoal(String goalId) async {
    if (authUser == null) return;
    await _db.deleteGoal(authUser!.uid, goalId);
    await loadGoals();
    notifyListeners();
  }

  Future<void> removeRepeatGoals(String repeatId) async {
    if (authUser == null) return;
    await _db.deleteRepeatGoals(authUser!.uid, repeatId);
    await loadGoals();
    notifyListeners();
  }

  Map<String, dynamic>? getRepeatInfo(String goalId) {
    final goal = goals.firstWhere((g) => g.id == goalId);
    if (goal.repeatId == null) return null;
    final repeatGoals = goals.where((g) => g.repeatId == goal.repeatId).toList();
    final undone = repeatGoals.where((g) => !g.done).length;
    return {
      'repeatId': goal.repeatId,
      'total': repeatGoals.length,
      'undone': undone,
    };
  }

  Future<void> claimMailReward(String mailId) async {
    if (authUser == null || userData == null) return;
    final mail = mailbox.firstWhere((m) => m.id == mailId);
    if (mail.claimed) return;

    await _db.claimMail(authUser!.uid, mailId);

    int newXp = userData!.xp + mail.reward.xp;
    int newRevive = userData!.reviveItem + mail.reward.reviveItem;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;

    while (newXp >= newXpToNext) {
      newXp -= newXpToNext;
      newLevel++;
      newXpToNext = (newXpToNext * 1.3).round();
    }

    await _db.updateUser(authUser!.uid, {
      'xp': newXp,
      'level': newLevel,
      'xpToNext': newXpToNext,
      'reviveItem': newRevive,
    });

    userData = userData!.copyWith(
      xp: newXp, level: newLevel,
      xpToNext: newXpToNext, reviveItem: newRevive,
    );
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
    await _db.updateUser(authUser!.uid, {
      'name': nickname,
      'onboardingDone': true,
    });
    userData = userData!.copyWith(name: nickname, onboardingDone: true);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
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

    final xpGain = (minutes ~/ 10) * 50;
    int newXp = userData!.xp + xpGain;
    int newLevel = userData!.level;
    int newXpToNext = userData!.xpToNext;
    int newTotalFocus = userData!.totalFocusMin + minutes;

    while (newXp >= newXpToNext) {
      newXp -= newXpToNext;
      newLevel++;
      newXpToNext = (newXpToNext * 1.3).round();
    }

    await _db.updateUser(authUser!.uid, {
      'xp': newXp,
      'level': newLevel,
      'xpToNext': newXpToNext,
      'totalFocusMin': newTotalFocus,
    });
    await _db.updateTodayFocus(authUser!.uid, minutes);

    userData = userData!.copyWith(
      xp: newXp, level: newLevel,
      xpToNext: newXpToNext, totalFocusMin: newTotalFocus,
    );
    notifyListeners();
  }
}