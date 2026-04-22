import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../providers/app_provider.dart';

class StreakModal extends StatefulWidget {
  final String type; // 'milestone' | 'broken'
  final VoidCallback onClose;
  const StreakModal({super.key, required this.type, required this.onClose});

  @override
  State<StreakModal> createState() => _StreakModalState();
}

class _StreakModalState extends State<StreakModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _watchingAd = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    if (userData == null) return const SizedBox();

    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ScaleTransition(
            scale: _scaleAnim,
            child: widget.type == 'milestone'
                ? _MilestoneContent(userData: userData, onClose: widget.onClose, app: app)
                : _BrokenContent(userData: userData, onClose: widget.onClose, app: app,
                    watchingAd: _watchingAd, onWatchAd: () async {
                      setState(() => _watchingAd = true);
                      await Future.delayed(const Duration(seconds: 3));
                      if (mounted) {
                        setState(() => _watchingAd = false);
                        await app.reviveStreakByAd();
                        widget.onClose();
                      }
                    }),
          ),
        ),
      ),
    );
  }
}

class _MilestoneContent extends StatelessWidget {
  final dynamic userData;
  final VoidCallback onClose;
  final AppProvider app;
  const _MilestoneContent({required this.userData, required this.onClose, required this.app});

  @override
  Widget build(BuildContext context) {
    final streak = userData.streak as int;
    final milestone = app.currentMilestone;
    if (milestone == null) return const SizedBox();

    final badgeEmoji = streak >= 365 ? '👑' : streak >= 100 ? '⚡' : streak >= 30 ? '💪' : '🔥';
    final badgeName = streak >= 365 ? '전설의 의지' : streak >= 100 ? '백일의 기적' : streak >= 30 ? '한 달의 습관' : '7일 지속자';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏅', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 4),
        const Text('스트릭 달성!', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Text('$streak일 연속 접속', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('${milestone['label']} 달성으로\n+${milestone['xp']} XP를 획득합니다!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6)),

        if (milestone['badge'] == true) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary),
                  child: Center(child: Text(badgeEmoji, style: const TextStyle(fontSize: 20)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('새 뱃지 해금!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(badgeName, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ]),
          ),
        ],

        const SizedBox(height: 16),
        _StreakFlames(streak: streak),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: () async { await app.claimMilestoneXp(); onClose(); },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text('+${milestone['xp']} XP 획득하기 🎉',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
          ),
        ),
      ]),
    );
  }
}

class _BrokenContent extends StatelessWidget {
  final dynamic userData;
  final VoidCallback onClose;
  final AppProvider app;
  final bool watchingAd;
  final VoidCallback onWatchAd;
  const _BrokenContent({required this.userData, required this.onClose, required this.app, required this.watchingAd, required this.onWatchAd});

  @override
  Widget build(BuildContext context) {
    final prevStreak = app.brokenStreakPrev;
    final reviveItem = userData.reviveItem as int;
    final hasRevive = reviveItem > 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('😢', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        const Text('스트릭이 끊겼어요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('$prevStreak일 스트릭이 끊겼어요.\n복구하거나 새로 시작할 수 있어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('끊긴 스트릭', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            Text('🔥 $prevStreak일', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 16),

        _ReviveBtn(
          emoji: '🛡️', title: '부활 아이템 사용',
          sub: hasRevive ? '보유 ${reviveItem}개' : '아이템 없음',
          badge: '무료', disabled: !hasRevive,
          onTap: () async { await app.reviveStreakByItem(); onClose(); },
        ),
        const SizedBox(height: 10),
        _ReviveBtn(
          emoji: '📺',
          title: watchingAd ? '광고 시청 중...' : '광고 시청으로 복구',
          sub: '15~30초 광고 시청', badge: '무료',
          disabled: watchingAd,
          onTap: onWatchAd,
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async { await app.resetStreak(); onClose(); },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('그냥 초기화하기', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary))),
          ),
        ),
      ]),
    );
  }
}

class _ReviveBtn extends StatelessWidget {
  final String emoji, title, sub, badge;
  final bool disabled;
  final VoidCallback onTap;
  const _ReviveBtn({required this.emoji, required this.title, required this.sub, required this.badge, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: disabled ? const Color(0xFFF9F9F9) : Colors.white,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: disabled ? AppTheme.textSecondary : AppTheme.textPrimary)),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ]),
            if (!disabled)
              Text(badge, style: const TextStyle(fontSize: 12, color: Color(0xFF1b8a5a), fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _StreakFlames extends StatelessWidget {
  final int streak;
  const _StreakFlames({required this.streak});

  @override
  Widget build(BuildContext context) {
    final count = streak.clamp(0, 7);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ...List.generate(count, (i) => Container(
        width: 32, height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < count - 1 ? const Color(0xFFfff3e0) : const Color(0xFFff6b00),
          border: Border.all(color: i < count - 1 ? const Color(0xFFffe0b2) : const Color(0xFFe65100)),
        ),
        child: const Center(child: Text('🔥', style: TextStyle(fontSize: 16))),
      )),
      if (streak > 7)
        Container(
          width: 32, height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF9F9F9), border: Border.all(color: AppTheme.border)),
          child: Center(child: Text('+${streak - 7}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
        ),
    ]);
  }
}