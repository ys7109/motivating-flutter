import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/diary_service.dart';
import '../../services/friend_service.dart';
import '../../models/diary_model.dart';
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
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // social_screen에서 외부 호출 가능
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
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(editing == null ? '다이어리 작성' : '다이어리 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: context.surfaceColor, border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: contentCtrl,
                maxLines: 6,
                style: TextStyle(fontSize: 14, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: '오늘 하루를 기록해보세요...',
                  hintStyle: TextStyle(color: context.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('공개 설정', style: TextStyle(fontSize: 13, color: context.textSecondary)),
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
                    color: isSelected ? context.primaryColor : context.subtleBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(v[1], style: TextStyle(fontSize: 12, color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                if (contentCtrl.text.trim().isEmpty) return;
                final uid = app.authUser!.uid;
                final userData = {'name': app.userData!.name, 'level': app.userData!.level, 'character': app.userData!.character.toMap()};
                if (editing == null) {
                  await _diaryService.addDiary(uid, userData, contentCtrl.text.trim(), visibility);
                } else {
                  await _diaryService.updateDiary(editing.id, contentCtrl.text.trim(), visibility);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(editing == null ? '작성하기' : '수정하기', style: TextStyle(color: context.isDark ? Colors.black : Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
              ),
            ),
          ]),
        ),
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
              tabs: const [Tab(text: '내 다이어리'), Tab(text: '친구'), Tab(text: '전체')],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openWriteDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_outlined, size: 14, color: context.isDark ? Colors.black : Colors.white),
                const SizedBox(width: 4),
                Text('작성', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.isDark ? Colors.black : Colors.white)),
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
                RefreshIndicator(
                  onRefresh: _load,
                  color: context.primaryColor,
                  child: _myDiaries.isEmpty
                      ? const _EmptyDiary(message: '아직 작성한 다이어리가 없어요')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _myDiaries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _DiaryCard(
                            diary: _myDiaries[i], isMe: true,
                            onEdit: () => _openWriteDialog(editing: _myDiaries[i]),
                            onDelete: () async { await _diaryService.deleteDiary(_myDiaries[i].id); await _load(); },
                          ),
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  color: context.primaryColor,
                  child: _friendDiaries.isEmpty
                      ? const _EmptyDiary(message: '친구의 공개 다이어리가 없어요')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _friendDiaries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _DiaryCard(
                            diary: _friendDiaries[i], isMe: false,
                            onLike: () async { await _diaryService.toggleLike(myUid, _friendDiaries[i].id); await _load(); },
                          ),
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  color: context.primaryColor,
                  child: _publicDiaries.isEmpty
                      ? const _EmptyDiary(message: '전체 공개 다이어리가 없어요')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _publicDiaries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final diary = _publicDiaries[i];
                            final isMine = diary.uid == myUid;
                            return _DiaryCard(
                              diary: diary, isMe: isMine,
                              onLike: isMine ? null : () async { await _diaryService.toggleLike(myUid, diary.id); await _load(); },
                              onEdit: isMine ? () => _openWriteDialog(editing: diary) : null,
                              onDelete: isMine ? () async { await _diaryService.deleteDiary(diary.id); await _load(); } : null,
                            );
                          },
                        ),
                ),
              ]),
      ),
    ]);
  }
}

class _DiaryCard extends StatelessWidget {
  final DiaryModel diary;
  final bool isMe;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  const _DiaryCard({required this.diary, required this.isMe, this.onEdit, this.onDelete, this.onLike});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CharacterAvatar(character: diary.authorCharacter, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(diary.authorName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
            Row(children: [
              Text('Lv.${diary.authorLevel}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
              const SizedBox(width: 6),
              Text('·', style: TextStyle(fontSize: 11, color: context.textSecondary)),
              const SizedBox(width: 6),
              Text(diary.timeAgo, style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ]),
          ])),
          if (isMe) ...[
            if (onEdit != null) GestureDetector(onTap: onEdit, child: Icon(Icons.edit_outlined, size: 18, color: context.textSecondary)),
            const SizedBox(width: 10),
            if (onDelete != null) GestureDetector(onTap: onDelete, child: Icon(Icons.delete_outline, size: 18, color: context.textSecondary)),
          ],
        ]),
        const SizedBox(height: 10),
        Text(diary.content, style: TextStyle(fontSize: 14, color: context.textPrimary, height: 1.5)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(diary.visibilityLabel, style: TextStyle(fontSize: 11, color: context.textSecondary)),
          if (onLike != null)
            GestureDetector(
              onTap: onLike,
              child: Row(children: [
                Icon(diary.likedByMe ? Icons.favorite : Icons.favorite_border, size: 16, color: diary.likedByMe ? AppTheme.danger : context.textSecondary),
                const SizedBox(width: 4),
                Text('${diary.likeCount}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _EmptyDiary extends StatelessWidget {
  final String message;
  const _EmptyDiary({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('📔', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text(message, style: TextStyle(fontSize: 14, color: context.textSecondary)),
    ]));
  }
}