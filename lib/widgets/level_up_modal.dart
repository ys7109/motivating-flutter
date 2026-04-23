import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class LevelUpModal extends StatefulWidget {
  final int level;
  final VoidCallback onClose;
  const LevelUpModal({super.key, required this.level, required this.onClose});

  @override
  State<LevelUpModal> createState() => _LevelUpModalState();
}

class _LevelUpModalState extends State<LevelUpModal> with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _particleCtrl;
  late Animation<double> _scaleAnim;
  final List<_Particle> _particles = [];
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 80; i++) {
      _particles.add(_Particle(
        x: _rand.nextDouble(),
        vy: -(_rand.nextDouble() * 0.8 + 0.4),
        vx: (_rand.nextDouble() - 0.5) * 0.6,
        size: _rand.nextDouble() * 8 + 4,
        color: [
          const Color(0xFFe040fb), const Color(0xFFf48fb1),
          const Color(0xFFfff176), const Color(0xFF80deea),
          const Color(0xFFa5d6a7), const Color(0xFFffcc80),
        ][_rand.nextInt(6)],
        isCircle: _rand.nextBool(),
      ));
    }

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) { _scaleCtrl.forward(); _particleCtrl.forward(); }
    });

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _close();
    });
  }

  void _close() { _scaleCtrl.reverse().then((_) { if (mounted) widget.onClose(); }); }

  @override
  void dispose() { _scaleCtrl.dispose(); _particleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: _close,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleCtrl, _particleCtrl]),
        builder: (context, _) {
          return Container(
            color: Colors.black.withOpacity(0.6 * _scaleCtrl.value),
            child: Stack(children: [
              ..._particles.map((p) {
                final t = _particleCtrl.value;
                final x = p.x + p.vx * t;
                final y = 1.0 + p.vy * t + 0.5 * 0.3 * t * t;
                return Positioned(
                  left: x * size.width, top: y * size.height,
                  child: Opacity(
                    opacity: (1 - t * 0.8).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: t * p.size,
                      child: Container(
                        width: p.size,
                        height: p.isCircle ? p.size : p.size * 0.6,
                        decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(p.isCircle ? p.size : 2)),
                      ),
                    ),
                  ),
                );
              }),
              Center(
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                    decoration: BoxDecoration(
                      color: context.modalBg,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 64)],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('⭐', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      Text('LEVEL UP!', style: TextStyle(fontSize: 14, color: context.textSecondary, fontWeight: FontWeight.w500, letterSpacing: 0.08)),
                      const SizedBox(height: 4),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFe040fb), Color(0xFFf48fb1)]).createShader(b),
                        child: Text('${widget.level}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      Text('레벨 ${widget.level} 달성!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      const SizedBox(height: 4),
                      Text('계속 성장하고 있어요 🔥', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                      const SizedBox(height: 20),
                      Text('탭하여 닫기', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                    ]),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x, vy, vx, size;
  final Color color;
  final bool isCircle;
  const _Particle({required this.x, required this.vy, required this.vx, required this.size, required this.color, required this.isCircle});
}
