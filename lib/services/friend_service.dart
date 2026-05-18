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
    // 친구 수락 시 friend_request 알림 읽음 처리 — 배지에서 사라지도록
    final notifSnap = await _db
        .collection('users').doc(myUid).collection('notifications')
        .where('type', isEqualTo: 'friend_request')
        .where('fromUid', isEqualTo: fromUid)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in notifSnap.docs) {
      await doc.reference.update({'read': true});
    }
  }

  Future<void> removeFriend(String myUid, String otherUid) async {
    final id = _friendshipId(myUid, otherUid);
    await _db.collection('friendships').doc(id).delete();
  }

  // 친구 목록 조회 — presence 상태 포함
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
      final presenceStatus = _calcPresenceStatus(presenceData);
      return {
        ...userData,
        'uid': fUid,
        'presenceStatus': presenceStatus,
        'isOnline': presenceStatus == 'online',
        'isFocusing': presenceStatus == 'focusing',
      };
    });
    return await Future.wait(futures);
  }

  // presence 데이터 → 표준 포맷 변환 — friends_tab 서버 fetch 결과 파싱용
  Map<String, dynamic> buildPresenceData(String uid, Map<String, dynamic> data) {
    return {
      'uid': uid,
      'presenceStatus': _calcPresenceStatus(data),
      'lastSeen': data['lastSeen'],
    };
  }

  // Timestamp → DateTime 변환
  DateTime? _presenceTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // 접속 상태 계산 — 3분 이상 비활동 시 오프라인, 집중모드 중이면 focusing
  String _calcPresenceStatus(Map<String, dynamic> presenceData) {
    final isFocusing = presenceData['isFocusing'] == true;
    if (isFocusing) return 'focusing';
    // isOnline: false면 즉시 오프라인
    if (presenceData['isOnline'] == false) return 'offline';
    final lastActivityTime = _presenceTime(presenceData['lastActivity']);
    if (lastActivityTime == null) return 'offline';
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
      try {
        final friendUids = snap.docs.map((d) {
          final users = List<String>.from(d['users']);
          return users.firstWhere((u) => u != uid);
        }).toList();
        if (friendUids.isEmpty) return <Map<String, dynamic>>[];
        final futures = friendUids.map((fUid) async {
          try {
            final userSnap = await _db.collection('users').doc(fUid).get();
            // 탈퇴 유저는 문서가 없으므로 null 반환 후 필터링
            if (!userSnap.exists) return null;
            final presenceSnap = await _db.collection('presence').doc(fUid).get();
            final userData = userSnap.data() ?? {};
            final presenceData = presenceSnap.data() ?? {};
            final presenceStatus = _calcPresenceStatus(presenceData);
            return <String, dynamic>{
              ...userData,
              'uid': fUid,
              'presenceStatus': presenceStatus,
              'isOnline': presenceStatus == 'online',
              'isFocusing': presenceStatus == 'focusing',
            };
          } catch (_) {
            return null;
          }
        });
        final results = await Future.wait(futures);
        // 탈퇴 유저(null) 필터링
        return results.whereType<Map<String, dynamic>>().toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  // presence 실시간 스트림 — hasPendingWrites 필터링으로 pending 스냅샷 제외
  Stream<Map<String, dynamic>> presenceStream(String uid) {
    return _db.collection('presence').doc(uid).snapshots()
        .where((snap) => !snap.metadata.hasPendingWrites)
        .map((snap) {
          final data = snap.data() ?? {};
          return {
            'uid': uid,
            'presenceStatus': _calcPresenceStatus(data),
            'lastSeen': data['lastSeen'],
          };
        });
  }

  // 친구 요청 실시간 스트림
  Stream<List<Map<String, dynamic>>> requestsStream(String uid) {
    return _db.collection('friendships')
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snap) async {
      try {
        final requests = snap.docs.where((d) => d['requestedBy'] != uid).toList();
        if (requests.isEmpty) return <Map<String, dynamic>>[];
        final futures = requests.map((doc) async {
          try {
            final fromUid = List<String>.from(doc['users']).firstWhere((u) => u != uid);
            final userSnap = await _db.collection('users').doc(fromUid).get();
            return <String, dynamic>{'docId': doc.id, ...userSnap.data() ?? {}, 'uid': fromUid};
          } catch (_) {
            return <String, dynamic>{};
          }
        });
        final results = await Future.wait(futures);
        return results.where((r) => r.isNotEmpty).toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
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

  // presence + users 양쪽에 lastLogin 동시 저장
  // users.lastLogin은 friends_tab에서 서버 직접 조회로 접속 시각 표시에 사용
  Future<void> _setPresenceWithLastLogin(String uid, Map<String, dynamic> presenceData) async {
    final batch = _db.batch();
    batch.set(_db.collection('presence').doc(uid), presenceData, SetOptions(merge: true));
    // users.lastLogin 항상 최신으로 유지
    batch.set(_db.collection('users').doc(uid),
        {'lastLogin': presenceData['lastSeen']}, SetOptions(merge: true));
    await batch.commit();
  }

  // 온라인 상태 설정
  Future<void> setOnline(String uid) async {
    final now = FieldValue.serverTimestamp();
    await _setPresenceWithLastLogin(uid, {
      'isOnline': true,
      'lastSeen': now,
      'lastActivity': now,
      'isFocusing': false,
    });
  }

  // 활동 감지 시 lastActivity 갱신 (탭, 스크롤 등)
  Future<void> updateActivity(String uid) async {
    final now = FieldValue.serverTimestamp();
    await _setPresenceWithLastLogin(uid, {
      'lastActivity': now,
      'lastSeen': now,
    });
  }

  // 집중모드 시작
  Future<void> setFocusing(String uid) async {
    final now = FieldValue.serverTimestamp();
    await _setPresenceWithLastLogin(uid, {
      'isFocusing': true,
      'lastActivity': now,
      'lastSeen': now,
    });
  }

  // 집중모드 종료
  Future<void> clearFocusing(String uid) async {
    final now = FieldValue.serverTimestamp();
    await _setPresenceWithLastLogin(uid, {
      'isFocusing': false,
      'lastActivity': now,
      'lastSeen': now,
    });
  }

  // 오프라인 상태 설정 — isOnline: false로 즉시 오프라인 처리
  Future<void> setOffline(String uid) async {
    final now = FieldValue.serverTimestamp();
    await _setPresenceWithLastLogin(uid, {
      'isOnline': false,
      'lastSeen': now,
      'isFocusing': false,
    });
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