import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _loading;
  String _error = '';
  String? _lastMethod;

  @override
  void initState() {
    super.initState();
    _lastMethod = _LastLogin.method;
  }

  Future<void> _handle(Future<void> Function() fn, String name) async {
    setState(() { _loading = name; _error = ''; });
    try {
      await fn();
      _LastLogin.method = name;
      if (mounted) await context.read<AppProvider>().reloadUser();
    } catch (e) {
      if (e.toString() != 'cancelled') {
        setState(() => _error = '로그인에 실패했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: context.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(child: Text('⭐',
                          style: TextStyle(fontSize: 36,
                              color: context.isDark ? Colors.black : null))),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '목표를 달성하고\n레벨업하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '단기·중기·장기 목표 설정,\n집중 모드로 경험치 획득',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: const [
                        _FeatureChip('🎯 목표 관리'),
                        _FeatureChip('⚡ XP & 레벨업'),
                        _FeatureChip('🔒 집중 모드'),
                        _FeatureChip('🎨 캐릭터 커스텀'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error,
                          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                          textAlign: TextAlign.center),
                    ),

                  // Google
                  _LoginButton(
                    onTap: () => _handle(() async { await auth.signInWithGoogle(); }, 'google'),
                    loading: _loading == 'google',
                    isLast: _lastMethod == 'google',
                    backgroundColor: context.surfaceColor,
                    borderColor: context.borderColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleIcon(),
                        const SizedBox(width: 10),
                        Text('Google로 계속하기',
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 카카오
                  _LoginButton(
                    onTap: () => _handle(
                        () async { await auth.signInWithKakao(context); }, 'kakao'),
                    loading: _loading == 'kakao',
                    isLast: _lastMethod == 'kakao',
                    backgroundColor: const Color(0xFFFEE500),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _KakaoIcon(),
                        SizedBox(width: 10),
                        Text('카카오로 계속하기',
                            style: TextStyle(
                                color: Color(0xCC000000),
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 게스트
                  GestureDetector(
                    onTap: _loading != null
                        ? null
                        : () => _handle(() async { await auth.signInAnonymously(); }, 'guest'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: _loading == 'guest'
                            ? SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: context.textSecondary))
                            : Text('게스트로 시작 (저장 안됨)',
                                style: TextStyle(color: context.textSecondary, fontSize: 13)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    '계속하면 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textSecondary, fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastLogin {
  static String? method;
}

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: context.subtleBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(
              color: context.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading, isLast;
  final Color backgroundColor;
  final Color? borderColor;
  final Widget child;

  const _LoginButton({
    required this.onTap,
    required this.loading,
    required this.isLast,
    required this.backgroundColor,
    required this.child,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: loading ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: borderColor != null ? Border.all(color: borderColor!) : null,
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: backgroundColor == context.surfaceColor
                              ? context.primaryColor
                              : const Color(0xCC000000)),
                    ),
                  )
                : child,
          ),
        ),
        if (isLast)
          Positioned(
            top: 0, bottom: 0, right: 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: context.primaryColor,
                    borderRadius: BorderRadius.circular(99)),
                child: Text('마지막 로그인',
                    style: TextStyle(
                        color: context.isDark ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 구글 아이콘 (공식 SVG 패스) ──────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 18, height: 18, child: CustomPaint(painter: _GoogleIconPainter()));
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(Path()
      ..moveTo(17.64 * s, 9.2 * s)
      ..cubicTo(17.64 * s, 8.563 * s, 17.583 * s, 7.949 * s, 17.476 * s, 7.36 * s)
      ..lineTo(9 * s, 7.36 * s)
      ..lineTo(9 * s, 10.841 * s)
      ..lineTo(13.844 * s, 10.841 * s)
      ..cubicTo(13.635 * s, 11.966 * s, 13.001 * s, 12.919 * s, 12.048 * s, 13.558 * s)
      ..lineTo(12.048 * s, 15.816 * s)
      ..lineTo(14.956 * s, 15.816 * s)
      ..cubicTo(16.658 * s, 14.249 * s, 17.64 * s, 11.942 * s, 17.64 * s, 9.2 * s)
      ..close(), paint);

    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(Path()
      ..moveTo(9 * s, 18 * s)
      ..cubicTo(11.43 * s, 18 * s, 13.467 * s, 17.194 * s, 14.956 * s, 15.816 * s)
      ..lineTo(12.048 * s, 13.558 * s)
      ..cubicTo(11.242 * s, 14.098 * s, 10.211 * s, 14.418 * s, 9 * s, 14.418 * s)
      ..cubicTo(6.656 * s, 14.418 * s, 4.672 * s, 12.834 * s, 3.964 * s, 10.707 * s)
      ..lineTo(0.957 * s, 10.707 * s)
      ..lineTo(0.957 * s, 13.039 * s)
      ..cubicTo(2.438 * s, 15.983 * s, 5.482 * s, 18 * s, 9 * s, 18 * s)
      ..close(), paint);

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(Path()
      ..moveTo(3.964 * s, 10.707 * s)
      ..cubicTo(3.784 * s, 10.167 * s, 3.682 * s, 9.59 * s, 3.682 * s, 9 * s)
      ..cubicTo(3.682 * s, 8.41 * s, 3.784 * s, 7.833 * s, 3.964 * s, 7.293 * s)
      ..lineTo(3.964 * s, 4.961 * s)
      ..lineTo(0.957 * s, 4.961 * s)
      ..cubicTo(0.347 * s, 6.175 * s, 0, 7.55 * s, 0, 9 * s)
      ..cubicTo(0, 10.45 * s, 0.348 * s, 11.825 * s, 0.957 * s, 13.039 * s)
      ..lineTo(3.964 * s, 10.707 * s)
      ..close(), paint);

    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(Path()
      ..moveTo(9 * s, 3.58 * s)
      ..cubicTo(10.321 * s, 3.58 * s, 11.508 * s, 4.034 * s, 12.44 * s, 4.925 * s)
      ..lineTo(15.022 * s, 2.345 * s)
      ..cubicTo(13.463 * s, 0.891 * s, 11.426 * s, 0, 9 * s, 0)
      ..cubicTo(5.482 * s, 0, 2.438 * s, 2.017 * s, 0.957 * s, 4.961 * s)
      ..lineTo(3.964 * s, 6.293 * s)
      ..cubicTo(4.672 * s, 4.166 * s, 6.656 * s, 3.58 * s, 9 * s, 3.58 * s)
      ..close(), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 카카오 아이콘 (공식 SVG 패스) ────────────────────────
class _KakaoIcon extends StatelessWidget {
  const _KakaoIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 18, height: 18, child: CustomPaint(painter: _KakaoIconPainter()));
  }
}

class _KakaoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xCC000000);

    canvas.drawPath(Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(9 * s, 0)
      ..cubicTo(4.029 * s, 0, 0, 3.072 * s, 0, 6.864 * s)
      ..cubicTo(0, 9.288 * s, 1.584 * s, 11.424 * s, 3.996 * s, 12.66 * s)
      ..lineTo(3 * s, 16.368 * s)
      ..cubicTo(2.928 * s, 16.644 * s, 3.216 * s, 16.872 * s, 3.456 * s, 16.716 * s)
      ..lineTo(7.92 * s, 13.764 * s)
      ..cubicTo(7.956 * s, 13.824 * s, 8.472 * s, 13.872 * s, 9 * s, 13.872 * s)
      ..cubicTo(13.971 * s, 13.872 * s, 18 * s, 10.8 * s, 18 * s, 6.864 * s)
      ..cubicTo(18 * s, 3.072 * s, 13.971 * s, 0, 9 * s, 0)
      ..close(), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}