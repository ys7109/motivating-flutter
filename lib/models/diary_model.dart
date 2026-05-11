import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryModel {
  final String id;
  final String uid;
  final String authorName;
  final Map<String, dynamic> authorCharacter;
  final int authorLevel;
  final String? authorEquippedAchievement;
  // 작성자 프로필 이미지 URL — 소셜 탭에서 프로필 이미지 표시용
  final String? authorProfileImageUrl;
  final String content;
  final String visibility; // private | friends | public
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiaryModel({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.authorCharacter,
    required this.authorLevel,
    this.authorEquippedAchievement,
    this.authorProfileImageUrl,
    required this.content,
    required this.visibility,
    required this.likeCount,
    this.commentCount = 0,
    required this.likedByMe,
    this.createdAt,
    this.updatedAt,
  });

  factory DiaryModel.fromMap(String id, Map<String, dynamic> map, {bool likedByMe = false}) {
    return DiaryModel(
      id: id,
      uid: map['uid'] ?? '',
      authorName: map['authorName'] ?? '모험가',
      authorCharacter: Map<String, dynamic>.from(
          map['authorCharacter'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'}),
      authorLevel: map['authorLevel'] ?? 1,
      authorEquippedAchievement: map['authorEquippedAchievement'] as String?,
      authorProfileImageUrl: map['authorProfileImageUrl'] as String?,
      content: map['content'] ?? '',
      visibility: map['visibility'] ?? 'private',
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      likedByMe: likedByMe,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  String get visibilityLabel {
    if (visibility == 'private') return '🔒 비공개';
    if (visibility == 'friends') return '👥 친구 공개';
    return '🌐 전체 공개';
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt!.year}.${createdAt!.month.toString().padLeft(2, '0')}.${createdAt!.day.toString().padLeft(2, '0')}';
  }
}