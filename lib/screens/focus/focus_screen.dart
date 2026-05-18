import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/friend_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  String _phase = 'idle';
  int _hInput = 0, _mInput = 25, _sInput = 0;
  int _totalSec = 25 * 60;
  int _elapsedMs = 0, _elapsedAtStartMs = 0;
  Timer? _timer;
  DateTime? _startTime;
  bool _wasRunningBeforeBackground = false;
  bool _addPopup = false;
  int _addH = 0, _addM = 0, _addS = 0;
  bool _exitPopup = false;

  static const _lifecycleChannel =
      EventChannel('com.kimyuseong.motivating/lifecycle');
  StreamSubscription? _lifecycleSub;

  static const _presets = [
    {'label': '10분', 'h': 0, 'm': 10, 's': 0},
    {'label': '30분', 'h': 0, 'm': 30, 's': 0},
    {'label': '1시간', 'h': 1, 'm': 0, 's': 0},
    {'label': '2시간', 'h': 2, 'm': 0, 's': 0},
  ];

  int get _elapsed => _elapsedMs ~/ 1000;
  int get _remaining =>
      (_totalSec - _elapsed).clamp(0, _totalSec);
  double get _progress => _totalSec > 0
      ? (_totalSec * 1000 - _elapsedMs) / (_totalSec * 1000)
      : 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().onPauseFocus = _pauseFromOutside;
    });
    _lifecycleSub =
        _lifecycleChannel.receiveBroadcastStream().listen((event) {
      if (event == 'app_switch') {
        if (_phase == 'running') {
          _wasRunningBeforeBackground = true;
          _timer?.cancel();
          _elapsedAtStartMs = _elapsedMs;
          if (mounted) {
            setState(() => _phase = 'paused_by_switch');
            context.read<AppProvider>().isFocusing = false;
          }
        }
      } else if (event == 'resumed') {
        if (_wasRunningBeforeBackground &&
            _phase == 'paused_by_switch') {
          _wasRunningBeforeBackground = false;
          if (mounted) {
            setState(() => _phase = 'running');
            context.read<AppProvider>().isFocusing = true;
          }
          _tick();
        }
      }
    });
  }

  @override
  void dispose() {
    context.read<AppProvider>().onPauseFocus = null;
    _timer?.cancel();
    _lifecycleSub?.cancel();
    super.dispose();
  }

  void _pauseFromOutside() {
    if (_phase == 'running') _pause();
  }

  int get _realtimeXp {
    final mins = _elapsed ~/ 60;
    return mins + (mins ~/ 10) * mins;
  }

  // 2번: _elapsed == 0일 때도 600(10:00)을 반환 — 시작 직후부터 표시
  int get _toNextBonus {
    final nextMin = ((_elapsed ~/ 60) ~/ 10 + 1) * 10;
    return nextMin * 60 - _elapsed;
  }

  int get _nextBonusXp => ((_elapsed ~/ 60) ~/ 10 + 1) * 10;

  bool get _isActive =>
      _phase == 'running' ||
      _phase == 'paused' ||
      _phase == 'paused_by_switch';

  String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0)
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _syncTotal() {
    if (_phase == 'idle')
      setState(() {
        _totalSec = _hInput * 3600 + _mInput * 60 + _sInput;
        _elapsedMs = 0;
      });
  }

  void _tick() {
    _timer?.cancel();
    _startTime = DateTime.now();
    _timer =
        Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final diffMs =
          DateTime.now().difference(_startTime!).inMilliseconds;
      final newElapsedMs = _elapsedAtStartMs + diffMs;
      if (newElapsedMs >= _totalSec * 1000) {
        setState(() => _elapsedMs = _totalSec * 1000);
        _onDone();
        return;
      }
      setState(() => _elapsedMs = newElapsedMs);
    });
  }

  void _start() {
    if (_totalSec == 0) return;
    _elapsedAtStartMs = 0;
    setState(() {
      _phase = 'running';
      _elapsedMs = 0;
    });
    context.read<AppProvider>().isFocusing = true;
    final uid = context.read<AppProvider>().authUser?.uid;
    if (uid != null) FriendService().setFocusing(uid);
    _tick();
  }

  void _pause() {
    _timer?.cancel();
    _elapsedAtStartMs = _elapsedMs;
    setState(() => _phase = 'paused');
    context.read<AppProvider>().isFocusing = false;
  }

  void _resume() {
    setState(() => _phase = 'running');
    context.read<AppProvider>().isFocusing = true;
    _tick();
  }

  void _onDone() {
    _timer?.cancel();
    context.read<AppProvider>().isFocusing = false;
    final uid = context.read<AppProvider>().authUser?.uid;
    if (uid != null) FriendService().clearFocusing(uid);
    setState(() {
      _phase = 'done';
      _elapsedMs = _totalSec * 1000;
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final mins = _elapsed ~/ 60;
    if (mins > 0)
      await context.read<AppProvider>().saveFocusSession(mins);
    context.read<AppProvider>().isFocusing = false;
    final uid = context.read<AppProvider>().authUser?.uid;
    if (uid != null) FriendService().clearFocusing(uid);
    if (mounted)
      setState(() {
        _phase = 'idle';
        _elapsedMs = 0;
        _elapsedAtStartMs = 0;
      });
  }

  void _applyAddTime() {
    final add = _addH * 3600 + _addM * 60 + _addS;
    if (add == 0) return;
    _timer?.cancel();
    _elapsedAtStartMs = _elapsedMs;
    setState(() {
      _totalSec += add;
      _addH = 0;
      _addM = 0;
      _addS = 0;
      _addPopup = false;
      if (_phase == 'done') _phase = 'running';
    });
    if (_phase == 'running') _tick();
  }

  String get _statusMsg {
    switch (_phase) {
      case 'running':
        return '화면을 끄거나 잠금 상태에서도 타이머가 계속 동작합니다.';
      case 'paused':
        return '일시정지 중입니다.';
      case 'paused_by_switch':
        return '다른 앱으로 이동하여 타이머가 정지됐어요.';
      case 'done':
        return '집중이 완료됐어요! XP를 획득하세요.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final size = sw - 160;
    final r = size / 2 - 8;
    final elMin = _elapsed ~/ 60;

    return PopScope(
      canPop: _phase == 'idle',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isActive)
          setState(() => _exitPopup = true);
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        if (_isActive)
                          setState(() => _exitPopup = true);
                      },
                      icon: Icon(Icons.arrow_back_ios,
                          size: 14, color: context.textSecondary),
                      label: Text('홈으로',
                          style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondary)),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero),
                    ),
                  ),

                  Text('집중 모드',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary)),
                  const SizedBox(height: 4),
                  Text('시간을 설정하고 집중을 시작하세요',
                      style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondary)),
                  if (_statusMsg.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_statusMsg,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            height: 1.5)),
                  ],
                  const SizedBox(height: 32),

                  SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                        fit: StackFit.expand,
                        children: [
                      CustomPaint(
                          painter: _RingPainter(
                        progress: _phase == 'idle'
                            ? 1.0
                            : _progress,
                        phase: _phase,
                        r: r,
                        activeColor: context.primaryColor,
                        bgColor: context.borderColor,
                      )),
                      Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                        Text(
                          _fmt(_remaining),
                          style: TextStyle(
                            fontSize:
                                _totalSec >= 3600 ? 38 : 46,
                            fontWeight: FontWeight.w300,
                            color: context.textPrimary,
                            letterSpacing: -2,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        if (_isActive) ...[
                          const SizedBox(height: 4),
                          Text('$elMin분 집중 완료',
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      context.textSecondary)),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => setState(
                                () => _addPopup = true),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 5),
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: context
                                          .borderColor),
                                  borderRadius:
                                      BorderRadius.circular(
                                          99)),
                              child: Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                Text('+',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: context
                                            .textSecondary)),
                                const SizedBox(width: 4),
                                Text('시간 추가',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context
                                            .textSecondary)),
                              ]),
                            ),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  if (_phase == 'idle') ...[
                    Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      _TimeInput(
                          label: '시간',
                          value: _hInput,
                          max: 23,
                          onChanged: (v) {
                            setState(() => _hInput = v);
                            _syncTotal();
                          }),
                      Padding(
                          padding:
                              const EdgeInsets.only(top: 18),
                          child: Text(':',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      context.textSecondary))),
                      _TimeInput(
                          label: '분',
                          value: _mInput,
                          max: 59,
                          onChanged: (v) {
                            setState(() => _mInput = v);
                            _syncTotal();
                          }),
                      Padding(
                          padding:
                              const EdgeInsets.only(top: 18),
                          child: Text(':',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      context.textSecondary))),
                      _TimeInput(
                          label: '초',
                          value: _sInput,
                          max: 59,
                          onChanged: (v) {
                            setState(() => _sInput = v);
                            _syncTotal();
                          }),
                    ]),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _presets.map((p) {
                        final isActive = _hInput == p['h'] &&
                            _mInput == p['m'] &&
                            _sInput == p['s'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _hInput = p['h'] as int;
                              _mInput = p['m'] as int;
                              _sInput = p['s'] as int;
                            });
                            _syncTotal();
                          },
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? context.primaryColor
                                  : context.subtleBg,
                              borderRadius:
                                  BorderRadius.circular(99),
                            ),
                            child: Text(p['label'] as String,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? context.onPrimary
                                        : context.textSecondary)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                    Text('현재까지 ',
                        style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary)),
                    Text('+$_realtimeXp XP',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary)),
                    Text(' 획득 예정',
                        style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary)),
                  ]),

                  // 2번: _isActive이면 _elapsed > 0 조건 제거 — 시작 직후 10:00으로 즉시 표시
                  if (_isActive) ...[
                    const SizedBox(height: 8),
                    Text(
                      '다음 +$_nextBonusXp XP 보너스까지 ${_fmt(_toNextBonus)}${_phase == 'paused' ? ' ⏸' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),

                  if (_phase == 'idle')
                    _BigBtn(
                        label: '집중 시작',
                        disabled: _totalSec == 0,
                        onTap: _start),

                  if (_isActive) ...[
                    _BigBtn(
                      label: _phase == 'paused' ||
                              _phase == 'paused_by_switch'
                          ? '다시 집중'
                          : '일시정지',
                      onTap: _phase == 'running' ? _pause : _resume,
                    ),
                    const SizedBox(height: 10),
                    _OutlineBtn(
                        label: '종료하기',
                        onTap: () =>
                            setState(() => _exitPopup = true)),
                  ],

                  if (_phase == 'done') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: context.subtleBg,
                          borderRadius:
                              BorderRadius.circular(14)),
                      child: Column(children: [
                        const Text('🎉',
                            style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 8),
                        Text('집중 완료!',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary)),
                        const SizedBox(height: 4),
                        Text('$elMin분 집중 → +$_realtimeXp XP 획득',
                            style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    _OutlineBtn(
                        label: '+ 시간 추가하고 계속 집중',
                        onTap: () =>
                            setState(() => _addPopup = true)),
                    const SizedBox(height: 10),
                    _BigBtn(
                        label: 'XP 획득하고 홈으로',
                        onTap: _finish),
                  ],

                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: context.subtleBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Text('XP 획득 기준',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                          '1분마다 1 XP를 획득하며, 매 10분마다 현재까지 집중한 시간만큼 XP를 추가 획득합니다.',
                          style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                              height: 1.7)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                            color: context.surfaceColor,
                            border: Border.all(
                                color: context.borderColor),
                            borderRadius:
                                BorderRadius.circular(10)),
                        child: Text(
                            '예) 10분 집중 시 10 XP 추가 획득\n     50분 집중 시 50 XP 추가 획득',
                            style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                                height: 1.8)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                          '* 화면을 끄거나 잠금 상태에서도 타이머가 계속 동작합니다.\n* 다른 앱으로 이동하면 타이머가 일시정지됩니다.',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                              height: 1.6)),
                    ]),
                  ),
                ]),
              ),
            ),

            if (_exitPopup)
              _ExitModal(
                elapsed: _elapsed,
                xp: _realtimeXp,
                onCancel: () => setState(() => _exitPopup = false),
                onConfirm: () async {
                  setState(() => _exitPopup = false);
                  await _finish();
                },
              ),

            if (_addPopup)
              _AddTimeModal(
                remaining: _remaining,
                addH: _addH,
                addM: _addM,
                addS: _addS,
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

class _RingPainter extends CustomPainter {
  final double progress, r;
  final String phase;
  final Color activeColor, bgColor;
  const _RingPainter(
      {required this.progress,
      required this.phase,
      required this.r,
      required this.activeColor,
      required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeW = 8.0;
    if (phase == 'idle') {
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = activeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW);
      return;
    }
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = bgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW);
    if (progress > 0) {
      final color = phase == 'done'
          ? const Color(0xFF1b8a5a)
          : phase == 'paused' || phase == 'paused_by_switch'
              ? const Color(0xFF9E9E9E)
              : activeColor;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -pi / 2,
          2 * pi * progress,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.phase != phase;
}

class _TimeInput extends StatefulWidget {
  final String label;
  final int value, max;
  final ValueChanged<int> onChanged;
  const _TimeInput(
      {required this.label,
      required this.value,
      required this.max,
      required this.onChanged});
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
    if (!_focused && old.value != widget.value)
      _ctrl.text = '${widget.value}';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(children: [
        Text(widget.label,
            style: TextStyle(
                fontSize: 11, color: context.textSecondary)),
        const SizedBox(height: 4),
        Focus(
          onFocusChange: (f) {
            setState(() => _focused = f);
            if (!f) {
              final n = (int.tryParse(_ctrl.text) ?? 0)
                  .clamp(0, widget.max);
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: context.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: context.borderColor)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: context.primaryColor, width: 1.5)),
                filled: true,
                fillColor: context.surfaceColor,
              ),
              onChanged: (s) {
                final n = int.tryParse(s) ?? 0;
                if (n > widget.max) {
                  _ctrl.text = '0';
                  widget.onChanged(0);
                } else {
                  widget.onChanged(n);
                }
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  const _BigBtn(
      {required this.label,
      required this.onTap,
      this.disabled = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
              color: disabled
                  ? context.borderColor
                  : context.primaryColor,
              borderRadius: BorderRadius.circular(99)),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: disabled
                          ? context.textSecondary
                          : context.onPrimary))),
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
          decoration: BoxDecoration(
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(99)),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      color: context.textSecondary))),
        ),
      );
}

class _ExitModal extends StatelessWidget {
  final int elapsed, xp;
  final VoidCallback onCancel, onConfirm;
  const _ExitModal(
      {required this.elapsed,
      required this.xp,
      required this.onCancel,
      required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    final elMin = elapsed ~/ 60;
    return Container(
      color: Colors.black54,
      child: Center(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: context.modalBg,
              borderRadius: BorderRadius.circular(20)),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: [
            Text('집중 종료',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            const SizedBox(height: 8),
            Text('$elMin분 집중했어요.\n지금 종료하면 +$xp XP를 획득합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    height: 1.6)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: GestureDetector(
                      onTap: onCancel,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          decoration: BoxDecoration(
                              color: context.subtleBg,
                              borderRadius:
                                  BorderRadius.circular(12)),
                          child: Center(
                              child: Text('계속 집중',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w500,
                                      color: context
                                          .textPrimary)))))),
              const SizedBox(width: 10),
              Expanded(
                  child: GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          decoration: BoxDecoration(
                              color: context.primaryColor,
                              borderRadius:
                                  BorderRadius.circular(12)),
                          child: Center(
                              child: Text('종료하기',
                                  style: TextStyle(
                                      color: context.onPrimary,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w500)))))),
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
  const _AddTimeModal(
      {required this.remaining,
      required this.addH,
      required this.addM,
      required this.addS,
      required this.onChangeH,
      required this.onChangeM,
      required this.onChangeS,
      required this.onCancel,
      required this.onConfirm,
      required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final preview =
        remaining + addH * 3600 + addM * 60 + addS;
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
              decoration: BoxDecoration(
                  color: context.modalBg,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20))),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('시간 추가',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary)),
                const SizedBox(height: 6),
                Text('추가할 시간을 입력하세요',
                    style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary)),
                const SizedBox(height: 20),
                Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                  _TimeInput(
                      label: '시간',
                      value: addH,
                      max: 23,
                      onChanged: onChangeH),
                  Padding(
                      padding:
                          const EdgeInsets.only(top: 18),
                      child: Text(':',
                          style: TextStyle(
                              fontSize: 20,
                              color:
                                  context.textSecondary))),
                  _TimeInput(
                      label: '분',
                      value: addM,
                      max: 59,
                      onChanged: onChangeM),
                  Padding(
                      padding:
                          const EdgeInsets.only(top: 18),
                      child: Text(':',
                          style: TextStyle(
                              fontSize: 20,
                              color:
                                  context.textSecondary))),
                  _TimeInput(
                      label: '초',
                      value: addS,
                      max: 59,
                      onChanged: onChangeS),
                ]),
                if (hasAdd) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: context.subtleBg,
                        borderRadius:
                            BorderRadius.circular(12)),
                    child: Column(children: [
                      Text('추가 후 남은 시간',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary)),
                      const SizedBox(height: 4),
                      Text(formatTime(preview),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary)),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: GestureDetector(
                          onTap: onCancel,
                          child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 13),
                              decoration: BoxDecoration(
                                  color: context.subtleBg,
                                  borderRadius:
                                      BorderRadius.circular(
                                          12)),
                              child: Center(
                                  child: Text('취소',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.w500,
                                          color: context
                                              .textPrimary)))))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: GestureDetector(
                          onTap: hasAdd ? onConfirm : null,
                          child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 13),
                              decoration: BoxDecoration(
                                  color: hasAdd
                                      ? context.primaryColor
                                      : context.borderColor,
                                  borderRadius:
                                      BorderRadius.circular(
                                          12)),
                              child: Center(
                                  child: Text('추가하기',
                                      style: TextStyle(
                                          color: hasAdd
                                              ? context.onPrimary
                                              : context
                                                  .textSecondary,
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.w500)))))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}