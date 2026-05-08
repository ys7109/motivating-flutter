import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_model.dart';
import 'activity_notification_service.dart';

class DiaryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _notifService = ActivityNotificationService();

  // 다이어리 CRUD

  Future<List<DiaryModel>> getMyDiaries(String uid) async {
    final snap = await _db.collection('diaries').where('uid', isEqualTo: uid).get();
    final results = snap.docs.map((d) => DiaryModel.fromMap(d.id, d.data())).toList();
    results.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return results;
  }

  Future<List<DiaryModel>> getFriendDiaries(String myUid, List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    final chunks = <List<String>>[];
    for (int i = 0; i < friendUids.length; i += 30) {
      chunks.add(friendUids.sublist(i, (i + 30).clamp(0, friendUids.length)));
    }
    final results = <DiaryModel>[];
    for (final chunk in chunks) {
      final snap = await _db.collection('diaries')
          .where('uid', whereIn: chunk)
          .where('visibility', whereIn: ['friends', 'public'])
          .get();
      for (final d in snap.docs) {
        final likedByMe = await _isLiked(myUid, d.id);
        results.add(DiaryModel.fromMap(d.id, d.data(), likedByMe: likedByMe));
      }
    }
    results.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return results;
  }

  Future<List<DiaryModel>> getPublicDiaries(String myUid) async {
    final snap = await _db.collection('diaries')
        .where('visibility', isEqualTo: 'public')
        .limit(30)
        .get();
    final results = <DiaryModel>[];
    for (final d in snap.docs) {
      final likedByMe = await _isLiked(myUid, d.id);
      results.add(DiaryModel.fromMap(d.id, d.data() as Map<String, dynamic>, likedByMe: likedByMe));
    }
    results.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return results;
  }

  Future<void> addDiary(String uid, Map<String, dynamic> userData, String content, String visibility) async {
    await _db.collection('diaries').add({
      'uid': uid,
      'authorName': userData['name'] ?? '모험가',
      'authorCharacter': userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'},
      'authorLevel': userData['level'] ?? 1,
      'authorEquippedAchievement': userData['equippedAchievement'],
      'content': content,
      'visibility': visibility,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDiary(String diaryId, String content, String visibility) async {
    await _db.collection('diaries').doc(diaryId).update({
      'content': content,
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAuthorInfo(String uid, String name, Map<String, dynamic> character, int level,
      {String? equippedAchievement}) async {
    final snap = await _db.collection('diaries').where('uid', isEqualTo: uid).get();
    if (snap.docs.isEmpty) return;
    const maxBatch = 500;
    for (int i = 0; i < snap.docs.length; i += maxBatch) {
      final chunk = snap.docs.sublist(i, (i + maxBatch).clamp(0, snap.docs.length));
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {
          'authorName': name, 'authorCharacter': character,
          'authorLevel': level, 'authorEquippedAchievement': equippedAchievement,
        });
      }
      await batch.commit();
    }
  }

  Future<void> deleteDiary(String diaryId) async {
    final comments = await _db.collection('diaries').doc(diaryId).collection('comments').get();
    final batch = _db.batch();
    for (final c in comments.docs) {
      final replies = await c.reference.collection('replies').get();
      for (final r in replies.docs) batch.delete(r.reference);
      batch.delete(c.reference);
    }
    batch.delete(_db.collection('diaries').doc(diaryId));
    await batch.commit();
  }

  // 좋아요 토글 + 알림
  Future<bool> toggleLike(String myUid, String diaryId,
      {Map<String, dynamic>? myUserData}) async {
    final likeRef = _db.collection('diaries').doc(diaryId).collection('likes').doc(myUid);
    final snap = await likeRef.get();
    final diaryRef = _db.collection('diaries').doc(diaryId);

    if (snap.exists) {
      await likeRef.delete();
      await diaryRef.update({'likeCount': FieldValue.increment(-1)});
      return false;
    } else {
      await likeRef.set({'uid': myUid, 'createdAt': FieldValue.serverTimestamp()});
      await diaryRef.update({'likeCount': FieldValue.increment(1)});

      // 좋아요 알림 전송
      if (myUserData != null) {
        final diarySnap = await diaryRef.get();
        final diaryData = diarySnap.data();
        if (diaryData != null && diaryData['uid'] != myUid) {
          await _notifService.sendLikeNotification(
            targetUid: diaryData['uid'],
            fromUid: myUid,
            fromName: myUserData['name'] ?? '모험가',
            fromCharacter: Map<String, dynamic>.from(
                myUserData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
            diaryId: diaryId,
            diaryContent: diaryData['content'] ?? '',
          );
        }
      }
      return true;
    }
  }

  Future<bool> _isLiked(String myUid, String diaryId) async {
    final snap = await _db.collection('diaries').doc(diaryId).collection('likes').doc(myUid).get();
    return snap.exists;
  }

  // 댓글 CRUD

  Future<List<CommentModel>> getComments(String diaryId) async {
    final snap = await _db
        .collection('diaries').doc(diaryId).collection('comments')
        .orderBy('createdAt', descending: false)
        .get();
    final comments = <CommentModel>[];
    for (final doc in snap.docs) {
      final repliesSnap = await doc.reference.collection('replies')
          .orderBy('createdAt', descending: false).get();
      final replies = repliesSnap.docs.map((r) => ReplyModel.fromMap(r.id, r.data())).toList();
      comments.add(CommentModel.fromMap(doc.id, doc.data(), replies: replies));
    }
    return comments;
  }

  // 댓글 작성 + 알림
  Future<void> addComment(String diaryId, Map<String, dynamic> userData, String content) async {
    final batch = _db.batch();
    final commentRef = _db.collection('diaries').doc(diaryId).collection('comments').doc();
    batch.set(commentRef, {
      'uid': userData['uid'],
      'authorName': userData['name'] ?? '모험가',
      'authorCharacter': userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'},
      'authorEquippedAchievement': userData['equippedAchievement'],
      'content': content,
      'replyCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('diaries').doc(diaryId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();

    // 댓글 알림 전송 (다이어리 작성자에게)
    final diarySnap = await _db.collection('diaries').doc(diaryId).get();
    final diaryData = diarySnap.data();
    if (diaryData != null && diaryData['uid'] != userData['uid']) {
      await _notifService.sendCommentNotification(
        targetUid: diaryData['uid'],
        fromUid: userData['uid'],
        fromName: userData['name'] ?? '모험가',
        fromCharacter: Map<String, dynamic>.from(
            userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
        diaryId: diaryId,
        diaryContent: diaryData['content'] ?? '',
        commentContent: content,
      );
    }
  }

  Future<void> deleteComment(String diaryId, String commentId, int replyCount) async {
    final commentRef = _db.collection('diaries').doc(diaryId).collection('comments').doc(commentId);
    final replies = await commentRef.collection('replies').get();
    final batch = _db.batch();
    for (final r in replies.docs) batch.delete(r.reference);
    batch.delete(commentRef);
    batch.update(_db.collection('diaries').doc(diaryId), {
      'commentCount': FieldValue.increment(-(1 + replyCount)),
    });
    await batch.commit();
  }

  // 대댓글 CRUD

  // 대댓글 작성 + 알림 (댓글 작성자에게)
  Future<void> addReply(String diaryId, String commentId, Map<String, dynamic> userData,
      String content, {String? commentAuthorUid, String? commentContent}) async {
    final batch = _db.batch();
    final replyRef = _db
        .collection('diaries').doc(diaryId)
        .collection('comments').doc(commentId)
        .collection('replies').doc();
    batch.set(replyRef, {
      'uid': userData['uid'],
      'authorName': userData['name'] ?? '모험가',
      'authorCharacter': userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'},
      'authorEquippedAchievement': userData['equippedAchievement'],
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(
      _db.collection('diaries').doc(diaryId).collection('comments').doc(commentId),
      {'replyCount': FieldValue.increment(1)},
    );
    batch.update(_db.collection('diaries').doc(diaryId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();

    // 대댓글 알림 (댓글 작성자에게, 본인 댓글이 아닌 경우)
    if (commentAuthorUid != null && commentAuthorUid != userData['uid']) {
      await _notifService.sendReplyNotification(
        targetUid: commentAuthorUid,
        fromUid: userData['uid'],
        fromName: userData['name'] ?? '모험가',
        fromCharacter: Map<String, dynamic>.from(
            userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
        diaryId: diaryId,
        commentContent: commentContent ?? '',
        replyContent: content,
      );
    }
  }

  Future<void> deleteReply(String diaryId, String commentId, String replyId) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('diaries').doc(diaryId)
        .collection('comments').doc(commentId)
        .collection('replies').doc(replyId));
    batch.update(
      _db.collection('diaries').doc(diaryId).collection('comments').doc(commentId),
      {'replyCount': FieldValue.increment(-1)},
    );
    batch.update(_db.collection('diaries').doc(diaryId), {
      'commentCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }
}

// CommentModel
class CommentModel {
  final String id;
  final String uid;
  final String authorName;
  final Map<String, dynamic> authorCharacter;
  final String? authorEquippedAchievement;
  final String content;
  final int replyCount;
  final List<ReplyModel> replies;
  final DateTime? createdAt;

  CommentModel({
    required this.id, required this.uid, required this.authorName,
    required this.authorCharacter, this.authorEquippedAchievement,
    required this.content, this.replyCount = 0,
    this.replies = const [], this.createdAt,
  });

  factory CommentModel.fromMap(String id, Map<String, dynamic> map, {List<ReplyModel> replies = const []}) {
    return CommentModel(
      id: id, uid: map['uid'] ?? '',
      authorName: map['authorName'] ?? '모험가',
      authorCharacter: Map<String, dynamic>.from(
          map['authorCharacter'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
      authorEquippedAchievement: map['authorEquippedAchievement'] as String?,
      content: map['content'] ?? '',
      replyCount: map['replyCount'] ?? 0,
      replies: replies,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ReplyModel
class ReplyModel {
  final String id;
  final String uid;
  final String authorName;
  final Map<String, dynamic> authorCharacter;
  final String? authorEquippedAchievement;
  final String content;
  final DateTime? createdAt;

  ReplyModel({
    required this.id, required this.uid, required this.authorName,
    required this.authorCharacter, this.authorEquippedAchievement,
    required this.content, this.createdAt,
  });

  factory ReplyModel.fromMap(String id, Map<String, dynamic> map) {
    return ReplyModel(
      id: id, uid: map['uid'] ?? '',
      authorName: map['authorName'] ?? '모험가',
      authorCharacter: Map<String, dynamic>.from(
          map['authorCharacter'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
      authorEquippedAchievement: map['authorEquippedAchievement'] as String?,
      content: map['content'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}