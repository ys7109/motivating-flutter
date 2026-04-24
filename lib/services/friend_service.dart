import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_model.dart';
import 'package:flutter/foundation.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 두 uid로 friendship 문서 ID 생성 (작은 uid가 앞)
  String _friendshipId(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // 친구 요청 전송
  Future<void> sendRequest(String myUid, String targetUid) async {
    final id = _friendshipId(myUid, targetUid);
    await _db.collection('friendships').doc(id).set({
      'users': [myUid, targetUid],
      'status': 'pending',
      'requestedBy': myUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 친구 요청 수락
  Future<void> acceptRequest(String myUid, String fromUid) async {
    final id = _friendshipId(myUid, fromUid);
    await _db.collection('friendships').doc(id).update({'status': 'accepted'});
  }

  // 친구 요청 거절 / 친구 삭제
  Future<void> removeFriend(String myUid, String otherUid) async {
    final id = _friendshipId(myUid, otherUid);
    await _db.collection('friendships').doc(id).delete();
  }

  // 친구 목록 조회 (수락된 것만)
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

    // 친구 유저 정보 + presence 조회
    final futures = friendUids.map((fUid) async {
      final userSnap = await _db.collection('users').doc(fUid).get();
      final presenceSnap = await _db.collection('presence').doc(fUid).get();
      final userData = userSnap.data() ?? {};
      final presenceData = presenceSnap.data() ?? {};
      return {
        ...userData,
        'uid': fUid,
        'isOnline': presenceData['isOnline'] ?? false,
        'lastSeen': presenceData['lastSeen'],
      };
    });
    return await Future.wait(futures);
  }

  // 받은 친구 요청 목록
  Future<List<Map<String, dynamic>>> getReceivedRequests(String uid) async {
    final snap = await _db.collection('friendships')
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: 'pending')
        .get();

    final requests = snap.docs
        .where((d) => d['requestedBy'] != uid)
        .toList();

    if (requests.isEmpty) return [];

    final futures = requests.map((doc) async {
      final fromUid = (List<String>.from(doc['users'])).firstWhere((u) => u != uid);
      final userSnap = await _db.collection('users').doc(fromUid).get();
      return {'docId': doc.id, ...userSnap.data() ?? {}, 'uid': fromUid};
    });
    return await Future.wait(futures);
  }

  // 닉네임으로 유저 검색
  Future<List<Map<String, dynamic>>> searchUsers(String name, String myUid) async {
    debugPrint('검색어: $name');
    final snap = await _db.collection('users')
        .where('name', isEqualTo: name)
        .limit(20)
        .get();
    debugPrint('검색 결과 수: ${snap.docs.length}');  // ← 이게 없었던 것 같아요
    return snap.docs
        .where((d) => d.id != myUid)
        .map((d) => {'uid': d.id, ...d.data()})
        .toList();
    }

  // 특정 유저와의 친구 관계 상태 확인
  Future<String?> getFriendshipStatus(String myUid, String otherUid) async {
    final id = _friendshipId(myUid, otherUid);
    final snap = await _db.collection('friendships').doc(id).get();
    if (!snap.exists) return null;
    return snap.data()?['status'] as String?;
  }

  // Presence 업데이트 (온라인)
  Future<void> setOnline(String uid) async {
    await _db.collection('presence').doc(uid).set({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Presence 업데이트 (오프라인)
  Future<void> setOffline(String uid) async {
    await _db.collection('presence').doc(uid).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Presence 실시간 스트림
  Stream<Map<String, dynamic>> presenceStream(String uid) {
    return _db.collection('presence').doc(uid).snapshots().map((s) => s.data() ?? {});
  }

  // 친구들의 전체 랭킹 등수 조회
  Future<List<Map<String, dynamic>>> getFriendRankings(String uid, String type) async {
    final friends = await getFriends(uid);
    final friendUids = friends.map((f) => f['uid'] as String).toSet();
    friendUids.add(uid); // 본인도 포함

    final field = type == 'total' ? 'totalFocusMin'
        : type == 'daily' ? 'todayFocusMin'
        : 'avgFocusMin';

    final snap = await _db.collection('rankings').orderBy(field, descending: true).get();
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < snap.docs.length; i++) {
      final data = snap.docs[i].data();
      if (friendUids.contains(data['uid'])) {
        result.add({'rank': i + 1, ...data});
      }
    }
    return result;
  }
}