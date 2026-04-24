import 'package:cloud_firestore/cloud_firestore.dart';

class FriendModel {
  final String uid;
  final String name;
  final int level;
  final Map<String, dynamic> character;
  final String status; // pending | accepted
  final String requestedBy;
  final DateTime? createdAt;
  final DateTime? lastSeen; // 마지막 접속 시간
  final bool isOnline;

  FriendModel({
    required this.uid,
    required this.name,
    required this.level,
    required this.character,
    required this.status,
    required this.requestedBy,
    this.createdAt,
    this.lastSeen,
    this.isOnline = false,
  });

  factory FriendModel.fromMap(Map<String, dynamic> map) {
    return FriendModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '모험가',
      level: map['level'] ?? 1,
      character: map['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'},
      status: map['status'] ?? 'pending',
      requestedBy: map['requestedBy'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      lastSeen: map['lastSeen'] != null ? (map['lastSeen'] as Timestamp).toDate() : null,
      isOnline: map['isOnline'] ?? false,
    );
  }

  // 마지막 접속 시간 표시 텍스트
  String get lastSeenText {
    if (isOnline) return '접속 중';
    if (lastSeen == null) return '접속 정보 없음';
    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inMinutes < 1) return '방금 전 접속';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 접속';
    if (diff.inHours < 24) return '${diff.inHours}시간 전 접속';
    return '${diff.inDays}일 전 접속';
  }
}