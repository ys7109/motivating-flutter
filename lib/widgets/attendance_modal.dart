import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../providers/app_provider.dart';

class AttendanceModal extends StatefulWidget {
  final VoidCallback onClose;
  const AttendanceModal({super.key, required this.onClose});

  @override
  State<AttendanceModal> createState() => _AttendanceModalState();
}

class _AttendanceModalState extends State<AttendanceModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 50), () => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final userData = app.userData;
    if (userData == null) return const SizedBox();

    final streak = userData.streak;
    final isSpecial = streak % 7 == 0;
    final xpReward = streak * 10;
    final daysInCycle = streak % 7;
    final nextSpecial = daysInCycle == 0 ? 7 : 7 - daysInCycle;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$streak일 연속 출석',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, letterSpacing: 0.06)),
                const SizedBox(height: 8),
                Text(isSpecial ? '🎁' : '📅', style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 8),
                Text(isSpecial ? '특별 출석 보상!' : '오늘의 출석 보상',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  isSpecial
                      ? '$streak일 연속 출석 달성!\n특별 보상을 우편함으로 발송합니다.'
                      : '$streak일차 출석 보상을 우편함으로 발송합니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 20),

                // 보상 미리보기
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Text('$streak일차 보상 내용', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Column(children: [
                        Text('+$xpReward', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                        const Text('XP', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                      if (isSpecial) ...[
                        Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 20), color: AppTheme.border),
                        Column(children: [
                          const Text('🛡️ +1', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                          const Text('부활 아이템', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ]),
                      ],
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // 7일 주기 표시
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(7, (i) {
                  final dayInCycle = (streak - 1) % 7;
                  final filled = i <= dayInCycle;
                  final isLast = i == 6;
                  return Container(
                    width: 34, height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLast ? (filled ? const Color(0xFFff6b00) : const Color(0xFFfff3e0))
                          : filled ? AppTheme.primary : const Color(0xFFF0F0F0),
                      border: Border.all(
                        color: isLast ? (filled ? const Color(0xFFe65100) : const Color(0xFFffe0b2))
                            : filled ? AppTheme.primary : AppTheme.border,
                      ),
                    ),
                    child: Center(
                      child: isLast ? const Text('🎁', style: TextStyle(fontSize: 14))
                          : filled ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : Text('${i + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ),
                  );
                })),
                const SizedBox(height: 12),

                if (!isSpecial)
                  Text('특별 보상까지 $nextSpecial일 남음',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),

                // 수령 버튼
                GestureDetector(
                  onTap: _claiming ? null : () async {
                    setState(() => _claiming = true);
                    widget.onClose();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _claiming ? const Color(0xFFE0E0E0) : AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: _claiming
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('우편함으로 받기 📬', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Text('나중에 받기', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}