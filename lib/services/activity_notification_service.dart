import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class ActivityNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 알림 저장 — 수신자 설정 확인 후 저장
  Future<void> _send(String targetUid, Map<String, dynamic> data, {String? prefKey}) async {
    // 본인에게는 알림 안 보냄
    if (data['fromUid'] == targetUid) return;
    // 수신자의 알림 설정 확인 (prefKey가 있는 경우)
    if (prefKey != null) {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notif_$prefKey') ?? true;
      if (!enabled) return;
    }
    await _db.collection('users').doc(targetUid).collection('notifications').add({
      ...data,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 좋아요 알림
  Future<void> sendLikeNotification({
    required String targetUid,
    required String fromUid,
    required String fromName,
    required Map<String, dynamic> fromCharacter,
    required String diaryId,
    required String diaryContent,
  }) async {
    await _send(targetUid, {
      'type': 'like',
      'fromUid': fromUid,
      'fromName': fromName,
      'fromCharacter': fromCharacter,
      'diaryId': diaryId,
      'diaryContent': diaryContent.length > 20 ? '${diaryContent.substring(0, 20)}...' : diaryContent,
    }, prefKey: 'activity_like');
  }

  // 댓글 알림
  Future<void> sendCommentNotification({
    required String targetUid,
    required String fromUid,
    required String fromName,
    required Map<String, dynamic> fromCharacter,
    required String diaryId,
    required String diaryContent,
    required String commentContent,
  }) async {
    await _send(targetUid, {
      'type': 'comment',
      'fromUid': fromUid,
      'fromName': fromName,
      'fromCharacter': fromCharacter,
      'diaryId': diaryId,
      'diaryContent': diaryContent.length > 20 ? '${diaryContent.substring(0, 20)}...' : diaryContent,
      'commentContent': commentContent.length > 30 ? '${commentContent.substring(0, 30)}...' : commentContent,
    }, prefKey: 'activity_comment');
  }

  // 대댓글 알림
  Future<void> sendReplyNotification({
    required String targetUid,
    required String fromUid,
    required String fromName,
    required Map<String, dynamic> fromCharacter,
    required String diaryId,
    required String commentContent,
    required String replyContent,
  }) async {
    await _send(targetUid, {
      'type': 'reply',
      'fromUid': fromUid,
      'fromName': fromName,
      'fromCharacter': fromCharacter,
      'diaryId': diaryId,
      'commentContent': commentContent.length > 20 ? '${commentContent.substring(0, 20)}...' : commentContent,
      'diaryContent': replyContent.length > 30 ? '${replyContent.substring(0, 30)}...' : replyContent,
    }, prefKey: 'activity_comment');
  }

  // 친구 요청 알림
  Future<void> sendFriendRequestNotification({
    required String targetUid,
    required String fromUid,
    required String fromName,
    required Map<String, dynamic> fromCharacter,
  }) async {
    await _send(targetUid, {
      'type': 'friend_request',
      'fromUid': fromUid,
      'fromName': fromName,
      'fromCharacter': fromCharacter,
    }, prefKey: 'activity_friend');
  }

  // 친구 수락 알림
  Future<void> sendFriendAcceptedNotification({
    required String targetUid,
    required String fromUid,
    required String fromName,
    required Map<String, dynamic> fromCharacter,
  }) async {
    await _send(targetUid, {
      'type': 'friend_accepted',
      'fromUid': fromUid,
      'fromName': fromName,
      'fromCharacter': fromCharacter,
    }, prefKey: 'activity_friend');
  }

  // 알림 목록 조회
  Future<List<NotificationModel>> getNotifications(String uid) async {
    final snap = await _db
        .collection('users').doc(uid).collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => NotificationModel.fromMap(d.id, d.data())).toList();
  }

  // 읽지 않은 알림 수
  Future<int> getUnreadCount(String uid) async {
    final snap = await _db
        .collection('users').doc(uid).collection('notifications')
        .where('read', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // 단일 알림 읽음 처리
  Future<void> markAsRead(String uid, String notifId) async {
    await _db.collection('users').doc(uid).collection('notifications').doc(notifId).update({'read': true});
  }

  // 전체 읽음 처리
  Future<void> markAllAsRead(String uid) async {
    final snap = await _db
        .collection('users').doc(uid).collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) batch.update(doc.reference, {'read': true});
    await batch.commit();
  }

  // 알림 삭제
  Future<void> deleteNotification(String uid, String notifId) async {
    await _db.collection('users').doc(uid).collection('notifications').doc(notifId).delete();
  }

  // 특정 발신자 + 타입의 알림 즉시 삭제 — 친구 요청 수락/거절 시 호출
  Future<void> deleteNotificationByFromUid(String uid, String fromUid, String type) async {
    final snap = await _db
        .collection('users').doc(uid).collection('notifications')
        .where('fromUid', isEqualTo: fromUid)
        .where('type', isEqualTo: type)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }

  // 특정 타입의 알림 전체 삭제 — 채팅방 입장 시 chat 알림 제거
  Future<void> deleteNotificationsByType(String uid, String type) async {
    final snap = await _db
        .collection('users').doc(uid).collection('notifications')
        .where('type', isEqualTo: type)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }

  // 30일 이상 된 알림 정리
  Future<void> cleanOldNotifications(String uid) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final snap = await _db
        .collection('users').doc(uid).collection('notifications')
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }
}