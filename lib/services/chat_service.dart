import 'package:cloud_firestore/cloud_firestore.dart';

// 고정 이모지 반응 6종
const kReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1:1 채팅방 ID (작은 uid가 앞으로 정렬)
  String directChatId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // 1:1 채팅방 생성 또는 기존 방 반환
  Future<String> getOrCreateDirectChat(String myUid, String otherUid) async {
    final id = directChatId(myUid, otherUid);
    final ref = _db.collection('chats').doc(id);
    if (!(await ref.get()).exists) {
      await ref.set({
        'type': 'direct',
        'users': [myUid, otherUid],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {myUid: 0, otherUid: 0},
        // lastReadAt: 각 유저가 마지막으로 읽은 시각 (카카오톡 방식)
        'lastReadAt': {myUid: FieldValue.serverTimestamp(), otherUid: Timestamp.fromMillisecondsSinceEpoch(0)},
      });
    }
    return id;
  }

  // 그룹 채팅방 생성
  Future<String> createGroupChat(String myUid, List<String> memberUids, String name) async {
    final allUsers = [myUid, ...memberUids];
    final unreadCount = {for (final uid in allUsers) uid: 0};
    final lastReadAt = {for (final uid in allUsers) uid: Timestamp.fromMillisecondsSinceEpoch(0)};
    final ref = await _db.collection('chats').add({
      'type': 'group',
      'name': name,
      'users': allUsers,
      'createdBy': myUid,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
      'lastReadAt': lastReadAt,
    });
    return ref.id;
  }

  // 메시지 전송 — 수신자 unread 카운트 +1
  Future<void> sendMessage(String chatId, String senderUid, List<String> receiverUids, String content) async {
    final batch = _db.batch();
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(msgRef, {
      'senderUid': senderUid,
      'content': content,
      'reactions': {},
      'createdAt': FieldValue.serverTimestamp(),
    });
    final unreadUpdate = {
      for (final uid in receiverUids) 'unreadCount.$uid': FieldValue.increment(1),
    };
    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': content,
      'lastMessageAt': FieldValue.serverTimestamp(),
      ...unreadUpdate,
    });
    await batch.commit();
  }

  // 이모지 반응 토글
  Future<void> toggleReaction(String chatId, String msgId, String myUid, String emoji) async {
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc(msgId);
    final snap = await ref.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final users = List<String>.from(reactions[emoji] ?? []);
    if (users.contains(myUid)) {
      users.remove(myUid);
    } else {
      users.add(myUid);
    }
    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }
    await ref.update({'reactions': reactions});
  }

  // 메시지 실시간 스트림
  Stream<QuerySnapshot> messagesStream(String chatId) {
    return _db
        .collection('chats').doc(chatId).collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // 채팅방 문서 실시간 스트림 (lastReadAt 변경 감지용)
  Stream<DocumentSnapshot> chatRoomStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  // 채팅방 입장 시 읽음 처리 — lastReadAt 업데이트 + unreadCount 초기화
  Future<void> markAsRead(String chatId, String myUid) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCount.$myUid': 0,
      'lastReadAt.$myUid': FieldValue.serverTimestamp(),
    });
  }

  // 특정 친구와의 미읽음 수 (친구 목록 배지용)
  Future<int> getTotalUnreadCountForUser(String myUid, String otherUid) async {
    final id = directChatId(myUid, otherUid);
    final snap = await _db.collection('chats').doc(id).get();
    if (!snap.exists) return 0;
    final unread = (snap.data()?['unreadCount'] as Map<String, dynamic>?) ?? {};
    return unread[myUid] as int? ?? 0;
  }

  // 전체 미읽음 수
  Future<int> getTotalUnreadCount(String uid) async {
    final snap = await _db.collection('chats').where('users', arrayContains: uid).get();
    int total = 0;
    for (final doc in snap.docs) {
      final unread = (doc.data()['unreadCount'] as Map<String, dynamic>?) ?? {};
      total += (unread[uid] as int? ?? 0);
    }
    return total;
  }

  // 전체 미읽음 실시간 스트림
  Stream<int> unreadCountStream(String uid) {
    return _db.collection('chats').where('users', arrayContains: uid).snapshots().map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final unread = (doc.data()['unreadCount'] as Map<String, dynamic>?) ?? {};
        total += (unread[uid] as int? ?? 0);
      }
      return total;
    });
  }
}

// 메시지 모델
class MessageModel {
  final String id;
  final String senderUid;
  final String content;
  final Map<String, List<String>> reactions;
  final DateTime? createdAt;

  MessageModel({
    required this.id, required this.senderUid,
    required this.content, required this.reactions,
    this.createdAt,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      senderUid: data['senderUid'] ?? '',
      content: data['content'] ?? '',
      reactions: rawReactions.map((k, v) => MapEntry(k, List<String>.from(v))),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  String get timeStr {
    if (createdAt == null) return '';
    final h = createdAt!.hour;
    final m = createdAt!.minute.toString().padLeft(2, '0');
    final amPm = h < 12 ? '오전' : '오후';
    final hour = h == 0 ? 12 : h > 12 ? h - 12 : h;
    return '$amPm $hour:$m';
  }
}