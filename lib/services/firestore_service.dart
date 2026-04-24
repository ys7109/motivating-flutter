import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../models/mail_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 유저
  Future<void> ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'name': user.displayName ?? '새로운 모험가',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'level': 1,
        'xp': 0,
        'xpToNext': 100,
        'streak': 0,
        'maxStreak': 0,
        'lastStreakDate': '',
        'reviveItem': 0,
        'streakBadges': {},
        'totalFocusMin': 0,
        'lastAttendDate': '',
        'character': {'skin': 'default', 'badge': 'none', 'frame': 'none'},
        'onboardingDone': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'lastLogin': FieldValue.serverTimestamp()});
    }
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromMap(snap.data()!);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // 목표
  Future<List<GoalModel>> getGoals(String uid) async {
    final snap = await _db
        .collection('users').doc(uid).collection('goals')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => GoalModel.fromMap(d.id, d.data())).toList();
  }

  // 단일 목표 추가
  Future<void> addGoal(String uid, Map<String, dynamic> goal) async {
    await _db.collection('users').doc(uid).collection('goals').add({
      ...goal,
      'progress': 0,
      'done': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 반복 목표 배치 추가 (500건 초과 시 자동 분할)
  Future<void> addGoalsBatch(String uid, List<Map<String, dynamic>> goals) async {
    const maxBatchSize = 500;
    final colRef = _db.collection('users').doc(uid).collection('goals');

    for (int i = 0; i < goals.length; i += maxBatchSize) {
      final chunk = goals.sublist(i, (i + maxBatchSize).clamp(0, goals.length));
      final batch = _db.batch();
      for (final goal in chunk) {
        final docRef = colRef.doc();
        batch.set(docRef, {
          ...goal,
          'progress': 0,
          'done': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> updateGoal(String uid, String goalId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).collection('goals').doc(goalId).update(data);
  }

  Future<void> deleteGoal(String uid, String goalId) async {
    await _db.collection('users').doc(uid).collection('goals').doc(goalId).delete();
  }

  Future<void> deleteRepeatGoals(String uid, String repeatId) async {
    final snap = await _db
        .collection('users').doc(uid).collection('goals')
        .where('repeatId', isEqualTo: repeatId)
        .where('done', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }

  // 집중 세션
  Future<void> saveFocusSession(String uid, int minutes) async {
    await _db.collection('users').doc(uid).collection('focusSessions').add({
      'minutes': minutes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 우편함
  Future<List<MailModel>> getMailbox(String uid) async {
    final snap = await _db
        .collection('users').doc(uid).collection('mailbox')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => MailModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> claimMail(String uid, String mailId) async {
    await _db.collection('users').doc(uid).collection('mailbox').doc(mailId).update({
      'read': true, 'claimed': true,
    });
  }

  Future<void> deleteMail(String uid, String mailId) async {
    await _db.collection('users').doc(uid).collection('mailbox').doc(mailId).delete();
  }

  Future<void> sendAttendanceMail(String uid, int streakDay) async {
    final xp = streakDay * 10;
    final isSpecial = streakDay % 7 == 0;
    await _db.collection('users').doc(uid).collection('mailbox').add({
      'title': '${streakDay}일차 출석 보상',
      'body': isSpecial
          ? '$streakDay일 연속 출석을 달성했어요! 특별 보상을 드립니다.'
          : '오늘도 접속해 주셨네요! ${streakDay}일차 출석 보상입니다.',
      'reward': {'xp': xp, 'reviveItem': isSpecial ? 1 : 0},
      'type': isSpecial ? 'attendance_special' : 'attendance',
      'read': false, 'claimed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 랭킹
  Future<List<Map<String, dynamic>>> getRankings(String type) async {
    final field = type == 'total' ? 'totalFocusMin'
        : type == 'daily' ? 'todayFocusMin'
        : 'avgFocusMin';
    final snap = await _db.collection('rankings').orderBy(field, descending: true).get();
    return snap.docs.asMap().entries.map((e) => {'rank': e.key + 1, ...e.value.data()}).toList();
  }

  Future<void> updatePublicProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('rankings').doc(uid).set({
      'uid': uid, ...data, 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateTodayFocus(String uid, int minutes) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final ref = _db.collection('rankings').doc(uid);
    final userSnap = await _db.collection('users').doc(uid).get();
    final userData = userSnap.data() ?? {};
    final snap = await ref.get();
    if (snap.exists) {
      final data = snap.data()!;
      final lastDate = data['lastFocusDate'] ?? '';
      final todayMin = lastDate == today ? (data['todayFocusMin'] ?? 0) + minutes : minutes;
      final totalMin = (data['totalFocusMin'] ?? 0) + minutes;
      final sessionCount = (data['sessionCount'] ?? 0) + 1;
      final avgFocusMin = (totalMin / sessionCount).round();
      await ref.update({
        'todayFocusMin': todayMin, 'totalFocusMin': totalMin,
        'avgFocusMin': avgFocusMin, 'sessionCount': sessionCount,
        'lastFocusDate': today, 'updatedAt': FieldValue.serverTimestamp(),
        'name': userData['name'] ?? '모험가',
        'level': userData['level'] ?? 1,
        'character': userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'},
      });
    } else {
      await ref.set({
        'uid': uid,
        'name': userData['name'] ?? '모험가',
        'level': userData['level'] ?? 1,
        'character': userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'},
        'todayFocusMin': minutes, 'totalFocusMin': minutes,
        'avgFocusMin': minutes, 'sessionCount': 1,
        'lastFocusDate': today, 'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<GoalModel>> getUserCompletedGoals(String uid) async {
    final snap = await _db
        .collection('users').doc(uid).collection('goals')
        .where('done', isEqualTo: true)
        .orderBy('completedAt', descending: true)
        .get();
    return snap.docs.map((d) => GoalModel.fromMap(d.id, d.data())).toList();
  }
}