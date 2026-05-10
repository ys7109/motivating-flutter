import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/diary_service.dart';
import '../../services/friend_service.dart';
import '../../models/diary_model.dart';
import '../../models/achievement_definitions.dart';
import 'character_avatar.dart';

class DiaryTab extends StatefulWidget {
  const DiaryTab({super.key});
  @override
  State<DiaryTab> createState() => DiaryTabState();
}

class DiaryTabState extends State<DiaryTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _diaryService = DiaryService();
  final _friendService = FriendService();

  List<DiaryModel> _myDiaries = [];
  List<DiaryModel> _friendDiaries = [];
  List<DiaryModel> _publicDiaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> reload() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    final uid = app.authUser!.uid;
    setState(() => _loading = true);
    try {
      final friends = await _friendService.getFriends(uid);
      final friendUids = friends.map((f) => f['uid'] as String).toList();
      final results = await Future.wait([
        _diaryService.getMyDiaries(uid),
        _diaryService.getFriendDiaries(uid, friendUids),
        _diaryService.getPublicDiaries(uid),
      ]);
      if (mounted) setState(() {
        _myDiaries = results[0];
        _friendDiaries = results[1];
        _publicDiaries = results[2];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openWriteDialog({DiaryModel? editing}) {
    final app = context.read<AppProvider>();
    final contentCtrl = TextEditingController(text: editing?.content ?? '');
    String visibility = editing?.visibility ?? 'private';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(editing == null ? '게시글 작성' : '게시글 수정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
              GestureDetector(onTap: () => Navigator.pop(ctx),
                  child: Text('×', style: TextStyle(fontSize: 24, color: ctx.textSecondary))),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: ctx.surfaceColor,
                  border: Border.all(color: ctx.borderColor), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: contentCtrl, maxLines: 6,
                style: TextStyle(fontSize: 14, color: ctx.textPrimary),
                decoration: InputDecoration(
                  hintText: '오늘 하루를 기록해보세요...',
                  hintStyle: TextStyle(color: ctx.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('공개 설정', style: TextStyle(fontSize: 13, color: ctx.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              ['private', '🔒 비공개'],
              ['friends', '👥 친구'],
              ['public', '🌐 전체'],
            ].map((v) {
              final isSelected = visibility == v[0];
              return GestureDetector(
                onTap: () => setModalState(() => visibility = v[0]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? ctx.primaryColor : ctx.subtleBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(v[1], style: TextStyle(fontSize: 12,
                      color: isSelected ? ctx.onPrimary : ctx.textSecondary)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                if (contentCtrl.text.trim().isEmpty) return;
                final uid = app.authUser!.uid;
                final userData = {
                  'name': app.userData!.name,
                  'level': app.userData!.level,
                  'character': app.userData!.character.toMap(),
                  'equippedAchievement': app.userData!.equippedAchievement,
                };
                if (editing == null) {
                  await _diaryService.addDiary(uid, userData, contentCtrl.text.trim(), visibility);
                } else {
                  await _diaryService.updateDiary(editing.id, contentCtrl.text.trim(), visibility);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
                if (editing == null && mounted) await app.onDiaryWritten(_myDiaries.length);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(editing == null ? '작성하기' : '수정하기',
                    style: TextStyle(color: context.onPrimary,
                        fontSize: 15, fontWeight: FontWeight.w600))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // 게시글 터치 시 상세 팝업 — 게시글 내용 + 좋아요 + 댓글
  void _openComments(DiaryModel diary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CommentSheet(
        diary: diary,
        diaryService: _diaryService,
        onChanged: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AppProvider>().authUser!.uid;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
            child: TabBar(
              controller: _tabCtrl,
              dividerColor: Colors.transparent,
              indicator: UnderlineTabIndicator(borderSide: BorderSide(color: context.primaryColor, width: 2)),
              labelColor: context.primaryColor,
              unselectedLabelColor: context.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              // 탭 이름 — 내 게시글, 친구, 전체
              tabs: const [Tab(text: '내 게시글'), Tab(text: '친구'), Tab(text: '전체')],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openWriteDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_outlined, size: 14, color: context.onPrimary),
                const SizedBox(width: 4),
                Text('작성', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: context.onPrimary)),
              ]),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: context.primaryColor))
            : TabBarView(controller: _tabCtrl, children: [
                // 내 게시글 탭 — 수정/삭제 가능
                _DiaryList(diaries: _myDiaries, myUid: myUid, onRefresh: _load,
                    onEdit: (d) => _openWriteDialog(editing: d),
                    onDelete: (d) async { await _diaryService.deleteDiary(d.id); await _load(); },
                    onComment: _openComments),
                // 친구 탭
                _DiaryList(diaries: _friendDiaries, myUid: myUid, onRefresh: _load,
                    onComment: _openComments),
                // 전체 탭
                _DiaryList(diaries: _publicDiaries, myUid: myUid, onRefresh: _load,
                    onEdit: (d) => _openWriteDialog(editing: d),
                    onDelete: (d) async { await _diaryService.deleteDiary(d.id); await _load(); },
                    onComment: _openComments),
              ]),
      ),
    ]);
  }
}

// ── 게시글 목록 ──
class _DiaryList extends StatelessWidget {
  final List<DiaryModel> diaries;
  final String myUid;
  final Future<void> Function() onRefresh;
  final void Function(DiaryModel)? onEdit;
  final Future<void> Function(DiaryModel)? onDelete;
  final void Function(DiaryModel) onComment;

  const _DiaryList({required this.diaries, required this.myUid, required this.onRefresh,
      this.onEdit, this.onDelete, required this.onComment});

  @override
  Widget build(BuildContext context) {
    if (diaries.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📔', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text('아직 게시글이 없어요', style: TextStyle(fontSize: 14, color: context.textSecondary)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: onRefresh, color: context.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: diaries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = diaries[i];
          final isMe = d.uid == myUid;
          return _DiaryCard(
            diary: d, isMe: isMe,
            onEdit: isMe && onEdit != null ? () => onEdit!(d) : null,
            onDelete: isMe && onDelete != null ? () => onDelete!(d) : null,
            // 카드 터치 시 상세 팝업 열기
            onTap: () => onComment(d),
          );
        },
      ),
    );
  }
}

// ── 게시글 카드 — 터치하면 상세 팝업 열림 ──
class _DiaryCard extends StatelessWidget {
  final DiaryModel diary;
  final bool isMe;
  final VoidCallback? onEdit, onDelete, onTap;

  const _DiaryCard({required this.diary, required this.isMe,
      this.onEdit, this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final achievement = diary.authorEquippedAchievement != null
        ? Achievements.findById(diary.authorEquippedAchievement!) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CharacterAvatar(character: diary.authorCharacter, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(diary.authorName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
              if (achievement != null) ...[
                const SizedBox(height: 2),
                _TitleChip(achievement: achievement),
                const SizedBox(height: 2),
              ],
              Row(children: [
                Text('Lv.${diary.authorLevel}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                const SizedBox(width: 6),
                Text('·', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                const SizedBox(width: 6),
                Text(diary.timeAgo, style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ]),
            ])),
            // 내 게시글일 때 수정/삭제 버튼
            if (isMe) ...[
              if (onEdit != null) GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 18, color: context.textSecondary))),
              const SizedBox(width: 6),
              if (onDelete != null) GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 18, color: context.textSecondary))),
            ],
          ]),
          const SizedBox(height: 10),
          // 본문 — 최대 3줄 미리보기
          Text(diary.content, style: TextStyle(fontSize: 14, color: context.textPrimary, height: 1.5),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(diary.visibilityLabel, style: TextStyle(fontSize: 11, color: context.textSecondary)),
            Row(children: [
              // 댓글 수
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: context.textSecondary),
              const SizedBox(width: 4),
              Text('${diary.commentCount}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const SizedBox(width: 12),
              // 좋아요 수
              Icon(diary.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 15, color: diary.likedByMe ? AppTheme.danger : context.textSecondary),
              const SizedBox(width: 4),
              Text('${diary.likeCount}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ── 칭호 칩 ──
class _TitleChip extends StatelessWidget {
  final Achievement achievement;
  const _TitleChip({required this.achievement});
  @override
  Widget build(BuildContext context) {
    final dc = Color(Achievements.difficultyColor[achievement.difficulty]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: dc.withOpacity(0.12), borderRadius: BorderRadius.circular(99),
          border: Border.all(color: dc.withOpacity(0.3))),
      child: Text(achievement.title, style: TextStyle(fontSize: 10, color: dc, fontWeight: FontWeight.w600)),
    );
  }
}

// ── 게시글 상세 팝업 — 내용 + 좋아요 + 댓글 ──
class _CommentSheet extends StatefulWidget {
  final DiaryModel diary;
  final DiaryService diaryService;
  final VoidCallback onChanged;
  const _CommentSheet({required this.diary, required this.diaryService, required this.onChanged});
  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  List<CommentModel> _comments = [];
  bool _loading = true;
  bool _sending = false;
  final _commentCtrl = TextEditingController();

  // 좋아요 상태 — 즉시 반영용
  late bool _likedByMe;
  late int _likeCount;
  late int _commentCount;

  // 답글 입력 상태
  String? _replyingToCommentId;
  String? _replyingToName;
  String? _replyingToAuthorUid;
  String? _replyingToContent;
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _likedByMe = widget.diary.likedByMe;
    _likeCount = widget.diary.likeCount;
    _commentCount = widget.diary.commentCount;
    _load();
  }

  @override
  void dispose() { _commentCtrl.dispose(); _replyCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      _comments = await widget.diaryService.getComments(widget.diary.id);
      // 댓글 + 답글 수 합산
      if (mounted) setState(() => _commentCount = _comments.fold(0, (s, c) => s + 1 + c.replies.length));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 좋아요 토글 — 즉시 UI 반영
  Future<void> _toggleLike() async {
    final app = context.read<AppProvider>();
    final myUid = app.authUser!.uid;
    setState(() {
      _likedByMe = !_likedByMe;
      _likeCount += _likedByMe ? 1 : -1;
    });
    await widget.diaryService.toggleLike(myUid, widget.diary.id,
        myUserData: {'name': app.userData!.name, 'character': app.userData!.character.toMap()});
    widget.onChanged();
  }

  void _startReply(String commentId, String authorName, String authorUid, String commentContent) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToName = authorName;
      _replyingToAuthorUid = authorUid;
      _replyingToContent = commentContent;
    });
    _replyCtrl.clear();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToName = null;
      _replyingToAuthorUid = null;
      _replyingToContent = null;
    });
    _replyCtrl.clear();
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty || _sending) return;
    final app = context.read<AppProvider>();
    setState(() => _sending = true);
    try {
      await widget.diaryService.addComment(widget.diary.id, {
        'uid': app.authUser!.uid,
        'name': app.userData!.name,
        'character': app.userData!.character.toMap(),
        'equippedAchievement': app.userData!.equippedAchievement,
      }, _commentCtrl.text.trim());
      _commentCtrl.clear();
      await _load();
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitReply() async {
    if (_replyCtrl.text.trim().isEmpty || _sending || _replyingToCommentId == null) return;
    final app = context.read<AppProvider>();
    setState(() => _sending = true);
    try {
      await widget.diaryService.addReply(
        widget.diary.id, _replyingToCommentId!,
        {
          'uid': app.authUser!.uid,
          'name': app.userData!.name,
          'character': app.userData!.character.toMap(),
          'equippedAchievement': app.userData!.equippedAchievement,
        },
        _replyCtrl.text.trim(),
        commentAuthorUid: _replyingToAuthorUid,
        commentContent: _replyingToContent,
      );
      _replyCtrl.clear();
      _cancelReply();
      await _load();
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    await widget.diaryService.deleteComment(widget.diary.id, comment.id, comment.replyCount);
    await _load();
    widget.onChanged();
  }

  Future<void> _deleteReply(String commentId, String replyId) async {
    await widget.diaryService.deleteReply(widget.diary.id, commentId, replyId);
    await _load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AppProvider>().authUser!.uid;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    final isReplying = _replyingToCommentId != null;
    final achievement = widget.diary.authorEquippedAchievement != null
        ? Achievements.findById(widget.diary.authorEquippedAchievement!) : null;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('게시글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
            GestureDetector(onTap: () => Navigator.pop(context),
                child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
          ]),
        ),
        const Divider(height: 1),

        // 스크롤 가능한 본문 + 댓글 영역
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 게시글 내용
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 작성자 정보
                  Row(children: [
                    CharacterAvatar(character: widget.diary.authorCharacter, size: 38),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.diary.authorName, style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: context.textPrimary)),
                      if (achievement != null) ...[
                        const SizedBox(height: 2),
                        _TitleChip(achievement: achievement),
                        const SizedBox(height: 2),
                      ],
                      Row(children: [
                        Text('Lv.${widget.diary.authorLevel}',
                            style: TextStyle(fontSize: 11, color: context.textSecondary)),
                        const SizedBox(width: 6),
                        Text('·', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                        const SizedBox(width: 6),
                        Text(widget.diary.timeAgo,
                            style: TextStyle(fontSize: 11, color: context.textSecondary)),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  // 게시글 본문 — 전체 표시
                  Text(widget.diary.content,
                      style: TextStyle(fontSize: 15, color: context.textPrimary, height: 1.6)),
                  const SizedBox(height: 14),
                  // 좋아요 + 댓글 수 버튼
                  Row(children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _likedByMe ? AppTheme.danger.withOpacity(0.1) : context.subtleBg,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: _likedByMe ? AppTheme.danger.withOpacity(0.3) : context.borderColor),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_likedByMe ? Icons.favorite : Icons.favorite_border,
                              size: 15, color: _likedByMe ? AppTheme.danger : context.textSecondary),
                          const SizedBox(width: 5),
                          Text('$_likeCount', style: TextStyle(fontSize: 13,
                              color: _likedByMe ? AppTheme.danger : context.textSecondary,
                              fontWeight: _likedByMe ? FontWeight.w600 : FontWeight.normal)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.subtleBg,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 15, color: context.textSecondary),
                        const SizedBox(width: 5),
                        Text('$_commentCount',
                            style: TextStyle(fontSize: 13, color: context.textSecondary)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                ]),
              ),
              const Divider(height: 1),

              // 댓글 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('댓글 $_commentCount',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
              ),

              // 댓글 목록
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('💬', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    Text('첫 댓글을 남겨보세요!',
                        style: TextStyle(fontSize: 14, color: context.textSecondary)),
                  ])),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = _comments[i];
                    return _CommentItem(
                      comment: c,
                      myUid: myUid,
                      isReplyingToThis: _replyingToCommentId == c.id,
                      onReply: () => _startReply(c.id, c.authorName, c.uid, c.content),
                      onDelete: () => _deleteComment(c),
                      onDeleteReply: (rId) => _deleteReply(c.id, rId),
                    );
                  },
                ),
              // 입력창 높이만큼 하단 여백
              const SizedBox(height: 80),
            ],
          ),
        ),

        const Divider(height: 1),

        // 답글 작성 중 표시
        if (isReplying)
          Container(
            color: context.primaryColor.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.reply, size: 14, color: context.primaryColor),
              const SizedBox(width: 6),
              Expanded(child: Text('$_replyingToName 님에게 답글 작성 중',
                  style: TextStyle(fontSize: 12, color: context.primaryColor))),
              GestureDetector(onTap: _cancelReply,
                  child: Icon(Icons.close, size: 16, color: context.textSecondary)),
            ]),
          ),

        // 댓글/답글 입력창
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 10),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.subtleBg, borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isReplying ? context.primaryColor : context.borderColor),
                ),
                child: TextField(
                  controller: isReplying ? _replyCtrl : _commentCtrl,
                  maxLines: 1, maxLength: 200,
                  style: TextStyle(fontSize: 14, color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: isReplying ? '답글을 입력하세요...' : '댓글을 입력하세요...',
                    hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                    border: InputBorder.none, counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => isReplying ? _submitReply() : _submitComment(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : (isReplying ? _submitReply : _submitComment),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: context.primaryColor),
                child: _sending
                    ? Padding(padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.onPrimary))
                    : Icon(Icons.send_rounded, size: 18, color: context.onPrimary),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── 댓글 아이템 (답글 포함) ──
class _CommentItem extends StatelessWidget {
  final CommentModel comment;
  final String myUid;
  final bool isReplyingToThis;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final void Function(String replyId) onDeleteReply;

  const _CommentItem({
    required this.comment, required this.myUid,
    required this.isReplyingToThis, required this.onReply,
    required this.onDelete, required this.onDeleteReply,
  });

  @override
  Widget build(BuildContext context) {
    final isMyComment = comment.uid == myUid;
    final achievement = comment.authorEquippedAchievement != null
        ? Achievements.findById(comment.authorEquippedAchievement!) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 댓글 본체
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CharacterAvatar(character: comment.authorCharacter, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 닉네임 + 칭호 + 시간
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(comment.authorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
              if (achievement != null) ...[
                const SizedBox(width: 6),
                _TitleChip(achievement: achievement),
              ],
              const SizedBox(width: 6),
              Text(comment.timeAgo, style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ]),
            const SizedBox(height: 4),
            Text(comment.content, style: TextStyle(fontSize: 14, color: context.textPrimary, height: 1.4)),
            const SizedBox(height: 6),
            // 답글 버튼
            GestureDetector(
              onTap: onReply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReplyingToThis ? context.primaryColor.withOpacity(0.1) : context.subtleBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.reply, size: 13,
                      color: isReplyingToThis ? context.primaryColor : context.textSecondary),
                  const SizedBox(width: 3),
                  Text('답글', style: TextStyle(fontSize: 12,
                      color: isReplyingToThis ? context.primaryColor : context.textSecondary)),
                ]),
              ),
            ),
          ])),
          if (isMyComment)
            GestureDetector(onTap: onDelete,
                child: Padding(padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Icon(Icons.delete_outline, size: 16, color: context.textSecondary))),
        ]),

        // 답글 목록
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 8),
            child: Column(children: comment.replies.map((r) {
              final isMyReply = r.uid == myUid;
              final replyAchievement = r.authorEquippedAchievement != null
                  ? Achievements.findById(r.authorEquippedAchievement!) : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 답글 인덴트 선
                  Container(
                    width: 2, height: 34, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                        color: context.borderColor, borderRadius: BorderRadius.circular(1)),
                  ),
                  CharacterAvatar(character: r.authorCharacter, size: 28),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Text(r.authorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: context.textPrimary)),
                      if (replyAchievement != null) ...[
                        const SizedBox(width: 5),
                        _TitleChip(achievement: replyAchievement),
                      ],
                      const SizedBox(width: 5),
                      Text(r.timeAgo, style: TextStyle(fontSize: 10, color: context.textSecondary)),
                    ]),
                    const SizedBox(height: 3),
                    Text(r.content, style: TextStyle(fontSize: 13, color: context.textPrimary, height: 1.4)),
                  ])),
                  if (isMyReply)
                    GestureDetector(onTap: () => onDeleteReply(r.id),
                        child: Padding(padding: const EdgeInsets.only(left: 6, top: 2),
                            child: Icon(Icons.delete_outline, size: 14, color: context.textSecondary))),
                ]),
              );
            }).toList()),
          ),
      ]),
    );
  }
}