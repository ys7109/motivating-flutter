import 'package:cloud_firestore/cloud_firestore.dart';

// 고정 이모지 반응 6종
const kReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1:1 채팅방 ID — 작은 uid가 앞으로 정렬해서 항상 동일한 ID 생성
  String directChatId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // 1:1 채팅방 생성 또는 기존 방 반환
  Future<String> getOrCreateDirectChat(String myUid, String otherUid) async {
    final id = directChatId(myUid, otherUid);
    final ref = _db.collection('chats').doc(id);
    final snap = await ref.get();
    final mySnap = await _db.collection('users').doc(myUid).get();
    final otherSnap = await _db.collection('users').doc(otherUid).get();
    final myName = mySnap.data()?['name'] as String? ?? '모험가';
    final otherName = otherSnap.data()?['name'] as String? ?? '모험가';

    if (!snap.exists) {
      await ref.set({
        'type': 'direct',
        'users': [myUid, otherUid],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {myUid: 0, otherUid: 0},
        'lastReadAt': {
          myUid: FieldValue.serverTimestamp(),
          otherUid: Timestamp.fromMillisecondsSinceEpoch(0),
        },
        'names': {myUid: otherName, otherUid: myName},
      });
    } else {
      final users = List<String>.from(snap.data()?['users'] ?? []);
      final updates = <String, dynamic>{};
      if (!users.contains(myUid)) {
        updates['users'] = FieldValue.arrayUnion([myUid]);
        updates['unreadCount.$myUid'] = 0;
        updates['lastReadAt.$myUid'] = FieldValue.serverTimestamp();
      }
      if (!users.contains(otherUid)) {
        updates['users'] = FieldValue.arrayUnion([otherUid]);
        updates['unreadCount.$otherUid'] = 0;
        updates['lastReadAt.$otherUid'] = Timestamp.fromMillisecondsSinceEpoch(0);
      }
      if (snap.data()?['names'] == null) {
        updates['names'] = {myUid: otherName, otherUid: myName};
      }
      if (updates.isNotEmpty) await ref.update(updates);
    }
    return id;
  }

  // 그룹 채팅방 생성
  Future<String> createGroupChat(
      String myUid, List<String> memberUids, String name) async {
    final allUsers = [myUid, ...memberUids];
    final unreadCount = {for (final uid in allUsers) uid: 0};
    final lastReadAt = {
      for (final uid in allUsers) uid: Timestamp.fromMillisecondsSinceEpoch(0),
    };
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

  // 메시지 전송 — type: 'text' | 'image' | 'system'
  Future<void> sendMessage(
    String chatId,
    String senderUid,
    List<String> receiverUids,
    String content, {
    String type = 'text',
  }) async {
    final batch = _db.batch();
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(msgRef, {
      'senderUid': senderUid,
      'receiverUids': receiverUids,
      'content': content,
      'type': type,
      'reactions': {},
      'isEdited': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final unreadUpdate = {
      for (final uid in receiverUids) 'unreadCount.$uid': FieldValue.increment(1),
    };
    final lastMessageText = type == 'image' ? '📷 사진' : content;
    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': lastMessageText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      ...unreadUpdate,
    });
    await batch.commit();
  }

  // 5번: 메시지 수정 — isEdited: true 표시
  Future<void> editMessage(String chatId, String msgId, String newContent) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(msgId).update({
      'content': newContent,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // 5번: 메시지 삭제 — 내용을 '메시지가 삭제되었습니다.'로 교체, type을 'deleted'로 변경
  // 그룹 채팅 퇴장과 동일한 방식으로 시스템 메시지 처리
  Future<void> deleteMessage(String chatId, String msgId, {String? senderName}) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(msgId).update({
      'content': '메시지가 삭제되었습니다.',
      'type': 'deleted',
      'reactions': {},
    });
  }

  // 이모지 반응 토글
  Future<void> toggleReaction(
      String chatId, String msgId, String myUid, String emoji) async {
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc(msgId);
    final snap = await ref.get();
    final data = snap.data() ?? {};
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
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // 채팅방 문서 실시간 스트림
  Stream<DocumentSnapshot> chatRoomStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  // 채팅방 입장 시 읽음 처리
  Future<void> markAsRead(String chatId, String myUid) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCount.$myUid': 0,
      'lastReadAt.$myUid': FieldValue.serverTimestamp(),
    });
  }

  // 특정 친구와의 미읽음 수
  Future<int> getTotalUnreadCountForUser(String myUid, String otherUid) async {
    final id = directChatId(myUid, otherUid);
    final snap = await _db.collection('chats').doc(id).get();
    if (!snap.exists) return 0;
    final unread = (snap.data()?['unreadCount'] as Map<String, dynamic>?) ?? {};
    return unread[myUid] as int? ?? 0;
  }

  // 전체 미읽음 수
  Future<int> getTotalUnreadCount(String uid) async {
    final snap = await _db.collection('chats')
        .where('users', arrayContains: uid).get();
    int total = 0;
    for (final doc in snap.docs) {
      final unread = (doc.data()['unreadCount'] as Map<String, dynamic>?) ?? {};
      total += (unread[uid] as int? ?? 0);
    }
    return total;
  }

  // 채팅방 목록 실시간 스트림
  Stream<QuerySnapshot> chatListStream(String uid) {
    return _db
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots();
  }

  // 채팅방 나가기
  Future<void> leaveChat(String chatId, String myUid) async {
    final ref = _db.collection('chats').doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final users = List<String>.from(data['users'] ?? []);
    final type = data['type'] as String? ?? 'direct';
    final wasGroupChat = type == 'group' || data['name'] != null || users.length > 2;
    final userSnap = await _db.collection('users').doc(myUid).get();
    final userName = userSnap.data()?['name'] as String? ?? '모험가';
    users.remove(myUid);
    if (users.isEmpty) {
      final msgs = await ref.collection('messages').get();
      final batch = _db.batch();
      for (final m in msgs.docs) batch.delete(m.reference);
      batch.delete(ref);
      await batch.commit();
    } else {
      final batch = _db.batch();
      final updates = <String, dynamic>{
        'users': users,
        'unreadCount.$myUid': FieldValue.delete(),
        'lastReadAt.$myUid': FieldValue.delete(),
      };
      if (wasGroupChat) {
        updates['lastMessage'] = '$userName님이 나갔습니다.';
        updates['lastMessageAt'] = FieldValue.serverTimestamp();
        for (final uid in users) {
          updates['unreadCount.$uid'] = FieldValue.increment(1);
        }
        batch.set(ref.collection('messages').doc(), {
          'senderUid': myUid,
          'content': '$userName님이 나갔습니다.',
          'type': 'system',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(ref, updates);
      await batch.commit();
    }
  }

  // 채팅방 이름 변경
  Future<void> renameChat(String chatId, String newName) async {
    await _db.collection('chats').doc(chatId).update({'name': newName});
  }

  // 그룹 채팅 멤버 추가
  Future<void> addMembers(String chatId, List<String> newUids) async {
    if (newUids.isEmpty) return;
    final updates = <String, dynamic>{
      'users': FieldValue.arrayUnion(newUids),
    };
    for (final uid in newUids) {
      updates['unreadCount.$uid'] = 0;
      updates['lastReadAt.$uid'] = Timestamp.fromMillisecondsSinceEpoch(0);
    }
    await _db.collection('chats').doc(chatId).update(updates);
  }

  // 전체 미읽음 실시간 스트림
  Stream<int> unreadCountStream(String uid) {
    return _db
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final unread = (doc.data()['unreadCount'] as Map<String, dynamic>?) ?? {};
        total += (unread[uid] as int? ?? 0);
      }
      return total;
    });
  }

  // 그룹 메시지 미읽음 수신자 수
  Future<int> getGroupUnreadReceiverCount(
    String chatId,
    String myUid,
    DateTime? msgCreatedAt,
    Map<String, DateTime> lastReadAt,
    List<String> memberUids,
  ) async {
    if (msgCreatedAt == null) return 0;
    int count = 0;
    for (final uid in memberUids) {
      if (uid == myUid) continue;
      final readTime = lastReadAt[uid];
      if (readTime == null || readTime.millisecondsSinceEpoch == 0) {
        count++;
      } else if (readTime.isBefore(msgCreatedAt)) {
        count++;
      }
    }
    return count;
  }
}

// 메시지 모델
class MessageModel {
  final String id;
  final String senderUid;
  final List<String> receiverUids;
  final String content;
  // type: 'text' | 'image' | 'system' | 'deleted'
  final String type;
  final Map<String, List<String>> reactions;
  final DateTime? createdAt;
  // 5번: 수정 여부
  final bool isEdited;

  MessageModel({
    required this.id,
    required this.senderUid,
    this.receiverUids = const [],
    required this.content,
    this.type = 'text',
    required this.reactions,
    this.createdAt,
    this.isEdited = false,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      senderUid: data['senderUid'] ?? '',
      receiverUids: List<String>.from(data['receiverUids'] ?? []),
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      reactions: rawReactions.map((k, v) => MapEntry(k, List<String>.from(v))),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      isEdited: data['isEdited'] as bool? ?? false,
    );
  }

  // 시간 문자열 — 오전/오후 HH:MM 형식
  String get timeStr {
    if (createdAt == null) return '';
    final h = createdAt!.hour;
    final m = createdAt!.minute.toString().padLeft(2, '0');
    final amPm = h < 12 ? '오전' : '오후';
    final hour = h == 0 ? 12 : h > 12 ? h - 12 : h;
    return '$amPm $hour:$m';
  }
}