import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/activity_notification_service.dart';
import '../social/character_avatar.dart';
import 'user_profile_sheet.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final Map<String, dynamic>? otherCharacter;
  final bool isGroup;
  final List<String> memberUids;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.otherCharacter,
    this.isGroup = false,
    this.memberUids = const [],
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chatService = ChatService();
  final _msgCtrl = TextEditingController();
  String? _myUid;
  late String _title;
  late List<String> _memberUids;
  final Map<String, Map<String, dynamic>> _memberProfiles = {};
  final Map<String, StreamSubscription<DocumentSnapshot>> _profileSubs = {};

  Map<String, DateTime> _lastReadAt = {};
  StreamSubscription? _readSub;
  int _prevMsgCount = -1;

  // 5번: 메시지 수정 모드
  String? _editingMsgId;
  String? _editingOriginalContent;

  @override
  void initState() {
    super.initState();
    _myUid = context.read<AppProvider>().authUser!.uid;
    _title = widget.title;
    _memberUids = List<String>.from(widget.memberUids);
    _syncMemberProfiles(_memberUids);
    currentOpenChatId = widget.chatId;
    _initReadStatus();
    _subscribeReadStatus();
  }

  Future<void> _initReadStatus() async {
    final snap = await FirebaseFirestore.instance
        .collection('chats').doc(widget.chatId).get();
    final raw = snap.data()?['lastReadAt'] as Map<String, dynamic>? ?? {};
    if (mounted) {
      setState(() {
        _lastReadAt = raw.map((k, v) => MapEntry(k, (v as Timestamp).toDate()));
      });
    }
    _chatService.markAsRead(widget.chatId, _myUid!);
    _deleteChatNotifications();
  }

  Future<void> _deleteChatNotifications() async {
    if (_myUid == null) return;
    await ActivityNotificationService().deleteNotificationsByType(_myUid!, 'chat');
    if (mounted) context.read<AppProvider>().reloadUnreadNotifCount();
  }

  void _subscribeReadStatus() {
    _readSub = FirebaseFirestore.instance
        .collection('chats').doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final raw = snap.data()?['lastReadAt'] as Map<String, dynamic>? ?? {};
      final updated = raw.map((k, v) => MapEntry(k, (v as Timestamp).toDate()));
      final users = List<String>.from(snap.data()?['users'] ?? _memberUids);
      _syncMemberProfiles(users);
      bool changed = false;
      for (final k in updated.keys) {
        if (k == _myUid) continue;
        if (_lastReadAt[k] != updated[k]) { changed = true; break; }
      }
      final membersChanged = users.length != _memberUids.length ||
          users.any((uid) => !_memberUids.contains(uid));
      if (changed || membersChanged) {
        setState(() { _lastReadAt = updated; _memberUids = users; });
      }
    });
  }

  @override
  void dispose() {
    currentOpenChatId = null;
    _readSub?.cancel();
    for (final sub in _profileSubs.values) sub.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty) return;

    // 5번: 수정 모드면 메시지 수정
    if (_editingMsgId != null) {
      await _chatService.editMessage(widget.chatId, _editingMsgId!, content);
      setState(() { _editingMsgId = null; _editingOriginalContent = null; });
      _msgCtrl.clear();
      return;
    }

    final receivers = _memberUids.where((uid) => uid != _myUid).toList();
    _msgCtrl.clear();
    await _chatService.sendMessage(widget.chatId, _myUid!, receivers, content);
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200,
    );
    if (picked == null || !mounted) return;
    if (mounted) context.read<AppProvider>().showToast('사진 업로드 중...');
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance.ref(
        'chat_images/${widget.chatId}/${_myUid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(file);
      final imageUrl = await ref.getDownloadURL();
      final receivers = _memberUids.where((uid) => uid != _myUid).toList();
      await _chatService.sendMessage(
          widget.chatId, _myUid!, receivers, imageUrl, type: 'image');
    } catch (e) {
      if (mounted) context.read<AppProvider>().showToast('사진 전송에 실패했어요');
    }
  }

  // 5번: 수정 모드 시작
  void _startEdit(MessageModel msg) {
    setState(() {
      _editingMsgId = msg.id;
      _editingOriginalContent = msg.content;
      _msgCtrl.text = msg.content;
    });
  }

  // 5번: 수정 모드 취소
  void _cancelEdit() {
    setState(() { _editingMsgId = null; _editingOriginalContent = null; });
    _msgCtrl.clear();
  }

  // 2번: 1:1 읽음 여부 — hideTime 조건 제거, 모든 말풍선에 표시
  bool _isReadDirect(MessageModel msg) {
    final receivers = _memberUids.where((uid) => uid != _myUid);
    return receivers.any((uid) {
      final readTime = _lastReadAt[uid];
      if (readTime == null) return false;
      if (readTime.millisecondsSinceEpoch == 0) return false;
      if (msg.createdAt == null) return true;
      return readTime.isAfter(msg.createdAt!.subtract(const Duration(seconds: 1)));
    });
  }

  // 2번: 그룹 미읽음 수 — hideTime 조건 제거, 모든 말풍선에 표시
  int _groupUnreadCount(MessageModel msg) {
    if (msg.createdAt == null) return 0;
    final receivers = msg.receiverUids.isNotEmpty
        ? msg.receiverUids
        : _memberUids.where((uid) => uid != msg.senderUid).toList();
    int count = 0;
    for (final uid in receivers) {
      final readTime = _lastReadAt[uid];
      if (readTime == null || readTime.millisecondsSinceEpoch == 0) {
        count++;
      } else if (readTime.isBefore(msg.createdAt!)) {
        count++;
      }
    }
    return count;
  }

  void _syncMemberProfiles(List<String> memberUids) {
    for (final uid in memberUids) {
      if (_profileSubs.containsKey(uid)) continue;
      _profileSubs[uid] = FirebaseFirestore.instance
          .collection('users').doc(uid)
          .snapshots()
          .listen((snap) {
        if (!mounted || !snap.exists) return;
        final data = snap.data() ?? {};
        setState(() => _memberProfiles[uid] = {'uid': uid, ...data});
      });
    }
  }

  Map<String, dynamic>? _profileOf(String uid) => _memberProfiles[uid];
  String _displayNameOf(String uid) => _profileOf(uid)?['name'] as String? ?? '모험가';
  String? _profileImageOf(String uid) => _profileOf(uid)?['profileImageUrl'] as String?;
  Map<String, dynamic>? _characterOf(String uid) {
    final raw = _profileOf(uid)?['character'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  void _openUserProfile(String uid) {
    if (uid.isEmpty || uid == _myUid) return;
    showUserProfileSheet(context, uid);
  }

  @override
  Widget build(BuildContext context) {
    final otherUid = _memberUids.firstWhere((uid) => uid != _myUid, orElse: () => '');
    return Scaffold(
      backgroundColor: context.bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(color: context.surfaceColor,
                border: Border(bottom: BorderSide(color: context.borderColor, width: 0.5))),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_ios, size: 18, color: context.textSecondary)),
              const SizedBox(width: 12),
              if (widget.isGroup)
                Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: context.subtleBg, shape: BoxShape.circle),
                    child: const Center(child: Text('👥', style: TextStyle(fontSize: 18))))
              else
                GestureDetector(onTap: () => _openUserProfile(otherUid),
                    child: CharacterAvatar(
                      character: otherUid.isNotEmpty ? _characterOf(otherUid) : widget.otherCharacter,
                      size: 36, profileImageUrl: otherUid.isNotEmpty ? _profileImageOf(otherUid) : null,
                    )),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                if (widget.isGroup)
                  Text('${_memberUids.length}명', style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ])),
              GestureDetector(onTap: () => _showSettings(context), behavior: HitTestBehavior.opaque,
                  child: Padding(padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.more_vert_rounded, size: 22, color: context.textSecondary))),
            ]),
          ),

          // 메시지 목록
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.messagesStream(widget.chatId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return Center(child: CircularProgressIndicator(color: context.primaryColor));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.length != _prevMsgCount) {
                  _prevMsgCount = docs.length;
                  if (docs.isNotEmpty) {
                    _chatService.markAsRead(widget.chatId, _myUid!);
                    _deleteChatNotifications();
                  }
                }
                if (docs.isEmpty) return const _EmptyChat();
                final messages = docs.map((d) => MessageModel.fromDoc(d)).toList();

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final idx = messages.length - 1 - i;
                    final msg = messages[idx];
                    final isMe = msg.senderUid == _myUid;
                    final showDate = idx == 0 || !_isSameDay(messages[idx - 1].createdAt, msg.createdAt);
                    final isContinued = idx > 0 && !showDate &&
                        messages[idx - 1].senderUid == msg.senderUid &&
                        messages[idx - 1].type != 'system' && msg.type != 'system';
                    final nextIdx = idx + 1;
                    final hasNext = nextIdx < messages.length;
                    final nextMsg = hasNext ? messages[nextIdx] : null;
                    // 시간 숨김 — 연속 메시지 중 마지막만 시간 표시 (읽음 표시에는 영향 없음)
                    final hideTime = hasNext &&
                        nextMsg!.senderUid == msg.senderUid &&
                        nextMsg.type != 'system' && msg.type != 'system' &&
                        nextMsg.timeStr == msg.timeStr;
                    // 하단 간격 — 다음 메시지가 같은 사람 연속이면 좁게, 아니면 넓게
                    final isNextContinued = hasNext &&
                        nextMsg!.senderUid == msg.senderUid &&
                        nextMsg.type != 'system' && msg.type != 'system';

                    // 2번: hideTime과 무관하게 모든 말풍선에 읽음 표시
                    final isRead = isMe && !widget.isGroup ? _isReadDirect(msg) : false;
                    final groupUnread = isMe && widget.isGroup ? _groupUnreadCount(msg) : 0;

                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (showDate && msg.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(children: [
                            Expanded(child: Divider(color: context.borderColor)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(_dateLabel(msg.createdAt!),
                                    style: TextStyle(fontSize: 11, color: context.textSecondary))),
                            Expanded(child: Divider(color: context.borderColor)),
                          ]),
                        ),
                      _MessageBubble(
                        message: msg, isMe: isMe,
                        isRead: isRead,
                        groupUnreadCount: groupUnread,
                        isGroup: widget.isGroup, myUid: _myUid!,
                        hideTime: hideTime, senderName: _displayNameOf(msg.senderUid),
                        senderCharacter: _characterOf(msg.senderUid),
                        senderProfileImageUrl: _profileImageOf(msg.senderUid),
                        onProfileTap: () => _openUserProfile(msg.senderUid),
                        isContinued: isContinued,
                        isNextContinued: isNextContinued,
                        chatId: widget.chatId,
                        chatService: _chatService,
                        // 5번: 꾹 누르면 바텀시트 표시
                        onLongPress: () => _showMessageActions(context, msg, isMe),
                      ),
                    ]);
                  },
                );
              },
            ),
          ),

          // 5번: 수정 모드 표시 배너
          if (_editingMsgId != null)
            Container(
              color: context.primaryColor.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 14, color: context.primaryColor),
                const SizedBox(width: 6),
                Expanded(child: Text('메시지 수정 중',
                    style: TextStyle(fontSize: 12, color: context.primaryColor))),
                GestureDetector(onTap: _cancelEdit,
                    child: Icon(Icons.close, size: 16, color: context.textSecondary)),
              ]),
            ),

          _ChatInputBar(
            controller: _msgCtrl, onSend: _send, onSendImage: _sendImage,
            isEditing: _editingMsgId != null,
          ),
        ]),
      ),
    );
  }

  // 5번: 메시지 꾹 누르면 바텀시트 — 반응/수정/삭제
  void _showMessageActions(BuildContext context, MessageModel msg, bool isMe) {
    if (msg.type == 'system' || msg.type == 'deleted') return;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.modalBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: context.borderColor,
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 16),
            // 5번: 반응 추가 — 자신 메시지에도 가능
            Text('반응 추가', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: context.textPrimary)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: kReactionEmojis.map((emoji) {
                final reacted = (msg.reactions[emoji] ?? []).contains(_myUid);
                return GestureDetector(
                  onTap: () {
                    _chatService.toggleReaction(widget.chatId, msg.id, _myUid!, emoji);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: reacted ? context.primaryColor.withOpacity(0.12) : context.subtleBg,
                      shape: BoxShape.circle,
                      border: reacted ? Border.all(color: context.primaryColor.withOpacity(0.4)) : null,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
            // 내 메시지면 수정/삭제 옵션 표시
            if (isMe && msg.type != 'image') ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: context.textPrimary),
                title: Text('메시지 수정', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(ctx); _startEdit(msg); },
              ),
            ],
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: const Text('메시지 삭제', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(ctx);
                  // 삭제 확인 다이얼로그
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: context.modalBg,
                      title: Text('메시지 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      content: Text('이 메시지를 삭제하시겠어요?\n삭제된 메시지는 복구할 수 없어요.', style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.5)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('취소', style: TextStyle(color: context.textSecondary))),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: AppTheme.danger))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _chatService.deleteMessage(widget.chatId, msg.id, senderName: _displayNameOf(_myUid!));
                  }
                },
              ),
            ],
          ]),
        );
      },
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: context.modalBg, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(0, 16, 0, bottomPad + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 16),
            if (widget.isGroup) ...[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: context.textPrimary),
                title: Text('채팅방 이름 변경', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(ctx); _showRenameDialog(context); },
              ),
              ListTile(
                leading: Icon(Icons.people_outline_rounded, color: context.textPrimary),
                title: Text('참여자 보기', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(ctx); _showParticipants(context); },
              ),
              ListTile(
                leading: Icon(Icons.person_add_outlined, color: context.textPrimary),
                title: Text('멤버 추가', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(ctx); _showAddMemberDialog(context); },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded, color: AppTheme.danger),
              title: const Text('채팅방 나가기', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _confirmLeave(context); },
            ),
          ]),
        );
      },
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: _title);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.modalBg,
        title: Text('채팅방 이름 변경', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
        content: TextField(controller: ctrl, autofocus: true,
          style: TextStyle(fontSize: 14, color: context.textPrimary),
          decoration: InputDecoration(hintText: '채팅방 이름을 입력하세요',
              hintStyle: TextStyle(color: context.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.primaryColor)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('취소', style: TextStyle(color: context.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text('변경', style: TextStyle(color: context.primaryColor))),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty && newName != _title) {
      await _chatService.renameChat(widget.chatId, newName);
      if (mounted) setState(() => _title = newName);
    }
  }

  Future<void> _showParticipants(BuildContext context) async {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        final members = List<String>.from(_memberUids);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('참여자 ${members.length}명', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Text('×', style: TextStyle(fontSize: 24, color: ctx.textSecondary))),
            ]),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
              child: ListView.separated(shrinkWrap: true, itemCount: members.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: ctx.borderColor),
                itemBuilder: (_, i) {
                  final uid = members[i];
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      CharacterAvatar(character: _characterOf(uid), size: 38, profileImageUrl: _profileImageOf(uid)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_displayNameOf(uid), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ctx.textPrimary))),
                      if (uid == _myUid) Text('나', style: TextStyle(fontSize: 12, color: ctx.textSecondary)),
                    ]));
                }),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final app = context.read<AppProvider>();
    final currentMembers = List<String>.from(_memberUids);
    final friendships = await FirebaseFirestore.instance
        .collection('friendships').where('users', arrayContains: _myUid)
        .where('status', isEqualTo: 'accepted').get();
    final friendUids = friendships.docs.map((d) {
      final users = List<String>.from(d['users']);
      return users.firstWhere((u) => u != _myUid, orElse: () => '');
    }).where((uid) => uid.isNotEmpty && !currentMembers.contains(uid)).toList();
    if (friendUids.isEmpty) {
      if (mounted) app.showToast('추가할 수 있는 친구가 없어요');
      return;
    }
    final friendDocs = await Future.wait(friendUids.map((uid) =>
        FirebaseFirestore.instance.collection('users').doc(uid).get()));
    final friends = friendDocs.where((d) => d.exists).map((d) => {'uid': d.id, ...d.data()!}).toList();
    if (!mounted) return;
    final selected = <String>{};
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('멤버 추가 (${selected.length}명 선택)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Text('×', style: TextStyle(fontSize: 24, color: ctx.textSecondary))),
            ]),
            const SizedBox(height: 12),
            ...friends.map((f) {
              final uid = f['uid'] as String;
              final isSelected = selected.contains(uid);
              return GestureDetector(
                onTap: () => setModal(() { if (isSelected) selected.remove(uid); else selected.add(uid); }),
                child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isSelected ? ctx.primaryColor.withOpacity(0.08) : ctx.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? ctx.primaryColor : ctx.borderColor, width: isSelected ? 1.5 : 0.5)),
                  child: Row(children: [
                    Expanded(child: Text(f['name'] as String? ?? '모험가', style: TextStyle(fontSize: 14, color: ctx.textPrimary))),
                    if (isSelected) Icon(Icons.check_circle, size: 18, color: ctx.primaryColor),
                  ])),
              );
            }),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: selected.isEmpty ? null : () async {
                await _chatService.addMembers(widget.chatId, selected.toList());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) app.showToast('${selected.length}명을 추가했어요');
              },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: selected.isEmpty ? ctx.borderColor : ctx.primaryColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('추가하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: selected.isEmpty ? ctx.textSecondary : ctx.onPrimary)))),
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: context.modalBg,
      title: Text('채팅방 나가기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
      content: Text('"$_title" 채팅방에서 나가시겠어요?', style: TextStyle(fontSize: 13, color: context.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('취소', style: TextStyle(color: context.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('나가기', style: TextStyle(color: AppTheme.danger))),
      ],
    ));
    if (confirm == true) {
      await _chatService.leaveChat(widget.chatId, _myUid!);
      if (mounted) { context.read<AppProvider>().showToast('채팅방에서 나갔어요'); Navigator.pop(context); }
    }
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('💬', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text('대화를 시작해보세요!', style: TextStyle(fontSize: 14, color: context.textSecondary)),
    ]));
  }
}

class _ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final Future<void> Function() onSendImage;
  // 5번: 수정 모드 여부 — true면 이미지 버튼 숨김
  final bool isEditing;
  const _ChatInputBar({required this.controller, required this.onSend,
      required this.onSendImage, this.isEditing = false});
  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _sending = false;
  bool _uploadingImage = false;

  @override
  void initState() { super.initState(); widget.controller.addListener(_onTextChanged); }
  @override
  void dispose() { widget.controller.removeListener(_onTextChanged); super.dispose(); }
  void _onTextChanged() => setState(() {});

  Future<void> _handleSend() async {
    if (widget.controller.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try { await widget.onSend(); } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _handleSendImage() async {
    if (_uploadingImage) return;
    setState(() => _uploadingImage = true);
    try { await widget.onSendImage(); } finally { if (mounted) setState(() => _uploadingImage = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.controller.text.trim().isEmpty;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(color: context.surfaceColor,
          border: Border(top: BorderSide(color: context.borderColor, width: 0.5))),
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPad + 10),
      child: Row(children: [
        // 5번: 수정 모드가 아닐 때만 이미지 버튼 표시
        if (!widget.isEditing)
          GestureDetector(
            onTap: _uploadingImage ? null : _handleSendImage,
            child: Container(width: 38, height: 38,
              decoration: BoxDecoration(color: context.subtleBg, shape: BoxShape.circle,
                  border: Border.all(color: context.borderColor)),
              child: _uploadingImage
                  ? Padding(padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.primaryColor))
                  : Icon(Icons.image_outlined, size: 18, color: context.textSecondary)),
          ),
        if (!widget.isEditing) const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.isEditing ? context.primaryColor : context.borderColor)),
            child: TextField(controller: widget.controller,
              maxLines: 4, minLines: 1, maxLength: 500,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: widget.isEditing ? '수정할 내용을 입력하세요...' : '메시지를 입력하세요...',
                hintStyle: TextStyle(fontSize: 14, color: context.textSecondary),
                border: InputBorder.none, counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onSubmitted: (_) => _handleSend()),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isEmpty ? null : _handleSend,
          child: AnimatedContainer(duration: const Duration(milliseconds: 150),
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: isEmpty ? context.borderColor : context.primaryColor),
            child: _sending
                ? Padding(padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.onPrimary))
                : Icon(widget.isEditing ? Icons.check_rounded : Icons.send_rounded,
                    size: 18, color: isEmpty ? context.textSecondary : context.onPrimary)),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe, isGroup, isContinued, isNextContinued, isRead;
  final bool hideTime;
  final int groupUnreadCount;
  final String myUid, chatId;
  final String senderName;
  final Map<String, dynamic>? senderCharacter;
  final String? senderProfileImageUrl;
  final VoidCallback? onProfileTap;
  final ChatService chatService;
  // 5번: 꾹 누르기 콜백
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message, required this.isMe, required this.isGroup,
    required this.myUid, required this.isContinued, required this.isNextContinued,
    required this.isRead,
    required this.hideTime, required this.groupUnreadCount,
    required this.chatId, required this.senderName,
    this.senderCharacter, this.senderProfileImageUrl,
    this.onProfileTap, required this.chatService,
    this.onLongPress,
  });

  bool get _isImage => message.type == 'image';
  // 5번: 삭제된 메시지 여부
  bool get _isDeleted => message.type == 'deleted';

  void _openFullscreen(BuildContext context, String url) {
    showDialog(context: context, barrierColor: Colors.black87,
      builder: (_) => GestureDetector(onTap: () => Navigator.pop(context),
        child: Stack(children: [
          Center(child: InteractiveViewer(child: Image.network(url))),
          Positioned(top: 48, right: 16,
            child: GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 36, height: 36,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18)))),
        ])));
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 메시지 — 중앙 표시
    if (message.type == 'system' || _isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: context.subtleBg,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: context.borderColor, width: 0.5)),
            // 5번: 삭제된 메시지는 이탤릭 표시
            child: Text(message.content,
                style: TextStyle(fontSize: 12, color: context.textSecondary,
                    fontStyle: FontStyle.normal)),
          ),
        ),
      );
    }

    final reactionSummary = message.reactions.entries.where((e) => e.value.isNotEmpty).toList();

    Widget messageContent(Color bubbleColor, bool isMyBubble) {
      if (_isImage) {
        return GestureDetector(
          onTap: () => _openFullscreen(context, message.content),
          onLongPress: onLongPress,
          child: ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.network(message.content, width: 180, height: 180, fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null ? child
                  : Container(width: 180, height: 180, color: context.subtleBg,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (_, __, ___) => Container(width: 180, height: 60, color: context.subtleBg,
                  child: Center(child: Text('이미지를 불러올 수 없어요',
                      style: TextStyle(fontSize: 12, color: context.textSecondary)))))),
        );
      }
      return GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMyBubble ? 16 : 4),
              bottomRight: Radius.circular(isMyBubble ? 4 : 16)),
            border: isMyBubble ? null : Border.all(color: context.borderColor, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message.content, style: TextStyle(fontSize: 14, height: 1.4,
                color: isMyBubble ? context.onPrimary : context.textPrimary)),
            // 5번: 수정됨 표시
            if (message.isEdited) ...[
              const SizedBox(height: 2),
              Text('수정됨', style: TextStyle(fontSize: 10,
                  color: isMyBubble ? context.onPrimary.withOpacity(0.6) : context.textSecondary)),
            ],
          ]),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: reactionSummary.isNotEmpty ? 4 : isNextContinued ? 2 : 7),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isMe)
            Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
              // 2번: hideTime 조건 제거 — 모든 말풍선에 읽음 표시
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (isGroup && groupUnreadCount > 0)
                  Text('$groupUnreadCount', style: TextStyle(fontSize: 10, color: context.primaryColor, fontWeight: FontWeight.w600))
                else if (!isGroup && !isRead)
                  Text('1', style: TextStyle(fontSize: 10, color: context.primaryColor, fontWeight: FontWeight.w600)),
                if (!hideTime)
                  Text(message.timeStr, style: TextStyle(fontSize: 10, color: context.textSecondary)),
              ]),
              const SizedBox(width: 4),
              messageContent(context.primaryColor, true),
            ])
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isContinued) const SizedBox(width: 42)
              else ...[
                GestureDetector(onTap: onProfileTap,
                    child: CharacterAvatar(character: senderCharacter, size: 34, profileImageUrl: senderProfileImageUrl)),
                const SizedBox(width: 8),
              ],
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isContinued) ...[
                  GestureDetector(onTap: onProfileTap,
                      child: Text(senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary))),
                  const SizedBox(height: 2),
                ],
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  messageContent(context.surfaceColor, false),
                  const SizedBox(width: 4),
                  if (!hideTime) Text(message.timeStr, style: TextStyle(fontSize: 10, color: context.textSecondary)),
                ]),
              ]),
            ]),
          // 이모지 반응 요약
          if (reactionSummary.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 42, right: isMe ? 4 : 0),
              child: Wrap(spacing: 4, children: reactionSummary.map((e) {
                final isMine = e.value.contains(myUid);
                return GestureDetector(
                  // 5번: 자신의 메시지 반응도 토글 가능
                  onTap: () => chatService.toggleReaction(chatId, message.id, myUid, e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isMine ? context.primaryColor.withOpacity(0.15) : context.subtleBg,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: isMine ? context.primaryColor.withOpacity(0.4) : context.borderColor)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(e.key, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 3),
                      Text('${e.value.length}', style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                );
              }).toList()),
            ),
        ],
      ),
    );
  }
}