import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    final List<String> existingImageUrls = List<String>.from(editing?.imageUrls ?? []);
    final List<File> newImages = [];
    final Set<String> removedUrls = {};
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final visibleExisting = existingImageUrls
              .where((url) => !removedUrls.contains(url)).toList();
          final totalCount = visibleExisting.length + newImages.length;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20,
                MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(editing == null ? '일기 작성' : '일기 수정',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
                  GestureDetector(onTap: () => Navigator.pop(ctx),
                      child: Text('×', style: TextStyle(fontSize: 24, color: ctx.textSecondary))),
                ]),
                const SizedBox(height: 16),
                // 본문 입력창
                Container(
                  decoration: BoxDecoration(color: ctx.surfaceColor,
                      border: Border.all(color: ctx.borderColor),
                      borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: contentCtrl, maxLines: 5,
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

                // 사진 미리보기 + 추가 버튼 — Row로 항상 표시
                SizedBox(
                  height: 80,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 기존 이미지 (수정 시)
                        ...visibleExisting.map((url) => Stack(
                          children: [
                            Container(
                              width: 80, height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                      image: NetworkImage(url), fit: BoxFit.cover)),
                            ),
                            Positioned(top: 2, right: 10,
                              child: GestureDetector(
                                onTap: () => setModalState(() => removedUrls.add(url)),
                                child: Container(width: 20, height: 20,
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white)),
                              )),
                          ],
                        )),
                        // 새로 추가한 로컬 이미지
                        ...newImages.asMap().entries.map((e) => Stack(
                          children: [
                            Container(
                              width: 80, height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                      image: FileImage(e.value), fit: BoxFit.cover)),
                            ),
                            Positioned(top: 2, right: 10,
                              child: GestureDetector(
                                onTap: () => setModalState(() => newImages.removeAt(e.key)),
                                child: Container(width: 20, height: 20,
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white)),
                              )),
                          ],
                        )),
                        // 사진 추가 버튼 — 최대 3장
                        if (totalCount < 3)
                          GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                  maxWidth: 1200);
                              if (picked != null) {
                                setModalState(() => newImages.add(File(picked.path)));
                              }
                            },
                            child: Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                  color: ctx.subtleBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: ctx.borderColor)),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 24, color: ctx.textSecondary),
                                const SizedBox(height: 4),
                                Text('$totalCount/3', style: TextStyle(fontSize: 11, color: ctx.textSecondary)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 공개 설정
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

                // 작성/수정 버튼
                GestureDetector(
                  onTap: uploading ? null : () async {
                    if (contentCtrl.text.trim().isEmpty) return;
                    setModalState(() => uploading = true);
                    try {
                      final uid = app.authUser!.uid;
                      final userData = {
                        'name': app.userData!.name,
                        'level': app.userData!.level,
                        'character': app.userData!.character.toMap(),
                        'equippedAchievement': app.userData!.equippedAchievement,
                        'profileImageUrl': app.userData!.profileImageUrl,
                      };

                      // 새 이미지 Firebase Storage 업로드
                      final List<String> uploadedUrls = [];
                      for (final file in newImages) {
                        final ref = FirebaseStorage.instance
                            .ref('diary_images/$uid/${DateTime.now().millisecondsSinceEpoch}_${uploadedUrls.length}.jpg');
                        await ref.putFile(file);
                        uploadedUrls.add(await ref.getDownloadURL());
                      }

                      final finalUrls = [...visibleExisting, ...uploadedUrls];

                      if (editing == null) {
                        await _diaryService.addDiary(uid, userData,
                            contentCtrl.text.trim(), visibility, imageUrls: finalUrls);
                      } else {
                        await _diaryService.updateDiary(editing.id,
                            contentCtrl.text.trim(), visibility, imageUrls: finalUrls);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                      if (editing == null && mounted) {
                        await app.onDiaryWritten(_myDiaries.length);
                      }
                    } finally {
                      if (ctx.mounted) setModalState(() => uploading = false);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        color: context.primaryColor, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: uploading
                        ? SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.onPrimary))
                        : Text(editing == null ? '작성하기' : '수정하기',
                            style: TextStyle(color: context.onPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openComments(DiaryModel diary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CommentSheet(
        diary: diary, diaryService: _diaryService, onChanged: _load,
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
              indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: context.primaryColor, width: 2)),
              labelColor: context.primaryColor,
              unselectedLabelColor: context.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [Tab(text: '내 일기'), Tab(text: '친구'), Tab(text: '전체')],
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
                Text('작성', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.onPrimary)),
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
                _DiaryList(diaries: _myDiaries, myUid: myUid, onRefresh: _load,
                    onEdit: (d) => _openWriteDialog(editing: d),
                    onDelete: (d) async { await _diaryService.deleteDiary(d.id); await _load(); },
                    onComment: _openComments),
                _DiaryList(diaries: _friendDiaries, myUid: myUid, onRefresh: _load,
                    onComment: _openComments),
                _DiaryList(diaries: _publicDiaries, myUid: myUid, onRefresh: _load,
                    onEdit: (d) => _openWriteDialog(editing: d),
                    onDelete: (d) async { await _diaryService.deleteDiary(d.id); await _load(); },
                    onComment: _openComments),
              ]),
      ),
    ]);
  }
}

class _DiaryList extends StatelessWidget {
  final List<DiaryModel> diaries;
  final String myUid;
  final Future<void> Function() onRefresh;
  final void Function(DiaryModel)? onEdit;
  final Future<void> Function(DiaryModel)? onDelete;
  final void Function(DiaryModel) onComment;

  const _DiaryList({required this.diaries, required this.myUid,
      required this.onRefresh, this.onEdit, this.onDelete, required this.onComment});

  @override
  Widget build(BuildContext context) {
    if (diaries.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📔', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text('아직 일기가 없어요', style: TextStyle(fontSize: 14, color: context.textSecondary)),
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
            onTap: () => onComment(d),
          );
        },
      ),
    );
  }
}

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
    final hasImages = diary.imageUrls.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CharacterAvatar(character: diary.authorCharacter, size: 36,
                profileImageUrl: diary.authorProfileImageUrl),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(diary.authorName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
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
            if (isMe) ...[
              if (onEdit != null) GestureDetector(
                onTap: onEdit, behavior: HitTestBehavior.opaque,
                child: Padding(padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 18, color: context.textSecondary))),
              const SizedBox(width: 6),
              if (onDelete != null) GestureDetector(
                onTap: onDelete, behavior: HitTestBehavior.opaque,
                child: Padding(padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 18, color: context.textSecondary))),
            ],
          ]),
          const SizedBox(height: 10),
          Text(diary.content, style: TextStyle(fontSize: 14, color: context.textPrimary, height: 1.5),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          if (hasImages) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: diary.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(diary.imageUrls[i], width: 100, height: 100, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(diary.visibilityLabel, style: TextStyle(fontSize: 11, color: context.textSecondary)),
            Row(children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: context.textSecondary),
              const SizedBox(width: 4),
              Text('${diary.commentCount}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const SizedBox(width: 12),
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

class _TitleChip extends StatelessWidget {
  final Achievement achievement;
  const _TitleChip({required this.achievement});
  @override
  Widget build(BuildContext context) {
    final dc = Color(Achievements.difficultyColor[achievement.difficulty]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: dc.withOpacity(0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: dc.withOpacity(0.3))),
      child: Text(achievement.title, style: TextStyle(fontSize: 10, color: dc, fontWeight: FontWeight.w600)),
    );
  }
}

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
  late bool _likedByMe;
  late int _likeCount;
  late int _commentCount;
  String? _replyingToCommentId;
  String? _replyingToName;
  String? _replyingToAuthorUid;
  String? _replyingToContent;
  final _replyCtrl = TextEditingController();
  int? _fullscreenImageIdx;

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
      if (mounted) setState(() =>
          _commentCount = _comments.fold(0, (s, c) => s + 1 + c.replies.length));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final app = context.read<AppProvider>();
    final myUid = app.authUser!.uid;
    setState(() { _likedByMe = !_likedByMe; _likeCount += _likedByMe ? 1 : -1; });
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
    setState(() { _replyingToCommentId = null; _replyingToName = null; _replyingToAuthorUid = null; _replyingToContent = null; });
    _replyCtrl.clear();
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty || _sending) return;
    final app = context.read<AppProvider>();
    setState(() => _sending = true);
    try {
      await widget.diaryService.addComment(widget.diary.id, {
        'uid': app.authUser!.uid, 'name': app.userData!.name,
        'character': app.userData!.character.toMap(),
        'equippedAchievement': app.userData!.equippedAchievement,
        'profileImageUrl': app.userData!.profileImageUrl,
      }, _commentCtrl.text.trim());
      _commentCtrl.clear();
      await _load();
      widget.onChanged();
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _submitReply() async {
    if (_replyCtrl.text.trim().isEmpty || _sending || _replyingToCommentId == null) return;
    final app = context.read<AppProvider>();
    setState(() => _sending = true);
    try {
      await widget.diaryService.addReply(
        widget.diary.id, _replyingToCommentId!,
        {'uid': app.authUser!.uid, 'name': app.userData!.name,
         'character': app.userData!.character.toMap(),
         'equippedAchievement': app.userData!.equippedAchievement,
         'profileImageUrl': app.userData!.profileImageUrl},
        _replyCtrl.text.trim(),
        commentAuthorUid: _replyingToAuthorUid,
        commentContent: _replyingToContent,
      );
      _replyCtrl.clear();
      _cancelReply();
      await _load();
      widget.onChanged();
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    await widget.diaryService.deleteComment(widget.diary.id, comment.id, comment.replyCount);
    await _load(); widget.onChanged();
  }

  Future<void> _deleteReply(String commentId, String replyId) async {
    await widget.diaryService.deleteReply(widget.diary.id, commentId, replyId);
    await _load(); widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AppProvider>().authUser!.uid;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    final isReplying = _replyingToCommentId != null;
    final achievement = widget.diary.authorEquippedAchievement != null
        ? Achievements.findById(widget.diary.authorEquippedAchievement!) : null;
    final hasImages = widget.diary.imageUrls.isNotEmpty;

    return Stack(children: [
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('일기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CharacterAvatar(character: widget.diary.authorCharacter, size: 38,
                        profileImageUrl: widget.diary.authorProfileImageUrl),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.diary.authorName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      if (achievement != null) ...[
                        const SizedBox(height: 2), _TitleChip(achievement: achievement), const SizedBox(height: 2),
                      ],
                      Row(children: [
                        Text('Lv.${widget.diary.authorLevel}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                        const SizedBox(width: 6),
                        Text('·', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                        const SizedBox(width: 6),
                        Text(widget.diary.timeAgo, style: TextStyle(fontSize: 11, color: context.textSecondary)),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Text(widget.diary.content, style: TextStyle(fontSize: 15, color: context.textPrimary, height: 1.6)),
                  if (hasImages) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.diary.imageUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => setState(() => _fullscreenImageIdx = i),
                          child: ClipRRect(borderRadius: BorderRadius.circular(10),
                              child: Image.network(widget.diary.imageUrls[i], width: 180, height: 180, fit: BoxFit.cover)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _likedByMe ? AppTheme.danger.withOpacity(0.1) : context.subtleBg,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _likedByMe ? AppTheme.danger.withOpacity(0.3) : context.borderColor)),
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
                      decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: context.borderColor)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 15, color: context.textSecondary),
                        const SizedBox(width: 5),
                        Text('$_commentCount', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                ]),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('댓글 $_commentCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
              ),
              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
              else if (_comments.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('💬', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    Text('첫 댓글을 남겨보세요!', style: TextStyle(fontSize: 14, color: context.textSecondary)),
                  ])))
              else
                ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = _comments[i];
                    return _CommentItem(
                      comment: c, myUid: myUid,
                      isReplyingToThis: _replyingToCommentId == c.id,
                      onReply: () => _startReply(c.id, c.authorName, c.uid, c.content),
                      onDelete: () => _deleteComment(c),
                      onDeleteReply: (rId) => _deleteReply(c.id, rId),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ]),
          ),
          const Divider(height: 1),
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
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 10),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isReplying ? context.primaryColor : context.borderColor)),
                  child: TextField(
                    controller: isReplying ? _replyCtrl : _commentCtrl,
                    maxLines: 1, maxLength: 200,
                    style: TextStyle(fontSize: 14, color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: isReplying ? '답글을 입력하세요...' : '댓글을 입력하세요...',
                      hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                      border: InputBorder.none, counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
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
      ),

      // 이미지 전체화면 오버레이
      if (_fullscreenImageIdx != null)
        GestureDetector(
          onTap: () => setState(() => _fullscreenImageIdx = null),
          child: Container(
            color: Colors.black87,
            child: SafeArea(child: Stack(children: [
              Center(child: InteractiveViewer(
                  child: Image.network(widget.diary.imageUrls[_fullscreenImageIdx!]))),
              Positioned(top: 12, right: 12,
                child: GestureDetector(
                  onTap: () => setState(() => _fullscreenImageIdx = null),
                  child: Container(width: 36, height: 36,
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 18)))),
              if (widget.diary.imageUrls.length > 1)
                Positioned(bottom: 20, left: 0, right: 0,
                  child: Center(child: Text(
                    '${_fullscreenImageIdx! + 1} / ${widget.diary.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)))),
            ])),
          ),
        ),
    ]);
  }
}

class _CommentItem extends StatelessWidget {
  final CommentModel comment;
  final String myUid;
  final bool isReplyingToThis;
  final VoidCallback onReply, onDelete;
  final void Function(String replyId) onDeleteReply;

  const _CommentItem({required this.comment, required this.myUid,
      required this.isReplyingToThis, required this.onReply,
      required this.onDelete, required this.onDeleteReply});

  @override
  Widget build(BuildContext context) {
    final isMyComment = comment.uid == myUid;
    final achievement = comment.authorEquippedAchievement != null
        ? Achievements.findById(comment.authorEquippedAchievement!) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CharacterAvatar(character: comment.authorCharacter, size: 34,
              profileImageUrl: comment.authorProfileImageUrl),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(comment.authorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
              if (achievement != null) ...[const SizedBox(width: 6), _TitleChip(achievement: achievement)],
              const SizedBox(width: 6),
              Text(comment.timeAgo, style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ]),
            const SizedBox(height: 4),
            Text(comment.content, style: TextStyle(fontSize: 14, color: context.textPrimary, height: 1.4)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onReply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReplyingToThis ? context.primaryColor.withOpacity(0.1) : context.subtleBg,
                  borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.reply, size: 13, color: isReplyingToThis ? context.primaryColor : context.textSecondary),
                  const SizedBox(width: 3),
                  Text('답글', style: TextStyle(fontSize: 12, color: isReplyingToThis ? context.primaryColor : context.textSecondary)),
                ]),
              ),
            ),
          ])),
          if (isMyComment)
            GestureDetector(onTap: onDelete,
                child: Padding(padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Icon(Icons.delete_outline, size: 16, color: context.textSecondary))),
        ]),
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
                  Container(width: 2, height: 34, margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(1))),
                  CharacterAvatar(character: r.authorCharacter, size: 28, profileImageUrl: r.authorProfileImageUrl),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Text(r.authorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      if (replyAchievement != null) ...[const SizedBox(width: 5), _TitleChip(achievement: replyAchievement)],
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