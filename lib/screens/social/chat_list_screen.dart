import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/chat_service.dart';
import 'chat_room_screen.dart';
import 'character_avatar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // 'all' | 'direct' | 'group'
  String _filter = 'all';

  // 채팅방 나가기 확인
  Future<void> _confirmLeave(BuildContext context, String chatId, String title, String myUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.modalBg,
        title: Text('채팅방 나가기', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w600, color: context.textPrimary)),
        content: Text('"$title" 채팅방에서 나가시겠어요?',
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
      await ChatService().leaveChat(chatId, myUid);
      if (context.mounted) context.read<AppProvider>().showToast('채팅방에서 나갔어요');
    }
  }

  // 꾹 눌렀을 때 바텀시트 메뉴
  // 이름 변경 다이얼로그
  Future<void> _showRenameDialog(BuildContext context, String chatId, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.modalBg,
        title: Text('채팅방 이름 변경', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w600, color: context.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: context.textPrimary),
          decoration: InputDecoration(
            hintText: '채팅방 이름을 입력하세요',
            hintStyle: TextStyle(color: context.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.primaryColor)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: context.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('변경', style: TextStyle(color: context.primaryColor)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty && newName != currentTitle) {
      await ChatService().renameChat(chatId, newName);
      if (context.mounted) context.read<AppProvider>().showToast('채팅방 이름을 변경했어요');
    }
  }

  void _showMenu(BuildContext context, String chatId, String title, String myUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        return Padding(
        padding: EdgeInsets.fromLTRB(0, 16, 0, bottomPad + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: ctx.borderColor,
                  borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 16),
          // 이름 변경 버튼
          ListTile(
            leading: Icon(Icons.edit_outlined, color: ctx.textPrimary),
            title: Text('채팅방 이름 변경',
                style: TextStyle(color: ctx.textPrimary, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(context, chatId, title);
            },
          ),
          // 나가기 버튼
          ListTile(
            leading: const Icon(Icons.exit_to_app_rounded, color: AppTheme.danger),
            title: const Text('채팅방 나가기',
                style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmLeave(context, chatId, title, myUid);
            },
          ),
        ]),
      );},
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AppProvider>().authUser!.uid;
    final chatService = ChatService();

    return Column(children: [
      // 1:1 / 그룹 필터 버튼
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(children: [
          _FilterBtn(label: '전체', value: 'all', current: _filter,
              onTap: () => setState(() => _filter = 'all')),
          const SizedBox(width: 8),
          _FilterBtn(label: '1:1', value: 'direct', current: _filter,
              onTap: () => setState(() => _filter = 'direct')),
          const SizedBox(width: 8),
          _FilterBtn(label: '그룹', value: 'group', current: _filter,
              onTap: () => setState(() => _filter = 'group')),
        ]),
      ),

      // 채팅방 목록
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: chatService.chatListStream(myUid),
          builder: (context, snap) {
            // 로딩 중에도 기존 데이터 있으면 유지 (깜빡임 방지)
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return Center(child: CircularProgressIndicator(color: context.primaryColor));
            }
            final docs = snap.data?.docs ?? [];

            // lastMessageAt 기준 클라이언트 정렬 (내림차순)
            final sorted = List.of(docs)..sort((a, b) {
              final aTs = (a.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?;
              final bTs = (b.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return bTs.compareTo(aTs);
            });

            // 필터 적용
            final filtered = sorted.where((doc) {
              final type = (doc.data() as Map<String, dynamic>)['type'] as String? ?? 'direct';
              if (_filter == 'direct') return type == 'direct';
              if (_filter == 'group') return type == 'group';
              return true;
            }).toList();

            if (filtered.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('💬', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  _filter == 'group' ? '그룹 채팅이 없어요\n친구 탭에서 그룹 채팅을 만들어보세요'
                      : _filter == 'direct' ? '1:1 채팅이 없어요\n친구 탭에서 채팅을 시작해보세요'
                      : '채팅이 없어요\n친구와 대화를 시작해보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.6),
                ),
              ]));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final doc = filtered[i];
                final data = doc.data() as Map<String, dynamic>;
                final chatId = doc.id;
                final type = data['type'] as String? ?? 'direct';
                final isGroup = type == 'group';
                final users = List<String>.from(data['users'] ?? []);
                final lastMsg = data['lastMessage'] as String? ?? '';
                final lastMsgAt = data['lastMessageAt'] as Timestamp?;
                final unreadMap = (data['unreadCount'] as Map<String, dynamic>?) ?? {};
                final unread = unreadMap[myUid] as int? ?? 0;

                // 1:1 채팅 — 상대방 정보 로드
                if (!isGroup) {
                  final otherUid = users.firstWhere((u) => u != myUid, orElse: () => '');
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                    builder: (_, userSnap) {
                      final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                      // name 필드 사용
                      final name = userData['name'] as String? ?? '모험가';
                      final character = userData['character'] as Map<String, dynamic>?;
                      return GestureDetector(
                        onLongPress: () => _showMenu(context, chatId, name, myUid),
                        child: _ChatTile(
                          title: name,
                          lastMsg: lastMsg,
                          lastMsgAt: lastMsgAt,
                          unread: unread,
                          isGroup: false,
                          otherCharacter: character,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              chatId: chatId,
                              title: name,
                              otherCharacter: character,
                              memberUids: users,
                            ),
                          )),
                        ),
                      );
                    },
                  );
                }

                // 그룹 채팅
                final groupName = data['name'] as String? ?? '그룹 채팅';
                return GestureDetector(
                  onLongPress: () => _showMenu(context, chatId, groupName, myUid),
                  child: _ChatTile(
                    title: groupName,
                    lastMsg: lastMsg,
                    lastMsgAt: lastMsgAt,
                    unread: unread,
                    isGroup: true,
                    memberCount: users.length,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        chatId: chatId,
                        title: groupName,
                        isGroup: true,
                        memberUids: users,
                      ),
                    )),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// 필터 버튼
class _FilterBtn extends StatelessWidget {
  final String label, value, current;
  final VoidCallback onTap;
  const _FilterBtn({required this.label, required this.value,
      required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? context.primaryColor : context.subtleBg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: isSelected
              ? (context.isDark ? Colors.black : Colors.white)
              : context.textSecondary,
        )),
      ),
    );
  }
}

// 채팅방 타일
class _ChatTile extends StatelessWidget {
  final String title, lastMsg;
  final Timestamp? lastMsgAt;
  final int unread;
  final bool isGroup;
  final int? memberCount;
  final Map<String, dynamic>? otherCharacter;
  final VoidCallback onTap;

  const _ChatTile({
    required this.title, required this.lastMsg,
    required this.lastMsgAt, required this.unread,
    required this.isGroup, required this.onTap,
    this.memberCount, this.otherCharacter,
  });

  String _timeLabel(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        child: Row(children: [
          // 아바타
          if (isGroup)
            Container(width: 46, height: 46,
                decoration: BoxDecoration(color: context.subtleBg, shape: BoxShape.circle),
                child: const Center(child: Text('👥', style: TextStyle(fontSize: 22))))
          else
            CharacterAvatar(character: otherCharacter, size: 46),
          const SizedBox(width: 12),

          // 채팅방 정보
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: context.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(_timeLabel(lastMsgAt),
                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              if (isGroup && memberCount != null) ...[
                Text('$memberCount명 · ',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
              Expanded(
                child: Text(lastMsg.isEmpty ? '대화를 시작해보세요' : lastMsg,
                    style: TextStyle(fontSize: 13, color: context.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.primaryColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$unread', style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.isDark ? Colors.black : Colors.white)),
                ),
            ]),
          ])),
        ]),
      ),
    );
  }
}