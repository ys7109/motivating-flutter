import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../utils/transitions.dart';
import '../../providers/app_provider.dart';
import 'mailbox_screen.dart';
import 'settings_screen.dart';

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
    final currentSkin = _skins.firstWhere(
        (s) => s['id'] == activeSkin, orElse: () => _skins[0]);
    final currentBadge = _badges.firstWhere(
        (b) => b['id'] == activeBadge, orElse: () => _badges[0]);
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
                        const Text('마이',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        Row(children: [
                          _IconBtn(
                            onTap: () => Navigator.push(context,
                                SlideRightRoute(page: const MailboxScreen())),
                            child: Stack(clipBehavior: Clip.none, children: [
                              const Text('📬', style: TextStyle(fontSize: 18)),
                              if (app.unreadMailCount > 0)
                                Positioned(
                                    top: -4, right: -6,
                                    child: Container(
                                      width: 16, height: 16,
                                      decoration: const BoxDecoration(
                                          color: AppTheme.danger,
                                          shape: BoxShape.circle),
                                      child: Center(
                                          child: Text(
                                            '${app.unreadMailCount > 9 ? '9+' : app.unreadMailCount}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold),
                                          )),
                                    )),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            onTap: () => Navigator.push(context,
                                SlideRightRoute(page: const SettingsScreen())),
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
                      decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Text('🛡️', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('부활 아이템',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              Text('${userData.reviveItem}개 보유',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                            ]),
                          ]),
                          GestureDetector(
                            onTap: () => setState(() => _shopModal = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(99)),
                              child: const Text('+ 구매',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
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
                          color: activeFrame == 'none'
                              ? const Color(0xFFF0F0F0)
                              : Color(_frames.firstWhere(
                                      (f) => f['id'] == activeFrame,
                                      orElse: () => _frames[0])['color'] as int),
                        ),
                        child: Center(
                          child: Container(
                            width: 82, height: 82,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.white),
                            child: Center(
                                child: Text(currentSkin['emoji'] as String,
                                    style: const TextStyle(fontSize: 40))),
                          ),
                        ),
                      ),
                      if (activeBadge != 'none')
                        Positioned(
                            bottom: 2, right: 2,
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: AppTheme.border)),
                              child: Center(
                                  child: Text(currentBadge['emoji'] as String,
                                      style: const TextStyle(fontSize: 14))),
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
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                                counterText: '',
                                isDense: true,
                                border: UnderlineInputBorder()),
                            onSubmitted: (_) => _saveName(app),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _nameSaving ? null : () => _saveName(app),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(99)),
                            child: Text(_nameSaving ? '...' : '저장',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _editName = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(99)),
                            child: const Text('취소',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ),
                        ),
                      ])
                    else
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${userData.name.split(' ').first} 님',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            _nameCtrl.text = userData.name;
                            setState(() => _editName = true);
                          },
                          child: const Text('✏️',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ]),
                    const SizedBox(height: 4),
                    Text('Lv.$level · ${app.levelTitle(level)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 20),

                  // 탭
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: ['skin', 'badge', 'frame'].asMap().entries.map((e) {
                        final labels = ['스킨', '뱃지', '프레임'];
                        final isActive = _tab == e.value;
                        return GestureDetector(
                          onTap: () => setState(() => _tab = e.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 7),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.primary
                                  : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(labels[e.key],
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? Colors.white
                                        : AppTheme.textSecondary)),
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
                          onTap: () {
                            if (unlocked) app.updateCharacter({_tab: item['id']});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.primary
                                  : unlocked
                                      ? Colors.white
                                      : const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isActive
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                  width: isActive ? 2 : 1),
                            ),
                            child: Opacity(
                              opacity: unlocked ? 1.0 : 0.5,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_tab == 'frame')
                                      Container(
                                          width: 34, height: 34,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(item['color'] as int)))
                                    else
                                      Text(item['emoji'] as String,
                                          style: const TextStyle(fontSize: 26)),
                                    const SizedBox(height: 6),
                                    Text(item['label'] as String,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isActive
                                                ? Colors.white
                                                : AppTheme.textPrimary)),
                                    if (!unlocked)
                                      Text('Lv.${item['lv']}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.textSecondary))
                                    else if (isActive)
                                      const Text('착용 중',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70)),
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
                        const Text('레벨 보상 로드맵',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        ..._roadmap.map((r) {
                          final lv = r['lv'] as int;
                          final unlocked = level >= lv;
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: unlocked ? 1.0 : 0.5,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppTheme.border, width: 0.5),
                              ),
                              child: Row(children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: unlocked
                                          ? AppTheme.primary
                                          : const Color(0xFFF0F0F0)),
                                  child: Center(
                                      child: unlocked
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 14)
                                          : Text('$lv',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                  fontWeight: FontWeight.w500))),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r['reward'] as String,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary)),
                                      Text('레벨 $lv 달성 시',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary)),
                                    ]),
                                if (unlocked) ...[
                                  const Spacer(),
                                  const Text('해금됨',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1b8a5a),
                                          fontWeight: FontWeight.w500)),
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
        decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(99)),
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
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🛡️ 부활 아이템 구매',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('스트릭이 끊겼을 때 1회 복구할 수 있는 아이템입니다.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.6)),
                    const SizedBox(height: 20),
                    ...[
                      {'count': 1, 'price': '₩1,100', 'label': '기본', 'highlight': false},
                      {'count': 3, 'price': '₩2,900', 'label': '추천', 'highlight': true},
                      {'count': 10, 'price': '₩7,900', 'label': '최대 할인', 'highlight': false},
                    ].map((item) => GestureDetector(
                          onTap: () => showDialog(
                              context: context,
                              builder: (_) => const AlertDialog(
                                  content: Text('결제 시스템 준비 중입니다.'))),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: item['highlight'] == true
                                  ? AppTheme.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: item['highlight'] == true
                                      ? AppTheme.primary
                                      : AppTheme.border),
                            ),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [
                                    Text('🛡️ × ${item['count']}',
                                        style: TextStyle(
                                            fontSize: 20,
                                            color: item['highlight'] == true
                                                ? Colors.white
                                                : AppTheme.textPrimary)),
                                    const SizedBox(width: 10),
                                    Text(item['label'] as String,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: item['highlight'] == true
                                                ? Colors.white70
                                                : AppTheme.textSecondary)),
                                  ]),
                                  Text(item['price'] as String,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: item['highlight'] == true
                                              ? Colors.white
                                              : AppTheme.textPrimary)),
                                ]),
                          ),
                        )),
                    const Text(
                        '결제는 앱스토어 정책에 따라 처리됩니다.\n구매한 아이템은 환불되지 않습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFBDBDBD),
                            height: 1.6)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}