import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'like' | 'comment' | 'reply' | 'friend_request' | 'friend_accepted'
  final String fromUid;
  final String fromName;
  final Map<String, dynamic> fromCharacter;
  final String? diaryId;
  final String? diaryContent; // 다이어리 내용 앞 20자
  final String? commentContent;
  final bool read;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    required this.fromCharacter,
    this.diaryId,
    this.diaryContent,
    this.commentContent,
    required this.read,
    this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      type: map['type'] ?? '',
      fromUid: map['fromUid'] ?? '',
      fromName: map['fromName'] ?? '모험가',
      fromCharacter: Map<String, dynamic>.from(
          map['fromCharacter'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
      diaryId: map['diaryId'] as String?,
      diaryContent: map['diaryContent'] as String?,
      commentContent: map['commentContent'] as String?,
      read: map['read'] ?? false,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  String get message {
    switch (type) {
      case 'like':         return '회원님의 다이어리를 좋아해요';
      case 'comment':      return '다이어리에 댓글을 남겼어요';
      case 'reply':        return '댓글에 답글을 남겼어요';
      case 'friend_request':  return '친구 요청을 보냈어요';
      case 'friend_accepted': return '친구 요청을 수락했어요';
      default: return '';
    }
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt!.month}/${createdAt!.day}';
  }
}