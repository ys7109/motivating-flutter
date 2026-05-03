import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'activity_notification_service.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _friendshipId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // 친구 요청 전송 + 알림
  Future<void> sendRequest(String myUid, String targetUid) async {
    final id = _friendshipId(myUid, targetUid);
    await _db.collection('friendships').doc(id).set({
      'users': [myUid, targetUid],
      'status': 'pending',
      'requestedBy': myUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final mySnap = await _db.collection('users').doc(myUid).get();
    final myData = mySnap.data() ?? {};
    await ActivityNotificationService().sendFriendRequestNotification(
      targetUid: targetUid,
      fromUid: myUid,
      fromName: myData['name'] ?? '모험가',
      fromCharacter: Map<String, dynamic>.from(
          myData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
    );
  }

  // 친구 요청 수락 + 알림
  Future<void> acceptRequest(String myUid, String fromUid) async {
    final id = _friendshipId(myUid, fromUid);
    await _db.collection('friendships').doc(id).update({'status': 'accepted'});
    final mySnap = await _db.collection('users').doc(myUid).get();
    final myData = mySnap.data() ?? {};
    await ActivityNotificationService().sendFriendAcceptedNotification(
      targetUid: fromUid,
      fromUid: myUid,
      fromName: myData['name'] ?? '모험가',
      fromCharacter: Map<String, dynamic>.from(
          myData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
    );
  }

  Future<void> removeFriend(String myUid, String otherUid) async {
    final id = _friendshipId(myUid, otherUid);
    await _db.collection('friendships').doc(id).delete();
  }

  // 친구 목록 조회 — presence 상태 계산 포함
  Future<List<Map<String, dynamic>>> getFriends(String uid) async {
    final snap = await _db.collection('friendships')
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final friendUids = snap.docs.map((d) {
      final users = List<String>.from(d['users']);
      return users.firstWhere((u) => u != uid);
    }).toList();
    if (friendUids.isEmpty) return [];
    final futures = friendUids.map((fUid) async {
      final userSnap = await _db.collection('users').doc(fUid).get();
      final presenceSnap = await _db.collection('presence').doc(fUid).get();
      final userData = userSnap.data() ?? {};
      final presenceData = presenceSnap.data() ?? {};
      // 접속 상태 계산
      final presenceStatus = _calcPresenceStatus(presenceData);
      return {
        ...userData,
        'uid': fUid,
        'presenceStatus': presenceStatus, // 'online' | 'focusing' | 'offline'
        'isOnline': presenceStatus == 'online',
        'isFocusing': presenceStatus == 'focusing',
        'lastSeen': presenceData['lastSeen'],
      };
    });
    return await Future.wait(futures);
  }

  // 접속 상태 계산 — 3분 이상 비활동 시 오프라인, 집중모드 중이면 focusing
  String _calcPresenceStatus(Map<String, dynamic> presenceData) {
    final isFocusing = presenceData['isFocusing'] == true;
    if (isFocusing) return 'focusing';

    final lastActivity = presenceData['lastActivity'];
    if (lastActivity == null) return 'offline';

    final lastActivityTime = (lastActivity as Timestamp).toDate();
    final diff = DateTime.now().difference(lastActivityTime);
    // 3분 이상 활동 없으면 오프라인
    if (diff.inMinutes >= 3) return 'offline';
    return 'online';
  }

  Future<List<Map<String, dynamic>>> getReceivedRequests(String uid) async {
    final snap = await _db.collection('friendships')
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: 'pending')
        .get();
    final requests = snap.docs.where((d) => d['requestedBy'] != uid).toList();
    if (requests.isEmpty) return [];
    final futures = requests.map((doc) async {
      final fromUid = (List<String>.from(doc['users'])).firstWhere((u) => u != uid);
      final userSnap = await _db.collection('users').doc(fromUid).get();
      return {'docId': doc.id, ...userSnap.data() ?? {}, 'uid': fromUid};
    });
    return await Future.wait(futures);
  }

  // 친구 목록 실시간 스트림
  Stream<List<Map<String, dynamic>>> friendsStream(String uid) {
    return _db.collection('friendships')
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((snap) async {
      final friendUids = snap.docs.map((d) {
        final users = List<String>.from(d['users']);
        return users.firstWhere((u) => u != uid);
      }).toList();
      if (friendUids.isEmpty) return [];
      final futures = friendUids.map((fUid) async {
        final userSnap = await _db.collection('users').doc(fUid).get();
        final presenceSnap = await _db.collection('presence').doc(fUid).get();
        final userData = userSnap.data() ?? {};
        final presenceData = presenceSnap.data() ?? {};
        final presenceStatus = _calcPresenceStatus(presenceData);
        return {
          ...userData,
          'uid': fUid,
          'presenceStatus': presenceStatus,
          'isOnline': presenceStatus == 'online',
          'isFocusing': presenceStatus == 'focusing',
          'lastSeen': presenceData['lastSeen'],
        };
      });
      return await Future.wait(futures);
    });
  }

  // 친구 요청 실시간 스트림
  Stream<List<Map<String, dynamic>>> requestsStream(String uid) {
    return _db.collection('friendships')
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snap) async {
      final requests = snap.docs.where((d) => d['requestedBy'] != uid).toList();
      if (requests.isEmpty) return [];
      final futures = requests.map((doc) async {
        final fromUid = List<String>.from(doc['users']).firstWhere((u) => u != uid);
        final userSnap = await _db.collection('users').doc(fromUid).get();
        return {'docId': doc.id, ...userSnap.data() ?? {}, 'uid': fromUid};
      });
      return await Future.wait(futures);
    });
  }

  Future<List<Map<String, dynamic>>> searchUsers(String name, String myUid) async {
    debugPrint('검색어: $name');
    final snap = await _db.collection('users').where('name', isEqualTo: name).limit(20).get();
    debugPrint('검색 결과 수: ${snap.docs.length}');
    return snap.docs.where((d) => d.id != myUid).map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  Future<String?> getFriendshipStatus(String myUid, String otherUid) async {
    final id = _friendshipId(myUid, otherUid);
    final snap = await _db.collection('friendships').doc(id).get();
    if (!snap.exists) return null;
    return snap.data()?['status'] as String?;
  }

  // 온라인 상태 설정 — lastActivity 타임스탬프 갱신
  Future<void> setOnline(String uid) async {
    await _db.collection('presence').doc(uid).set({
      'lastSeen': FieldValue.serverTimestamp(),
      'lastActivity': FieldValue.serverTimestamp(),
      'isFocusing': false,
    }, SetOptions(merge: true));
  }

  // 활동 감지 시 lastActivity 갱신 (탭, 스크롤 등)
  Future<void> updateActivity(String uid) async {
    await _db.collection('presence').doc(uid).set({
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 집중모드 시작
  Future<void> setFocusing(String uid) async {
    await _db.collection('presence').doc(uid).set({
      'isFocusing': true,
      'lastActivity': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 집중모드 종료
  Future<void> clearFocusing(String uid) async {
    await _db.collection('presence').doc(uid).set({
      'isFocusing': false,
      'lastActivity': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setOffline(String uid) async {
    await _db.collection('presence').doc(uid).set({
      'lastSeen': FieldValue.serverTimestamp(),
      'lastActivity': FieldValue.serverTimestamp(),
      'isFocusing': false,
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> presenceStream(String uid) {
    return _db.collection('presence').doc(uid).snapshots()
        .map((s) => s.data() ?? {});
  }

  Future<List<Map<String, dynamic>>> getFriendRankings(String uid, String type) async {
    final friends = await getFriends(uid);
    final friendUids = friends.map((f) => f['uid'] as String).toSet();
    friendUids.add(uid);
    final field = type == 'total' ? 'totalFocusMin'
        : type == 'daily' ? 'todayFocusMin' : 'avgFocusMin';
    final snap = await _db.collection('rankings').orderBy(field, descending: true).get();
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < snap.docs.length; i++) {
      final data = snap.docs[i].data();
      if (friendUids.contains(data['uid'])) result.add({'rank': i + 1, ...data});
    }
    return result;
  }
}