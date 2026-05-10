import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../social/character_avatar.dart';

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

  // lastReadAt — 상대방 변경만 감지 (내 uid 변경은 무시 → 루프 방지)
  Map<String, DateTime> _lastReadAt = {};
  StreamSubscription? _readSub;
  int _prevMsgCount = -1;

  @override
  void initState() {
    super.initState();
    _myUid = context.read<AppProvider>().authUser!.uid;
    _title = widget.title;
    currentOpenChatId = widget.chatId;
    _initReadStatus(); // markAsRead 전에 lastReadAt 선로드
    _subscribeReadStatus();
  }

  Future<void> _initReadStatus() async {
    // lastReadAt 초기값 선로드 — 1 깜빡임 방지
    final snap = await FirebaseFirestore.instance
        .collection('chats').doc(widget.chatId).get();
    final raw = snap.data()?['lastReadAt'] as Map<String, dynamic>? ?? {};
    if (mounted) {
      setState(() {
        _lastReadAt = raw.map((k, v) => MapEntry(k, (v as Timestamp).toDate()));
      });
    }
    // 선로드 완료 후 읽음 처리
    _chatService.markAsRead(widget.chatId, _myUid!);
  }

  void _subscribeReadStatus() {
    _readSub = FirebaseFirestore.instance
        .collection('chats').doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final raw = snap.data()?['lastReadAt'] as Map<String, dynamic>? ?? {};
      final updated = raw.map((k, v) => MapEntry(k, (v as Timestamp).toDate()));
      // 상대방 lastReadAt만 비교 — 내 uid 변경(markAsRead)은 무시해서 루프 방지
      bool changed = false;
      for (final k in updated.keys) {
        if (k == _myUid) continue; // 내 변경 무시
        if (_lastReadAt[k] != updated[k]) { changed = true; break; }
      }
      if (changed) setState(() => _lastReadAt = updated);
    });
  }

  @override
  void dispose() {
    // 채팅방 나갈 때 등록 해제
    currentOpenChatId = null;
    _readSub?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty) return;
    final receivers = widget.memberUids.where((uid) => uid != _myUid).toList();
    _msgCtrl.clear();
    await _chatService.sendMessage(widget.chatId, _myUid!, receivers, content);
  }

  // 내 메시지를 상대방이 읽었는지 확인
  // 상대방의 lastReadAt이 Epoch(0)보다 크면 한 번 이상 읽은 것 → 쭉 읽음 유지
  bool _isRead(MessageModel msg) {
    final receivers = widget.memberUids.where((uid) => uid != _myUid);
    return receivers.any((uid) {
      final readTime = _lastReadAt[uid];
      if (readTime == null) return false;
      // Epoch(0) = 아직 한 번도 읽지 않음
      if (readTime.millisecondsSinceEpoch == 0) return false;
      // 한 번이라도 읽었으면 이후 모든 메시지도 읽음으로 표시
      if (msg.createdAt == null) return true;
      return readTime.isAfter(
          msg.createdAt!.subtract(const Duration(seconds: 1)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(bottom: BorderSide(color: context.borderColor, width: 0.5)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back_ios, size: 18, color: context.textSecondary),
              ),
              const SizedBox(width: 12),
              if (widget.isGroup)
                Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: context.subtleBg, shape: BoxShape.circle),
                    child: const Center(child: Text('👥', style: TextStyle(fontSize: 18))))
              else
                CharacterAvatar(character: widget.otherCharacter, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_title, style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w600, color: context.textPrimary)),
                if (widget.isGroup)
                  Text('${widget.memberUids.length}명',
                      style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ])),
              // 설정 버튼
              GestureDetector(
                onTap: () => _showSettings(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.more_vert_rounded, size: 22, color: context.textSecondary),
                ),
              ),
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

                // 새 메시지 수신 시에만 읽음 처리
                if (docs.length != _prevMsgCount) {
                  _prevMsgCount = docs.length;
                  if (docs.isNotEmpty) {
                    _chatService.markAsRead(widget.chatId, _myUid!);
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
                    final showDate = idx == 0 || !_isSameDay(
                        messages[idx - 1].createdAt, msg.createdAt);
                    final isContinued = idx > 0
                        && messages[idx - 1].senderUid == msg.senderUid
                        && msg.createdAt != null
                        && messages[idx - 1].createdAt != null
                        && msg.createdAt!.difference(
                            messages[idx - 1].createdAt!).inMinutes < 1;
                    final isRead = isMe ? _isRead(msg) : false;

                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (showDate && msg.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(children: [
                            Expanded(child: Divider(color: context.borderColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(_dateLabel(msg.createdAt!),
                                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
                            ),
                            Expanded(child: Divider(color: context.borderColor)),
                          ]),
                        ),
                      _MessageBubble(
                        message: msg, isMe: isMe, isRead: isRead,
                        isGroup: widget.isGroup, myUid: _myUid!,
                        isContinued: isContinued, chatId: widget.chatId,
                        chatService: _chatService,
                      ),
                    ]);
                  },
                );
              },
            ),
          ),

          // 입력창
          _ChatInputBar(controller: _msgCtrl, onSend: _send),
        ]),
      ),
    );
  }

  // 설정 바텀시트
  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.modalBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(0, 16, 0, bottomPad + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: context.borderColor,
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 16),
            // 이름 변경 (1:1, 그룹 모두)
            ListTile(
              leading: Icon(Icons.edit_outlined, color: context.textPrimary),
              title: Text('채팅방 이름 변경',
                  style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _showRenameDialog(context); },
            ),
            // 멤버 추가 (그룹만)
            if (widget.isGroup)
              ListTile(
                leading: Icon(Icons.person_add_outlined, color: context.textPrimary),
                title: Text('멤버 추가',
                    style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500)),
                onTap: () { Navigator.pop(ctx); _showAddMemberDialog(context); },
              ),
            // 나가기
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded, color: AppTheme.danger),
              title: const Text('채팅방 나가기',
                  style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w500)),
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
        title: Text('채팅방 이름 변경', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w600, color: context.textPrimary)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(fontSize: 14, color: context.textPrimary),
          decoration: InputDecoration(
            hintText: '채팅방 이름을 입력하세요',
            hintStyle: TextStyle(color: context.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.primaryColor)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: context.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text('변경', style: TextStyle(color: context.primaryColor))),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty && newName != _title) {
      await _chatService.renameChat(widget.chatId, newName);
      if (mounted) setState(() => _title = newName);
    }
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final app = context.read<AppProvider>();
    final chatSnap = await FirebaseFirestore.instance
        .collection('chats').doc(widget.chatId).get();
    final currentMembers = List<String>.from(chatSnap.data()?['users'] ?? widget.memberUids);
    final friendships = await FirebaseFirestore.instance
        .collection('friendships')
        .where('users', arrayContains: _myUid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final friendUids = friendships.docs.map((d) {
      final users = List<String>.from(d['users']);
      return users.firstWhere((u) => u != _myUid, orElse: () => '');
    }).where((uid) => uid.isNotEmpty && !currentMembers.contains(uid)).toList();
    if (friendUids.isEmpty) {
      if (mounted) app.showToast('추가할 수 있는 친구가 없어요');
      return;
    }
    final friendDocs = await Future.wait(
        friendUids.map((uid) => FirebaseFirestore.instance.collection('users').doc(uid).get()));
    final friends = friendDocs.where((d) => d.exists).map((d) => {'uid': d.id, ...d.data()!}).toList();
    if (!mounted) return;
    final selected = <String>{};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final bottomPad = MediaQuery.of(ctx).padding.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('멤버 추가 (${selected.length}명 선택)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
                GestureDetector(onTap: () => Navigator.pop(ctx),
                    child: Text('×', style: TextStyle(fontSize: 24, color: ctx.textSecondary))),
              ]),
              const SizedBox(height: 12),
              ...friends.map((f) {
                final uid = f['uid'] as String;
                final isSelected = selected.contains(uid);
                return GestureDetector(
                  onTap: () => setModal(() {
                    if (isSelected) selected.remove(uid); else selected.add(uid);
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? ctx.primaryColor.withOpacity(0.08) : ctx.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? ctx.primaryColor : ctx.borderColor,
                          width: isSelected ? 1.5 : 0.5),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(f['name'] as String? ?? '모험가',
                          style: TextStyle(fontSize: 14, color: ctx.textPrimary))),
                      if (isSelected) Icon(Icons.check_circle, size: 18, color: ctx.primaryColor),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: selected.isEmpty ? null : () async {
                  await _chatService.addMembers(widget.chatId, selected.toList());
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) app.showToast('${selected.length}명을 추가했어요');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected.isEmpty ? ctx.borderColor : ctx.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('추가하기',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: selected.isEmpty ? ctx.textSecondary
                              : (ctx.isDark ? Colors.black : Colors.white)))),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.modalBg,
        title: Text('채팅방 나가기', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w600, color: context.textPrimary)),
        content: Text('"$_title" 채팅방에서 나가시겠어요?',
            style: TextStyle(fontSize: 13, color: context.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: TextStyle(color: context.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('나가기', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirm == true) {
      await _chatService.leaveChat(widget.chatId, _myUid!);
      if (mounted) {
        context.read<AppProvider>().showToast('채팅방에서 나갔어요');
        Navigator.pop(context);
      }
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
      Text('대화를 시작해보세요!',
          style: TextStyle(fontSize: 14, color: context.textSecondary)),
    ]));
  }
}

class _ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;
  const _ChatInputBar({required this.controller, required this.onSend});
  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _handleSend() async {
    if (widget.controller.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.controller.text.trim().isEmpty;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 10),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: context.subtleBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.borderColor),
            ),
            child: TextField(
              controller: widget.controller,
              maxLines: 4, minLines: 1, maxLength: 500,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle: TextStyle(fontSize: 14, color: context.textSecondary),
                border: InputBorder.none, counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isEmpty ? null : _handleSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEmpty ? context.borderColor : context.primaryColor,
            ),
            child: _sending
                ? Padding(padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: context.isDark ? Colors.black : Colors.white))
                : Icon(Icons.send_rounded, size: 18,
                    color: isEmpty ? context.textSecondary
                        : (context.isDark ? Colors.black : Colors.white)),
          ),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe, isGroup, isContinued, isRead;
  final String myUid, chatId;
  final ChatService chatService;

  const _MessageBubble({
    required this.message, required this.isMe, required this.isGroup,
    required this.myUid, required this.isContinued, required this.isRead,
    required this.chatId, required this.chatService,
  });

void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.modalBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom;
        return Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('반응 추가', style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: kReactionEmojis.map((emoji) {
              final reacted = (message.reactions[emoji] ?? []).contains(myUid);
              return GestureDetector(
                onTap: () {
                  chatService.toggleReaction(chatId, message.id, myUid, emoji);
                  Navigator.pop(context);
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
        ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reactionSummary = message.reactions.entries
        .where((e) => e.value.isNotEmpty).toList();

    final reactionBtn = isMe ? const SizedBox.shrink() : GestureDetector(
      onTap: () => _showReactionPicker(context),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: context.subtleBg, shape: BoxShape.circle,
          border: Border.all(color: context.borderColor),
        ),
        child: Icon(Icons.add_reaction_outlined, size: 14, color: context.textSecondary),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: reactionSummary.isNotEmpty ? 2 : 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isMe) ...[
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (!isRead)
                    Text('1', style: TextStyle(fontSize: 10,
                        color: context.primaryColor, fontWeight: FontWeight.w600)),
                  Text(message.timeStr,
                      style: TextStyle(fontSize: 10, color: context.textSecondary)),
                ]),
                const SizedBox(width: 4),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16), topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(message.content, style: TextStyle(fontSize: 14,
                      height: 1.4, color: context.isDark ? Colors.black : Colors.white)),
                ),
              ] else ...[
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4), topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: context.borderColor, width: 0.5),
                  ),
                  child: Text(message.content, style: TextStyle(fontSize: 14,
                      height: 1.4, color: context.textPrimary)),
                ),
                const SizedBox(width: 4),
                Text(message.timeStr,
                    style: TextStyle(fontSize: 10, color: context.textSecondary)),
                const SizedBox(width: 6),
                reactionBtn,
              ],
            ],
          ),
          if (reactionSummary.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
              child: Wrap(spacing: 4,
                children: reactionSummary.map((e) {
                  final isMine = e.value.contains(myUid);
                  return GestureDetector(
                    onTap: isMe ? null : () =>
                        chatService.toggleReaction(chatId, message.id, myUid, e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isMine ? context.primaryColor.withOpacity(0.15) : context.subtleBg,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: isMine
                            ? context.primaryColor.withOpacity(0.4) : context.borderColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(e.key, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 3),
                        Text('${e.value.length}', style: TextStyle(fontSize: 11,
                            color: context.textSecondary, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}