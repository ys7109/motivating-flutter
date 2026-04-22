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
    // 마지막 로그인 방법 로드 (SharedPreferences 대신 간단히 static 변수 사용)
    _lastMethod = _LastLogin.method;
  }

  Future<void> _handle(Future<void> Function() fn, String name) async {
    setState(() { _loading = name; _error = ''; });
    try {
      await fn();
      _LastLogin.method = name;
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero 영역 ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('⭐',
                            style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '목표를 달성하고\n레벨업하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '단기·중기·장기 목표 설정,\n집중 모드로 경험치 획득',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
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

            // ── 로그인 버튼 영역 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error,
                          style: const TextStyle(
                              color: AppTheme.danger, fontSize: 13),
                          textAlign: TextAlign.center),
                    ),

                  // Google
                  _LoginButton(
                    onTap: () => _handle(() async {
                      await auth.signInWithGoogle();
                    }, 'google'),
                    loading: _loading == 'google',
                    isLast: _lastMethod == 'google',
                    backgroundColor: Colors.white,
                    borderColor: AppTheme.border,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleIcon(),
                        const SizedBox(width: 10),
                        const Text('Google로 계속하기',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 카카오
                  _LoginButton(
                    onTap: () => _handle(() async {
                      // 카카오 로그인은 추후 구현
                    }, 'kakao'),
                    loading: _loading == 'kakao',
                    isLast: _lastMethod == 'kakao',
                    backgroundColor: const Color(0xFFFEE500),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('💬', style: TextStyle(fontSize: 18)),
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
                    onTap: _loading != null ? null : () => _handle(() async {
                      await auth.signInAnonymously();
                    }, 'guest'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: _loading == 'guest'
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.textSecondary))
                            : const Text('게스트로 시작 (저장 안됨)',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    '계속하면 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFFBDBDBD), fontSize: 11, height: 1.6),
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
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 13,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;
  final bool isLast;
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
              border: borderColor != null
                  ? Border.all(color: borderColor!)
                  : null,
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: backgroundColor == Colors.white
                              ? AppTheme.primary
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
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('마지막 로그인',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18, height: 18,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // 간단한 G 아이콘 대체 - 컬러 원
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), -1.57, 3.14, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 1.57, 1.57, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 3.14, 0.79, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 3.93, 0.79, true, paint);

    // 흰 원으로 가운데 뚫기
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.35, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}