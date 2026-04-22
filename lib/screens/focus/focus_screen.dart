import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  String _phase = 'idle';

  int _hInput = 0;
  int _mInput = 25;
  int _sInput = 0;

  int _totalSec = 25 * 60;
  int _remaining = 25 * 60;
  int _elapsed = 0;

  Timer? _timer;
  bool _wasRunningBeforeBackground = false;

  bool _addPopup = false;
  int _addH = 0, _addM = 0, _addS = 0;
  bool _exitPopup = false;

  static const _lifecycleChannel = EventChannel('com.kimyuseong.motivating/lifecycle');
  StreamSubscription? _lifecycleSub;

  static const _presets = [
    {'label': '10분', 'h': 0, 'm': 10, 's': 0},
    {'label': '30분', 'h': 0, 'm': 30, 's': 0},
    {'label': '1시간', 'h': 1, 'm': 0, 's': 0},
    {'label': '2시간', 'h': 2, 'm': 0, 's': 0},
  ];

  @override
  void initState() {
    super.initState();
    _lifecycleSub = _lifecycleChannel.receiveBroadcastStream().listen((event) {
      if (event == 'app_switch') {
        if (_phase == 'running') {
          _wasRunningBeforeBackground = true;
          _timer?.cancel();
          if (mounted) setState(() => _phase = 'paused_by_switch');
        }
      } else if (event == 'screen_off') {
        // 화면 꺼짐 → 타이머 유지
      } else if (event == 'resumed') {
        if (_wasRunningBeforeBackground && _phase == 'paused_by_switch') {
          _wasRunningBeforeBackground = false;
          if (mounted) setState(() => _phase = 'running');
          _tick();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycleSub?.cancel();
    super.dispose();
  }

  int get _realtimeXp {
    final mins = _elapsed ~/ 60;
    return mins + (mins ~/ 10) * 10;
  }

  int get _toNextBonus {
    final nextMin = ((_elapsed ~/ 60) ~/ 10 + 1) * 10;
    return nextMin * 60 - _elapsed;
  }

  int get _nextBonusXp => ((_elapsed ~/ 60) ~/ 10 + 1) * 10;

  bool get _isActive =>
      _phase == 'running' || _phase == 'paused' || _phase == 'paused_by_switch';

  String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  void _syncTotal() {
    if (_phase == 'idle') {
      final t = _hInput * 3600 + _mInput * 60 + _sInput;
      setState(() { _totalSec = t; _remaining = t; });
    }
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) { _onDone(); return; }
      setState(() { _elapsed++; _remaining--; });
    });
  }

  void _start() {
    if (_totalSec == 0) return;
    setState(() { _phase = 'running'; _elapsed = 0; });
    _tick();
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _phase = 'paused');
  }

  void _resume() {
    setState(() => _phase = 'running');
    _tick();
  }

  void _onDone() {
    _timer?.cancel();
    setState(() { _phase = 'done'; _remaining = 0; });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final mins = _elapsed ~/ 60;
    if (mins > 0) await context.read<AppProvider>().saveFocusSession(mins);
    if (mounted) setState(() { _phase = 'idle'; _elapsed = 0; _remaining = _totalSec; });
  }

  void _applyAddTime() {
    final add = _addH * 3600 + _addM * 60 + _addS;
    if (add == 0) return;
    setState(() {
      _remaining += add;
      _totalSec += add;
      _addH = 0; _addM = 0; _addS = 0;
      _addPopup = false;
      if (_phase == 'done') { _phase = 'running'; }
    });
    if (_phase == 'running') _tick();
  }

  String get _statusMsg {
    switch (_phase) {
      case 'running': return '화면을 끄거나 잠금 상태에서도 타이머가 계속 동작합니다.';
      case 'paused': return '일시정지 중입니다.';
      case 'paused_by_switch': return '다른 앱으로 이동하여 타이머가 정지됐어요.';
      case 'done': return '집중이 완료됐어요! XP를 획득하세요.';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final size = sw - 160;
    final r = size / 2 - 8;
    final double progress = _phase == 'idle' ? 1.0
        : _totalSec > 0 ? _remaining / _totalSec : 0.0;
    final elMin = _elapsed ~/ 60;

    return PopScope(
      canPop: _phase == 'idle',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isActive) setState(() => _exitPopup = true);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  children: [
                    // ← 홈으로
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          if (_isActive) setState(() => _exitPopup = true);
                        },
                        icon: const Icon(Icons.arrow_back_ios, size: 14, color: AppTheme.textSecondary),
                        label: const Text('홈으로', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      ),
                    ),

                    // 제목
                    const Text('집중 모드',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('시간을 설정하고 집중을 시작하세요',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    if (_statusMsg.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_statusMsg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
                    ],
                    const SizedBox(height: 32),

                    // 타이머 링
                    SizedBox(
                      width: size, height: size,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _RingPainter(progress: progress, phase: _phase, r: r)),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _fmt(_remaining),
                                style: TextStyle(
                                  fontSize: _totalSec >= 3600 ? 38 : 46,
                                  fontWeight: FontWeight.w300,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -2,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (_isActive) ...[
                                const SizedBox(height: 4),
                                Text('$elMin분 집중 완료',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => setState(() => _addPopup = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppTheme.border),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text('+', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                                      SizedBox(width: 4),
                                      Text('시간 추가', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    ]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // idle: 시간 입력 + 프리셋
                    if (_phase == 'idle') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TimeInput(label: '시간', value: _hInput, max: 23,
                              onChanged: (v) { setState(() => _hInput = v); _syncTotal(); }),
                          const Padding(padding: EdgeInsets.only(top: 18),
                              child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: AppTheme.textSecondary))),
                          _TimeInput(label: '분', value: _mInput, max: 59,
                              onChanged: (v) { setState(() => _mInput = v); _syncTotal(); }),
                          const Padding(padding: EdgeInsets.only(top: 18),
                              child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: AppTheme.textSecondary))),
                          _TimeInput(label: '초', value: _sInput, max: 59,
                              onChanged: (v) { setState(() => _sInput = v); _syncTotal(); }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _presets.map((p) {
                          final isActive = _hInput == p['h'] && _mInput == p['m'] && _sInput == p['s'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _hInput = p['h'] as int;
                                _mInput = p['m'] as int;
                                _sInput = p['s'] as int;
                              });
                              _syncTotal();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: isActive ? AppTheme.primary : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(p['label'] as String,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                      color: isActive ? Colors.white : const Color(0xFF616161))),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // XP
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('현재까지 ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      Text('+$_realtimeXp XP', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Text(' 획득 예정', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ]),

                    if (_isActive && _elapsed > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '다음 +$_nextBonusXp XP 보너스까지 ${_fmt(_toNextBonus)}${_phase == 'paused' ? ' ⏸' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 버튼
                    if (_phase == 'idle')
                      _BigBtn(label: '집중 시작', disabled: _totalSec == 0, onTap: _start),

                    if (_isActive) ...[
                      _BigBtn(
                        label: _phase == 'paused' || _phase == 'paused_by_switch' ? '다시 집중' : '일시정지',
                        onTap: _phase == 'running' ? _pause : _resume,
                      ),
                      const SizedBox(height: 10),
                      _OutlineBtn(label: '종료하기', onTap: () => setState(() => _exitPopup = true)),
                    ],

                    if (_phase == 'done') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          const Text('🎉', style: TextStyle(fontSize: 28)),
                          const SizedBox(height: 8),
                          const Text('집중 완료!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('$elMin분 집중 → +$_realtimeXp XP 획득',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      _OutlineBtn(label: '+ 시간 추가하고 계속 집중', onTap: () => setState(() => _addPopup = true)),
                      const SizedBox(height: 10),
                      _BigBtn(label: 'XP 획득하고 홈으로', onTap: _finish),
                    ],

                    const SizedBox(height: 28),

                    // XP 안내
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('XP 획득 기준', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        const Text('1분마다 1 XP를 획득하며, 매 10분마다 현재까지 집중한 시간만큼 XP를 추가 획득합니다.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF616161), height: 1.7)),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '예) 10분 집중 시 10 XP 추가 획득\n     50분 집중 시 50 XP 추가 획득',
                            style: TextStyle(fontSize: 13, color: Color(0xFF616161), height: 1.8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '* 화면을 끄거나 잠금 상태에서도 타이머가 계속 동작합니다.\n* 다른 앱으로 이동하면 타이머가 일시정지됩니다.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFBDBDBD), height: 1.6),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            if (_exitPopup)
              _ExitModal(
                elapsed: _elapsed, xp: _realtimeXp,
                onCancel: () => setState(() => _exitPopup = false),
                onConfirm: () async { setState(() => _exitPopup = false); await _finish(); },
              ),

            if (_addPopup)
              _AddTimeModal(
                remaining: _remaining,
                addH: _addH, addM: _addM, addS: _addS,
                onChangeH: (v) => setState(() => _addH = v),
                onChangeM: (v) => setState(() => _addM = v),
                onChangeS: (v) => setState(() => _addS = v),
                onCancel: () => setState(() => _addPopup = false),
                onConfirm: _applyAddTime,
                formatTime: _fmt,
              ),
          ],
        ),
      ),
    );
  }
}

// ── RingPainter ──────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress, r;
  final String phase;
  const _RingPainter({required this.progress, required this.phase, required this.r});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeW = 8.0;

    if (phase == 'idle') {
      final paint = Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW;
      canvas.drawCircle(center, r, paint);
      return;
    }

    final bgPaint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    canvas.drawCircle(center, r, bgPaint);

    if (progress > 0) {
      final color = phase == 'done' ? const Color(0xFF1b8a5a)
          : phase == 'paused' || phase == 'paused_by_switch' ? const Color(0xFF9E9E9E)
          : AppTheme.primary;
      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -pi / 2,
        2 * pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.phase != phase;
}

// ── TimeInput ────────────────────────────────────────────
class _TimeInput extends StatefulWidget {
  final String label;
  final int value, max;
  final ValueChanged<int> onChanged;
  const _TimeInput({required this.label, required this.value, required this.max, required this.onChanged});
  @override
  State<_TimeInput> createState() => _TimeInputState();
}

class _TimeInputState extends State<_TimeInput> {
  late TextEditingController _ctrl;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_TimeInput old) {
    super.didUpdateWidget(old);
    if (!_focused && old.value != widget.value) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(children: [
        Text(widget.label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Focus(
          onFocusChange: (f) {
            setState(() => _focused = f);
            if (!f) {
              final n = (int.tryParse(_ctrl.text) ?? 0).clamp(0, widget.max);
              _ctrl.text = '$n';
              widget.onChanged(n);
            }
          },
          child: SizedBox(
            width: 70,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
              ),
              onChanged: (s) {
                final n = int.tryParse(s) ?? 0;
                if (n > widget.max) { _ctrl.text = '0'; widget.onChanged(0); }
                else widget.onChanged(n);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Buttons ──────────────────────────────────────────────
class _BigBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  const _BigBtn({required this.label, required this.onTap, this.disabled = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFE0E0E0) : AppTheme.primary,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Center(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
          color: disabled ? AppTheme.textSecondary : Colors.white))),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(99)),
      child: Center(child: Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary))),
    ),
  );
}

// ── Modals ───────────────────────────────────────────────
class _ExitModal extends StatelessWidget {
  final int elapsed, xp;
  final VoidCallback onCancel, onConfirm;
  const _ExitModal({required this.elapsed, required this.xp, required this.onCancel, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    final elMin = elapsed ~/ 60;
    return Container(
      color: Colors.black54,
      child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('집중 종료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('$elMin분 집중했어요.\n지금 종료하면 +$xp XP를 획득합니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(onTap: onCancel,
                child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('계속 집중', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(onTap: onConfirm,
                child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('종료하기', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)))))),
            ]),
          ]),
        ),
      )),
    );
  }
}

class _AddTimeModal extends StatelessWidget {
  final int remaining, addH, addM, addS;
  final ValueChanged<int> onChangeH, onChangeM, onChangeS;
  final VoidCallback onCancel, onConfirm;
  final String Function(int) formatTime;
  const _AddTimeModal({required this.remaining, required this.addH, required this.addM, required this.addS,
    required this.onChangeH, required this.onChangeM, required this.onChangeS,
    required this.onCancel, required this.onConfirm, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final preview = remaining + addH * 3600 + addM * 60 + addS;
    final hasAdd = addH + addM + addS > 0;
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('시간 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('추가할 시간을 입력하세요', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _TimeInput(label: '시간', value: addH, max: 23, onChanged: onChangeH),
                  const Padding(padding: EdgeInsets.only(top: 18), child: Text(':', style: TextStyle(fontSize: 20, color: AppTheme.textSecondary))),
                  _TimeInput(label: '분', value: addM, max: 59, onChanged: onChangeM),
                  const Padding(padding: EdgeInsets.only(top: 18), child: Text(':', style: TextStyle(fontSize: 20, color: AppTheme.textSecondary))),
                  _TimeInput(label: '초', value: addS, max: 59, onChanged: onChangeS),
                ]),
                if (hasAdd) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      const Text('추가 후 남은 시간', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text(formatTime(preview), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: GestureDetector(onTap: onCancel,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('취소', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))))),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(onTap: hasAdd ? onConfirm : null,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(color: hasAdd ? AppTheme.primary : const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('추가하기', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)))))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}