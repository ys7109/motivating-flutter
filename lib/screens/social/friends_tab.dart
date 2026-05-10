import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/friend_service.dart';
import 'character_avatar.dart';
import '../../models/achievement_definitions.dart';
import '../../services/chat_service.dart';
import '../../utils/transitions.dart';
import 'chat_room_screen.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});
  @override
  State<FriendsTab> createState() => FriendsTabState();
}

class FriendsTabState extends State<FriendsTab> {
  final _friendService = FriendService();

  StreamSubscription? _friendsSub;
  StreamSubscription? _requestsSub;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _friendRankings = [];
  String _rankTab = 'total';
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _startStreams();
    _loadRankings();
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> reload() async => _loadRankings();

  void _startStreams() {
    final uid = context.read<AppProvider>().authUser!.uid;

    // 친구 목록 스트림 구독 — friendships 변경 시 자동 갱신
    _friendsSub = _friendService.friendsStream(uid).listen((friends) {
      if (mounted) setState(() { _friends = friends; _loading = false; });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });

    // 친구 요청 스트림 구독
    _requestsSub = _friendService.requestsStream(uid).listen((requests) {
      if (mounted) setState(() => _requests = requests);
    });
  }

  Future<void> _loadRankings() async {
    final uid = context.read<AppProvider>().authUser!.uid;
    final rankings = await _friendService.getFriendRankings(uid, _rankTab);
    if (mounted) setState(() => _friendRankings = rankings);
  }

  Future<void> _openGroupChatDialog(BuildContext context, String myUid) async {
    final selected = <String>{};
    final nameCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('그룹 채팅 만들기', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600, color: ctx.textPrimary)),
              GestureDetector(onTap: () => Navigator.pop(ctx),
                  child: Text('×', style: TextStyle(fontSize: 24, color: ctx.textSecondary))),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: ctx.surfaceColor,
                  border: Border.all(color: ctx.borderColor),
                  borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: nameCtrl,
                style: TextStyle(fontSize: 14, color: ctx.textPrimary),
                decoration: InputDecoration(
                  hintText: '그룹 이름을 입력하세요',
                  hintStyle: TextStyle(color: ctx.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setModalState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            Text('참여할 친구 선택 (${selected.length}명)',
                style: TextStyle(fontSize: 13, color: ctx.textSecondary)),
            const SizedBox(height: 8),
            // 친구 목록 스크롤 가능하게 — 키보드 올라올 때 오버플로우 방지
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: _friends.map((friend) {
              final uid = friend['uid'] as String;
              final isSelected = selected.contains(uid);
              return GestureDetector(
                onTap: () => setModalState(() {
                  if (isSelected) selected.remove(uid); else selected.add(uid);
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? ctx.primaryColor.withOpacity(0.08) : ctx.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? ctx.primaryColor : ctx.borderColor,
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(children: [
                    CharacterAvatar(character: friend['character'] as Map<String, dynamic>?, size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Text(friend['name'] ?? '모험가',
                        style: TextStyle(fontSize: 14, color: ctx.textPrimary))),
                    if (isSelected) Icon(Icons.check_circle, size: 18, color: ctx.primaryColor),
                  ]),
                ),
              );
            }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: selected.isEmpty || nameCtrl.text.trim().isEmpty ? null : () async {
                final groupName = nameCtrl.text.trim();
                final memberList = selected.toList();
                final chatId = await ChatService().createGroupChat(myUid, memberList, groupName);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      chatId: chatId, title: groupName,
                      isGroup: true, memberUids: [myUid, ...memberList],
                    ),
                  ));
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected.isEmpty || nameCtrl.text.trim().isEmpty
                      ? ctx.borderColor : ctx.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                // 그룹 채팅 만들기 버튼 — onPrimary로 대비 자동 계산
                child: Center(child: Text('그룹 채팅 만들기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: selected.isEmpty || nameCtrl.text.trim().isEmpty
                            ? ctx.textSecondary
                            : ctx.onPrimary))),
              ),
            ),
          ]),
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) { setState(() => _searchResults = []); return; }
    final uid = context.read<AppProvider>().authUser!.uid;
    final results = await _friendService.searchUsers(query.trim(), uid);
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _sendRequest(String targetUid) async {
    final uid = context.read<AppProvider>().authUser!.uid;
    await _friendService.sendRequest(uid, targetUid);
    if (mounted) context.read<AppProvider>().showToast('친구 요청을 보냈어요!');
    setState(() => _searchResults = []);
    _searchCtrl.clear();
  }

  Future<void> _acceptRequest(String fromUid) async {
    final app = context.read<AppProvider>();
    final uid = app.authUser!.uid;
    await _friendService.acceptRequest(uid, fromUid);
    if (mounted) app.showToast('친구 요청을 수락했어요!');
    // 업적 체크 — 친구 추가 달성 여부 확인
    await app.onFriendAdded();
  }

  Future<void> _rejectRequest(String fromUid) async {
    final uid = context.read<AppProvider>().authUser!.uid;
    await _friendService.removeFriend(uid, fromUid);
  }

  Future<void> _removeFriend(String friendUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.modalBg,
        title: Text('친구 삭제', style: TextStyle(color: context.textPrimary)),
        content: Text('친구를 삭제하시겠어요?', style: TextStyle(color: context.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: TextStyle(color: context.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirm == true) {
      final uid = context.read<AppProvider>().authUser!.uid;
      await _friendService.removeFriend(uid, friendUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AppProvider>().authUser!.uid;
    if (_loading) return Center(child: CircularProgressIndicator(color: context.primaryColor));

    return RefreshIndicator(
      onRefresh: () async => _loadRankings(),
      color: context.primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // 검색창
          Container(
            decoration: BoxDecoration(color: context.surfaceColor,
                border: Border.all(color: context.borderColor),
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
              textInputAction: TextInputAction.search,
              onChanged: _search, onSubmitted: _search,
              decoration: InputDecoration(
                hintText: '닉네임으로 친구 검색',
                hintStyle: TextStyle(color: context.textSecondary),
                prefixIcon: Icon(Icons.search, color: context.textSecondary, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          // 검색 결과
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: context.surfaceColor,
                  border: Border.all(color: context.borderColor),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: _searchResults.map((user) {
                final isFriend = _friends.any((f) => f['uid'] == user['uid']);
                return FutureBuilder<String?>(
                  future: _friendService.getFriendshipStatus(myUid, user['uid']),
                  builder: (_, snap) {
                    final status = snap.data;
                    return ListTile(
                      leading: CharacterAvatar(
                          character: user['character'] as Map<String, dynamic>?, size: 36),
                      title: Text(user['name'] ?? '모험가',
                          style: TextStyle(fontSize: 14, color: context.textPrimary)),
                      subtitle: Text('Lv.${user['level'] ?? 1}',
                          style: TextStyle(fontSize: 12, color: context.textSecondary)),
                      trailing: isFriend
                          ? Text('친구', style: TextStyle(fontSize: 12, color: context.primaryColor))
                          : status == 'pending'
                              ? Text('요청 중', style: TextStyle(fontSize: 12, color: context.textSecondary))
                              : GestureDetector(
                                  onTap: () => _sendRequest(user['uid']),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(color: context.primaryColor,
                                        borderRadius: BorderRadius.circular(99)),
                                    // 친구 추가 버튼 — onPrimary로 대비 자동 계산
                                    child: Text('친구 추가', style: TextStyle(fontSize: 12,
                                        color: context.onPrimary)),
                                  ),
                                ),
                    );
                  },
                );
              }).toList()),
            ),
          ],
          const SizedBox(height: 20),

          // 친구 요청 목록
          if (_requests.isNotEmpty) ...[
            Text('친구 요청 ${_requests.length}', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: context.textPrimary)),
            const SizedBox(height: 8),
            ..._requests.map((req) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.08),
                border: Border.all(color: context.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                CharacterAvatar(character: req['character'] as Map<String, dynamic>?, size: 36),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(req['name'] ?? '모험가', style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: context.textPrimary)),
                  Text('Lv.${req['level'] ?? 1}',
                      style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ])),
                GestureDetector(
                  onTap: () => _rejectRequest(req['uid']),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: context.subtleBg,
                        border: Border.all(color: context.borderColor),
                        borderRadius: BorderRadius.circular(99)),
                    child: Text('거절', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _acceptRequest(req['uid']),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: context.primaryColor,
                        borderRadius: BorderRadius.circular(99)),
                    // 수락 버튼 — onPrimary로 대비 자동 계산
                    child: Text('수락', style: TextStyle(fontSize: 12,
                        color: context.onPrimary)),
                  ),
                ),
              ]),
            )),
            const SizedBox(height: 12),
          ],

          // 친구 랭킹
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('친구 랭킹', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: context.textPrimary)),
            Row(children: [['total', '누적'], ['daily', '오늘'], ['average', '평균']].map((t) {
              final isSelected = _rankTab == t[0];
              return GestureDetector(
                onTap: () async {
                  setState(() => _rankTab = t[0]);
                  final uid = context.read<AppProvider>().authUser!.uid;
                  final rankings = await _friendService.getFriendRankings(uid, t[0]);
                  if (mounted) setState(() => _friendRankings = rankings);
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? context.primaryColor : context.subtleBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  // 랭킹 탭 버튼 — onPrimary로 대비 자동 계산
                  child: Text(t[1], style: TextStyle(fontSize: 11,
                      color: isSelected ? context.onPrimary : context.textSecondary)),
                ),
              );
            }).toList()),
          ]),
          const SizedBox(height: 8),
          if (_friendRankings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('친구를 추가하면 랭킹이 표시돼요',
                  style: TextStyle(fontSize: 13, color: context.textSecondary))),
            )
          else
            ..._friendRankings.map((user) {
              final isMe = user['uid'] == myUid;
              final medal = user['rank'] == 1 ? '🥇' : user['rank'] == 2 ? '🥈'
                  : user['rank'] == 3 ? '🥉' : null;
              final focusMin = _rankTab == 'total' ? user['totalFocusMin']
                  : _rankTab == 'daily' ? user['todayFocusMin'] : user['avgFocusMin'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceColor, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isMe ? context.primaryColor : context.borderColor,
                      width: isMe ? 1.5 : 0.5),
                ),
                child: Row(children: [
                  SizedBox(width: 30, child: Center(child: medal != null
                      ? Text(medal, style: const TextStyle(fontSize: 20))
                      : Text('${user['rank']}', style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: context.textSecondary)))),
                  const SizedBox(width: 8),
                  CharacterAvatar(character: user['character'] as Map<String, dynamic>?, size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(user['name'] ?? '모험가', style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w500, color: context.textPrimary)),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: context.subtleBg,
                              borderRadius: BorderRadius.circular(99)),
                          child: Text('나', style: TextStyle(fontSize: 11, color: context.textPrimary)),
                        ),
                      ],
                    ]),
                    Builder(builder: (ctx) {
                      final eid = user['equippedAchievement'] as String?;
                      final a = eid != null ? Achievements.findById(eid) : null;
                      if (a == null) return const SizedBox.shrink();
                      final dc = Color(Achievements.difficultyColor[a.difficulty]!);
                      return Padding(padding: const EdgeInsets.only(bottom: 2), child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: dc.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: dc.withOpacity(0.3))),
                          child: Text(a.title, style: TextStyle(fontSize: 10, color: dc,
                              fontWeight: FontWeight.w600))));
                    }),
                    Text('Lv.${user['level'] ?? 1}',
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ])),
                  Text(_formatMin(focusMin), style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w600, color: context.textPrimary)),
                ]),
              );
            }),
          const SizedBox(height: 20),

          // 그룹 채팅 생성 버튼 — 친구가 있을 때만 표시
          if (_friends.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _openGroupChatDialog(context, myUid),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  border: Border.all(color: context.borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.group_add_outlined, size: 18, color: context.textSecondary),
                  const SizedBox(width: 8),
                  Text('그룹 채팅 만들기', style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: context.textSecondary)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 친구 목록
          Text('친구 ${_friends.length}명', style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 8),
          if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('👥', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text('아직 친구가 없어요',
                    style: TextStyle(fontSize: 14, color: context.textSecondary)),
                const SizedBox(height: 4),
                Text('닉네임으로 검색해서 친구를 추가해보세요',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ])),
            )
          else
            // 친구 타일 — 각각 presence 실시간 구독
            ..._friends.map((friend) => _FriendTile(
                friend: friend, myUid: myUid, onRemove: () => _removeFriend(friend['uid']))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FriendTile extends StatefulWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onRemove;
  final String myUid;
  const _FriendTile({required this.friend, required this.onRemove, required this.myUid});
  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  bool _navigating = false;

  // presence 실시간 구독 — 접속 상태 즉시 반영
  StreamSubscription? _presenceSub;
  String _presenceStatus = 'offline';
  dynamic _lastSeen;

  @override
  void initState() {
    super.initState();
    // 초기값은 friendsStream에서 넘어온 값 사용
    _presenceStatus = widget.friend['presenceStatus'] as String? ?? 'offline';
    _lastSeen = widget.friend['lastSeen'];
    // presence 스트림 구독 시작
    _subscribePres();
  }

  void _subscribePres() {
    final friendUid = widget.friend['uid'] as String;
    // presence 컬렉션 실시간 구독 — 변경 즉시 UI 갱신
    _presenceSub = FriendService().presenceStream(friendUid).listen((data) {
      if (!mounted) return;
      setState(() {
        _presenceStatus = data['presenceStatus'] as String? ?? 'offline';
        _lastSeen = data['lastSeen'];
      });
    });
  }

  @override
  void dispose() {
    // presence 구독 해제
    _presenceSub?.cancel();
    super.dispose();
  }

  Future<void> _openChat() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      final chatId = await ChatService().getOrCreateDirectChat(
          widget.myUid, widget.friend['uid'] as String);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId: chatId,
          title: widget.friend['name'] ?? '모험가',
          otherCharacter: widget.friend['character'] as Map<String, dynamic>?,
          memberUids: [widget.myUid, widget.friend['uid'] as String],
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅방을 열 수 없어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;

    // presence 스트림에서 받은 최신 상태 사용
    final isOnline = _presenceStatus == 'online';
    final isFocusing = _presenceStatus == 'focusing';

    String statusText;
    Color statusColor;
    if (isFocusing) {
      statusText = '집중모드 실행중';
      statusColor = const Color(0xFFf9a825);
    } else if (isOnline) {
      statusText = '접속 중';
      statusColor = const Color(0xFF4CAF50);
    } else if (_lastSeen != null) {
      final dt = (_lastSeen as dynamic).toDate() as DateTime;
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) statusText = '방금 전 접속';
      else if (diff.inMinutes < 60) statusText = '${diff.inMinutes}분 전 접속';
      else if (diff.inHours < 24) statusText = '${diff.inHours}시간 전 접속';
      else statusText = '${diff.inDays}일 전 접속';
      statusColor = context.textSecondary;
    } else {
      statusText = '접속 정보 없음';
      statusColor = context.textSecondary;
    }

    final dotColor = isFocusing ? const Color(0xFFf9a825)
        : isOnline ? const Color(0xFF4CAF50)
        : const Color(0xFF9E9E9E);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor, width: 0.5)),
      child: Row(children: [
        Stack(children: [
          CharacterAvatar(character: friend['character'] as Map<String, dynamic>?, size: 40),
          // 접속 상태 도트
          Positioned(bottom: 0, right: 0, child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: dotColor,
              border: Border.all(color: context.surfaceColor, width: 1.5),
            ),
          )),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(friend['name'] ?? '모험가', style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w500, color: context.textPrimary)),
          Builder(builder: (ctx) {
            final eid = friend['equippedAchievement'] as String?;
            final a = eid != null ? Achievements.findById(eid) : null;
            if (a == null) return const SizedBox.shrink();
            final dc = Color(Achievements.difficultyColor[a.difficulty]!);
            return Padding(padding: const EdgeInsets.only(top: 2, bottom: 2), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: dc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: dc.withOpacity(0.3))),
                child: Text(a.title, style: TextStyle(fontSize: 10, color: dc,
                    fontWeight: FontWeight.w600))));
          }),
          Row(children: [
            Text('Lv.${friend['level'] ?? 1}',
                style: TextStyle(fontSize: 12, color: context.textSecondary)),
            const SizedBox(width: 6),
            Text('·', style: TextStyle(fontSize: 12, color: context.textSecondary)),
            const SizedBox(width: 6),
            Text(statusText, style: TextStyle(fontSize: 12, color: statusColor)),
          ]),
        ])),
        // 채팅 버튼 — 미읽음 배지 포함
        GestureDetector(
          onTap: _navigating ? null : _openChat,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 34, height: 34,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(99),
            ),
            child: _navigating
                ? Padding(padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.primaryColor))
                : FutureBuilder<int>(
                    future: ChatService().getTotalUnreadCountForUser(widget.myUid, friend['uid']),
                    builder: (_, snap) {
                      final unread = snap.data ?? 0;
                      return Stack(clipBehavior: Clip.none, children: [
                        Center(child: Icon(Icons.chat_bubble_outline_rounded,
                            size: 16, color: context.textSecondary)),
                        // 미읽음 배지
                        if (unread > 0)
                          Positioned(top: -3, right: -3, child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                                color: AppTheme.danger, shape: BoxShape.circle),
                            child: Center(child: Text('$unread',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 8, fontWeight: FontWeight.bold))),
                          )),
                      ]);
                    },
                  ),
          ),
        ),
        // 친구 삭제 버튼
        GestureDetector(
          onTap: widget.onRemove,
          behavior: HitTestBehavior.opaque,
          child: Icon(Icons.person_remove_outlined, size: 20, color: context.textSecondary),
        ),
      ]),
    );
  }
}

// 분을 시간/분 형식으로 변환
String _formatMin(dynamic min) {
  if (min == null || min == 0) return '0분';
  final h = (min as int) ~/ 60;
  final m = min % 60;
  if (h > 0) return '$h시간 ${m > 0 ? '${m}분' : ''}';
  return '$m분';
}