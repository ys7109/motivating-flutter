import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';

const _slides = [
  _Slide(emoji: '🔥', title: 'Motivating에\n오신 걸 환영해요!',
      desc: '목표를 설정하고 달성하면서\n경험치를 쌓고 레벨업하세요.', color: Color(0xFF7c3aed)),
  _Slide(emoji: '🎯', title: '목표를 설정하고\n달성해보세요',
      desc: '단기·중기·장기 목표를 만들고\n매일 꾸준히 달성해 나가세요.', color: Color(0xFF0284c7)),
  _Slide(emoji: '⚡', title: 'XP를 모아\n레벨업하세요',
      desc: '목표를 달성할 때마다 XP를 획득해요.\n레벨이 오를수록 새로운 보상이 열려요.', color: Color(0xFFd97706)),
  _Slide(emoji: '⏱️', title: '집중 모드로\n몰입하세요',
      desc: '타이머를 켜고 집중하면\n추가 XP와 랭킹 포인트를 얻어요.', color: Color(0xFF059669)),
  _Slide(emoji: '✨', title: '시작해볼까요?',
      desc: '닉네임을 입력하고\n첫 번째 목표를 만들어보세요!',
      color: Color(0xFFdb2777), isLast: true),
];

class _Slide {
  final String emoji, title, desc;
  final Color color;
  final bool isLast;
  const _Slide({
    required this.emoji, required this.title,
    required this.desc, required this.color, this.isLast = false,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _current = 0;
  final _nicknameController = TextEditingController();
  bool _loading = false;
  double? _startX;

  @override
  void dispose() { _nicknameController.dispose(); super.dispose(); }

  void _onPanStart(DragStartDetails d) => _startX = d.globalPosition.dx;
  void _onPanEnd(DragEndDetails d) {
    if (_startX == null) return;
    final diff = _startX! - d.globalPosition.dx;
    if (diff > 50 && _current < _slides.length - 1) setState(() => _current++);
    if (diff < -50 && _current > 0) setState(() => _current--);
    _startX = null;
  }

  Future<void> _handleStart() async {
    if (_nicknameController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<AppProvider>().completeOnboarding(_nicknameController.text.trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_current];
    final isLast = _current == _slides.length - 1;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: context.bgColor,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onHorizontalDragStart: _onPanStart,
        onHorizontalDragEnd: _onPanEnd,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              color: slide.color.withOpacity(context.isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: Center(child: Text(slide.emoji,
                                style: const TextStyle(fontSize: 56))),
                          ),
                          const SizedBox(height: 36),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              slide.title,
                              key: ValueKey(_current),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w700,
                                height: 1.3, letterSpacing: -0.5,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              slide.desc,
                              key: ValueKey('desc_$_current'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16, color: context.textSecondary, height: 1.7),
                            ),
                          ),
                          if (isLast) ...[
                            const SizedBox(height: 32),
                            TextField(
                              controller: _nicknameController,
                              maxLength: 12,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: context.textPrimary),
                              decoration: InputDecoration(
                                hintText: '닉네임을 입력하세요',
                                hintStyle: TextStyle(color: context.textSecondary),
                                counterText: '',
                                filled: true,
                                fillColor: context.inputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: slide.color),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: slide.color, width: 2),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Text('최대 12자',
                                style: TextStyle(color: context.textSecondary, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) => GestureDetector(
                          onTap: () => setState(() => _current = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: i == _current ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: i == _current ? slide.color : context.borderColor,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        )),
                      ),
                      const SizedBox(height: 24),
                      if (!isLast)
                        GestureDetector(
                          onTap: () => setState(() => _current++),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                                color: slide.color, borderRadius: BorderRadius.circular(14)),
                            child: const Center(child: Text('다음',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600))),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _nicknameController.text.trim().isEmpty || _loading
                              ? null
                              : _handleStart,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _nicknameController.text.trim().isEmpty
                                  ? context.borderColor
                                  : slide.color,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: _loading
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text('시작하기 🚀',
                                    style: TextStyle(
                                      color: _nicknameController.text.trim().isEmpty
                                          ? context.textSecondary
                                          : Colors.white,
                                      fontSize: 16, fontWeight: FontWeight.w600,
                                    ))),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
