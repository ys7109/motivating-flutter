import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';

const _skins = [
  {'id': 'default', 'label': '기본', 'emoji': '🧑', 'lv': 1},
  {'id': 'warrior', 'label': '전사', 'emoji': '⚔️', 'lv': 3},
  {'id': 'scholar', 'label': '학자', 'emoji': '📚', 'lv': 6},
  {'id': 'explorer', 'label': '탐험가', 'emoji': '🧭', 'lv': 10},
  {'id': 'legend', 'label': '전설', 'emoji': '🌟', 'lv': 20},
];
const _badges = [
  {'id': 'none', 'label': '없음', 'emoji': '—', 'lv': 1},
  {'id': 'flame', 'label': '열정', 'emoji': '🔥', 'lv': 2},
  {'id': 'lightning', 'label': '집중', 'emoji': '⚡', 'lv': 5},
  {'id': 'crown', 'label': '왕관', 'emoji': '👑', 'lv': 12},
  {'id': 'diamond', 'label': '다이아', 'emoji': '💎', 'lv': 18},
];
const _frames = [
  {'id': 'none', 'label': '없음', 'color': 0xFFE0E0E0, 'lv': 1},
  {'id': 'silver', 'label': '실버', 'color': 0xFF9e9e9e, 'lv': 4},
  {'id': 'gold', 'label': '골드', 'color': 0xFFf9a825, 'lv': 8},
  {'id': 'rainbow', 'label': '무지개', 'color': 0xFFe040fb, 'lv': 15},
];
const _roadmap = [
  {'lv': 3, 'reward': '전사 스킨 해금'},
  {'lv': 5, 'reward': '⚡ 집중 뱃지 해금'},
  {'lv': 8, 'reward': '🥈 실버 프레임 해금'},
  {'lv': 10, 'reward': '탐험가 스킨 해금'},
  {'lv': 12, 'reward': '👑 왕관 뱃지 해금'},
  {'lv': 15, 'reward': '🌈 무지개 프레임 해금'},
  {'lv': 20, 'reward': '🌟 전설 스킨 해금'},
];

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  String _tab = 'skin';
  bool _shopModal = false;
  bool _editName = false;
  late TextEditingController _nameCtrl;
  bool _nameSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    if (userData == null) return const SizedBox();

    final level = userData.level;
    final character = userData.character;
    final activeSkin = character.skin;
    final activeBadge = character.badge;
    final activeFrame = character.frame;
    final currentSkin = _skins.firstWhere((s) => s['id'] == activeSkin, orElse: () => _skins[0]);
    final currentBadge = _badges.firstWhere((b) => b['id'] == activeBadge, orElse: () => _badges[0]);
    final items = _tab == 'skin' ? _skins : _tab == 'badge' ? _badges : _frames;
    final activeId = _tab == 'skin' ? activeSkin : _tab == 'badge' ? activeBadge : activeFrame;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  // 헤더
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('마이', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        Row(children: [
                          _IconBtn(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MailboxScreen())),
                            child: Stack(clipBehavior: Clip.none, children: [
                              const Text('📬', style: TextStyle(fontSize: 18)),
                              if (app.unreadMailCount > 0)
                                Positioned(top: -4, right: -6, child: Container(
                                  width: 16, height: 16,
                                  decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                                  child: Center(child: Text('${app.unreadMailCount > 9 ? '9+' : app.unreadMailCount}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                                )),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                            child: const Text('⚙️', style: TextStyle(fontSize: 18)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 부활 아이템
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Text('🛡️', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('부활 아이템', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Text('${userData.reviveItem}개 보유', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            ]),
                          ]),
                          GestureDetector(
                            onTap: () => setState(() => _shopModal = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(99)),
                              child: const Text('+ 구매', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 캐릭터 미리보기
                  Column(children: [
                    Stack(children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeFrame == 'none' ? const Color(0xFFF0F0F0) : Color(_frames.firstWhere((f) => f['id'] == activeFrame, orElse: () => _frames[0])['color'] as int),
                        ),
                        child: Center(
                          child: Container(
                            width: 82, height: 82,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            child: Center(child: Text(currentSkin['emoji'] as String, style: const TextStyle(fontSize: 40))),
                          ),
                        ),
                      ),
                      if (activeBadge != 'none')
                        Positioned(bottom: 2, right: 2, child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: AppTheme.border)),
                          child: Center(child: Text(currentBadge['emoji'] as String, style: const TextStyle(fontSize: 14))),
                        )),
                    ]),
                    const SizedBox(height: 10),
                    if (_editName)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _nameCtrl,
                            maxLength: 12,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(counterText: '', isDense: true, border: UnderlineInputBorder()),
                            onSubmitted: (_) => _saveName(app),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _nameSaving ? null : () => _saveName(app),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(99)),
                            child: Text(_nameSaving ? '...' : '저장', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _editName = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(99)),
                            child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ),
                        ),
                      ])
                    else
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${userData.name.split(' ').first} 님', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () { _nameCtrl.text = userData.name; setState(() => _editName = true); },
                          child: const Text('✏️', style: TextStyle(fontSize: 13)),
                        ),
                      ]),
                    const SizedBox(height: 4),
                    Text('Lv.$level · ${app.levelTitle(level)}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 20),

                  // 탭
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: ['skin','badge','frame'].asMap().entries.map((e) {
                        final labels = ['스킨','뱃지','프레임'];
                        final isActive = _tab == e.value;
                        return GestureDetector(
                          onTap: () => setState(() => _tab = e.value),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primary : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(labels[e.key], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isActive ? Colors.white : AppTheme.textSecondary)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 아이템 그리드
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.9,
                      children: items.map((item) {
                        final unlocked = level >= (item['lv'] as int);
                        final isActive = activeId == item['id'];
                        return GestureDetector(
                          onTap: () { if (unlocked) app.updateCharacter({_tab: item['id']}); },
                          child: Opacity(
                            opacity: unlocked ? 1.0 : 0.5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isActive ? AppTheme.primary : unlocked ? Colors.white : const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isActive ? AppTheme.primary : AppTheme.border, width: isActive ? 2 : 1),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                if (_tab == 'frame')
                                  Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(item['color'] as int)))
                                else
                                  Text(item['emoji'] as String, style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 6),
                                Text(item['label'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? Colors.white : AppTheme.textPrimary)),
                                if (!unlocked)
                                  Text('Lv.${item['lv']}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary))
                                else if (isActive)
                                  const Text('착용 중', style: TextStyle(fontSize: 10, color: Colors.white70)),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 레벨 보상 로드맵
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('레벨 보상 로드맵', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        ..._roadmap.map((r) {
                          final lv = r['lv'] as int;
                          final unlocked = level >= lv;
                          return Opacity(
                            opacity: unlocked ? 1.0 : 0.5,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border, width: 0.5),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: unlocked ? AppTheme.primary : const Color(0xFFF0F0F0)),
                                  child: Center(child: unlocked
                                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                                    : Text('$lv', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
                                ),
                                const SizedBox(width: 12),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r['reward'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                                  Text('레벨 $lv 달성 시', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ]),
                                if (unlocked) ...[
                                  const Spacer(),
                                  const Text('해금됨', style: TextStyle(fontSize: 12, color: Color(0xFF1b8a5a), fontWeight: FontWeight.w500)),
                                ],
                              ]),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 구매 모달
          if (_shopModal)
            _ShopModal(onClose: () => setState(() => _shopModal = false)),
        ],
      ),
    );
  }

  Future<void> _saveName(AppProvider app) async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _nameSaving = true);
    await app.updateName(_nameCtrl.text.trim());
    if (mounted) setState(() { _nameSaving = false; _editName = false; });
  }
}

class _IconBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _IconBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(99)),
        child: child,
      ),
    );
  }
}

class _ShopModal extends StatelessWidget {
  final VoidCallback onClose;
  const _ShopModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🛡️ 부활 아이템 구매', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('스트릭이 끊겼을 때 1회 복구할 수 있는 아이템입니다.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
                  const SizedBox(height: 20),
                  ...[
                    {'count': 1, 'price': '₩1,100', 'label': '기본', 'highlight': false},
                    {'count': 3, 'price': '₩2,900', 'label': '추천', 'highlight': true},
                    {'count': 10, 'price': '₩7,900', 'label': '최대 할인', 'highlight': false},
                  ].map((item) => GestureDetector(
                    onTap: () { showDialog(context: context, builder: (_) => const AlertDialog(content: Text('결제 시스템 준비 중입니다.'))); },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: item['highlight'] == true ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: item['highlight'] == true ? AppTheme.primary : AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Text('🛡️ × ${item['count']}', style: TextStyle(fontSize: 20, color: item['highlight'] == true ? Colors.white : AppTheme.textPrimary)),
                            const SizedBox(width: 10),
                            Text(item['label'] as String, style: TextStyle(fontSize: 12, color: item['highlight'] == true ? Colors.white70 : AppTheme.textSecondary)),
                          ]),
                          Text(item['price'] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: item['highlight'] == true ? Colors.white : AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  )),
                  const Text('결제는 앱스토어 정책에 따라 처리됩니다.\n구매한 아이템은 환불되지 않습니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFFBDBDBD), height: 1.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 우편함 & 설정 화면은 Navigator.push로 이동 ──
class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});
  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  String? _selected;
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final mailbox = app.mailbox;
    final unread = mailbox.where((m) => !m.read).length;
    final unclaimed = mailbox.where((m) => !m.claimed).length;

    const typeIcon = {'attendance': '📅', 'attendance_special': '🎁', 'admin': '📣'};
    const typeLabel = {'attendance': '출석 보상', 'attendance_special': '특별 보상', 'admin': '관리자 지급'};

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios, size: 18, color: AppTheme.textSecondary)),
                const SizedBox(width: 12),
                const Text('우편함', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(99)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () async { setState(() => _refreshing = true); await app.loadMailbox(); setState(() => _refreshing = false); },
                  child: Text(_refreshing ? '새로고침 중...' : '새로고침', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ]),
            ),
            if (unclaimed > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8E1), border: Border.all(color: const Color(0xFFFFE082)), borderRadius: BorderRadius.circular(12)),
                  child: Text('📬 수령 가능한 보상이 $unclaimed개 있어요!', style: const TextStyle(fontSize: 13, color: Color(0xFFc47f00))),
                ),
              ),
            Expanded(
              child: mailbox.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('📭', style: TextStyle(fontSize: 32)),
                    SizedBox(height: 12),
                    Text('우편함이 비어있어요', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: mailbox.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final mail = mailbox[i];
                      final isSelected = _selected == mail.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = isSelected ? null : mail.id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: !mail.read ? AppTheme.primary : AppTheme.border, width: !mail.read ? 1.5 : 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(typeIcon[mail.type] ?? '📬', style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    if (!mail.read) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.danger)),
                                    Expanded(child: Text(mail.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(typeLabel[mail.type] ?? '보상', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ])),
                                if (!mail.claimed)
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(99)),
                                    child: const Text('수령 가능', style: TextStyle(fontSize: 11, color: Color(0xFF2e7d32), fontWeight: FontWeight.w500)))
                                else
                                  const Text('수령 완료', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ]),
                              if (isSelected) ...[
                                const SizedBox(height: 14),
                                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                                const SizedBox(height: 14),
                                Text(mail.body, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.7)),
                                if (mail.reward.xp > 0 || mail.reward.reviveItem > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(10)),
                                    child: Row(children: [
                                      if (mail.reward.xp > 0) Column(children: [
                                        Text('+${mail.reward.xp}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                        const Text('XP', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ]),
                                      if (mail.reward.reviveItem > 0) ...[
                                        const SizedBox(width: 16),
                                        Column(children: [
                                          Text('🛡️ +${mail.reward.reviveItem}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                          const Text('부활 아이템', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        ]),
                                      ],
                                    ]),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(children: [
                                  if (!mail.claimed)
                                    Expanded(child: GestureDetector(
                                      onTap: () { app.claimMailReward(mail.id); setState(() => _selected = null); },
                                      child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                                        child: const Center(child: Text('보상 수령', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)))),
                                    )),
                                  if (!mail.claimed) const SizedBox(width: 8),
                                  Expanded(child: GestureDetector(
                                    onTap: () { app.deleteMailItem(mail.id); setState(() => _selected = null); },
                                    child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(10)),
                                      child: const Center(child: Text('삭제', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)))),
                                  )),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _logoutModal = false;
  bool _withdrawModal = false;
  bool _cancelModal = false;
  Map<String, bool> _notif = {'goal': true, 'streak': true, 'mail': true};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final withdrawPending = app.userData?.withdrawScheduledAt != null;
    final withdrawDate = app.userData?.withdrawScheduledAt;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(children: [
                      GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios, size: 18, color: AppTheme.textSecondary)),
                      const SizedBox(width: 12),
                      const Text('설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  if (withdrawPending)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3F3), border: Border.all(color: const Color(0xFFFFCDD2)), borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('⚠️ 탈퇴 예정 계정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.danger)),
                          const SizedBox(height: 4),
                          Text('${withdrawDate?.month}월 ${withdrawDate?.day}일에 탈퇴가 진행됩니다.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.6)),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => setState(() => _cancelModal = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: AppTheme.danger), borderRadius: BorderRadius.circular(99)),
                              child: const Text('탈퇴 취소하기', style: TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  _Section(title: '알림', children: [
                    _ToggleItem(label: '목표 리마인더', sub: '매일 아침 9시', value: _notif['goal']!, onChange: () => setState(() => _notif['goal'] = !_notif['goal']!)),
                    _ToggleItem(label: '스트릭 위기 알림', sub: '매일 저녁 8시', value: _notif['streak']!, onChange: () => setState(() => _notif['streak'] = !_notif['streak']!)),
                    _ToggleItem(label: '우편함 알림', sub: '새 보상 도착 시', value: _notif['mail']!, onChange: () => setState(() => _notif['mail'] = !_notif['mail']!)),
                  ]),
                  _Section(title: '앱 정보', children: [
                    const _InfoItem(label: '버전', value: '1.0.0'),
                    _InfoItem(label: '빌드', value: DateTime.now().toString().substring(0, 10).replaceAll('-', '.')),
                  ]),
                  _Section(title: '계정', children: [
                    _LinkItem(label: '로그아웃', danger: true, onTap: () => setState(() => _logoutModal = true)),
                    _LinkItem(label: '회원 탈퇴', danger: true, onTap: () => setState(() => _withdrawModal = true)),
                  ]),
                ],
              ),
            ),
          ),
          if (_logoutModal)
            _ConfirmModal(
              title: '로그아웃',
              body: '로그아웃 하시겠습니까?',
              confirmLabel: '로그아웃',
              onCancel: () => setState(() => _logoutModal = false),
              onConfirm: () async { setState(() => _logoutModal = false); await app.signOut(); },
            ),
          if (_withdrawModal)
            _WithdrawModal(
              onCancel: () => setState(() => _withdrawModal = false),
              onConfirm: () async {
                setState(() => _withdrawModal = false);
                final uid = app.authUser?.uid;
                if (uid == null) return;
                final scheduleDate = DateTime.now().add(const Duration(days: 30));
                await app.signOut();
              },
            ),
          if (_cancelModal)
            _ConfirmModal(
              title: '탈퇴 취소',
              body: '탈퇴 신청을 취소하시겠습니까?',
              confirmLabel: '탈퇴 취소',
              onCancel: () => setState(() => _cancelModal = false),
              onConfirm: () async {
                setState(() => _cancelModal = false);
                final uid = app.authUser?.uid;
                if (uid == null) return;
                await FirestoreService().updateUser(uid, {'withdrawScheduledAt': null});
                await app.init();
              },
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
      ),
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Column(children: children),
      ),
    ]);
  }
}

class _ToggleItem extends StatelessWidget {
  final String label, sub;
  final bool value;
  final VoidCallback onChange;
  const _ToggleItem({required this.label, required this.sub, required this.value, required this.onChange});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
          Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
        GestureDetector(
          onTap: onChange,
          child: Container(
            width: 44, height: 26,
            decoration: BoxDecoration(color: value ? AppTheme.primary : const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(99)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(margin: const EdgeInsets.all(3), width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LinkItem extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _LinkItem({required this.label, this.danger = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 15, color: danger ? AppTheme.danger : AppTheme.textPrimary)),
          const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD), size: 18),
        ]),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  const _InfoItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
        Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

class _ConfirmModal extends StatelessWidget {
  final String title, body, confirmLabel;
  final VoidCallback onCancel, onConfirm;
  const _ConfirmModal({required this.title, required this.body, required this.confirmLabel, required this.onCancel, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black54, child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: GestureDetector(onTap: onCancel, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('취소', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(onTap: onConfirm, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)))))),
        ]),
      ]),
    ))));
  }
}

class _WithdrawModal extends StatelessWidget {
  final VoidCallback onCancel, onConfirm;
  const _WithdrawModal({required this.onCancel, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black54, child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('⚠️', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        const Text('회원 탈퇴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('탈퇴 신청 후 30일 유예기간이 적용됩니다.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
          child: const Text('• 30일 후 모든 데이터가 영구 삭제돼요\n• 삭제된 데이터는 복구할 수 없어요\n• 유예기간 중 재로그인하여 취소할 수 있어요',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.7))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: GestureDetector(onTap: onCancel, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('취소', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(onTap: onConfirm, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('탈퇴 신청', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)))))),
        ]),
      ]),
    ))));
  }
}