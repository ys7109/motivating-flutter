import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/notification_service.dart';
import 'in_app_web_view.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _logoutModal = false;
  bool _withdrawModal = false;
  bool _cancelModal = false;
  // 5번 수정: 기본값 true
  Map<String, bool> _notif = {'goal': true, 'streak': true, 'mail': true};

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notif = {
        'goal': prefs.getBool('notif_goal') ?? true,
        'streak': prefs.getBool('notif_streak') ?? true,
        'mail': prefs.getBool('notif_mail') ?? true,
      };
    });
  }

  Future<void> _toggleNotif(String key) async {
    final newVal = !_notif[key]!;

    if (newVal) {
      // 켜는 경우: 권한 확인 후 없으면 요청
      final hasPermission = await NotificationService.hasPermission();
      if (!hasPermission) {
        final granted = await NotificationService.requestPermission();
        if (!granted) {
          if (mounted) {
            // 권한 거부 시 설정 앱으로 안내
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: context.modalBg,
                title: Text('알림 권한 필요', style: TextStyle(color: context.textPrimary)),
                content: Text('알림을 받으려면 설정에서 알림 권한을 허용해주세요.', style: TextStyle(color: context.textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('취소', style: TextStyle(color: context.textSecondary))),
                  TextButton(onPressed: () { Navigator.pop(context); openAppSettings(); }, child: Text('설정 열기', style: TextStyle(color: context.primaryColor))),
                ],
              ),
            );
          }
          return;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_$key', newVal);
    setState(() => _notif[key] = newVal);

    final app = context.read<AppProvider>();
    if (key == 'goal') {
      if (newVal) await NotificationService.scheduleDailyGoalReminder();
      else await NotificationService.cancelNotification(1);
    } else if (key == 'streak') {
      if (newVal) await NotificationService.scheduleStreakRiskReminder(app.userData?.streak ?? 0);
      else await NotificationService.cancelNotification(2);
    } else if (key == 'mail') {
      if (!newVal) await NotificationService.cancelNotification(3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final withdrawPending = app.userData?.withdrawScheduledAt != null;
    final withdrawDate = app.userData?.withdrawScheduledAt;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(children: [
        SafeArea(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.arrow_back_ios, size: 18, color: context.textSecondary)),
                  const SizedBox(width: 12),
                  Text('설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.textPrimary)),
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

              _Section(title: '디스플레이', children: [const _ThemeItem()]),

              _Section(title: '알림', children: [
                _ToggleItem(label: '목표 리마인더', sub: '매일 아침 9시 — 오늘의 목표 확인', value: _notif['goal']!, onChange: () => _toggleNotif('goal')),
                _ToggleItem(label: '스트릭 위기 알림', sub: '매일 저녁 8시 — 스트릭이 끊길 위기일 때', value: _notif['streak']!, onChange: () => _toggleNotif('streak')),
                _ToggleItem(label: '우편함 알림', sub: '새 보상이 도착하면 즉시 알림', value: _notif['mail']!, onChange: () => _toggleNotif('mail')),
              ]),

              _Section(title: '개인정보', children: [
                _LinkItem(label: '개인정보 처리방침', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InAppWebView(url: 'https://motivating-5a036.web.app/privacy.html', title: '개인정보 처리방침')))),
                _LinkItem(label: '이용약관', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InAppWebView(url: 'https://motivating-5a036.web.app/terms.html', title: '이용약관')))),
                _LinkItem(label: '오픈소스 라이선스', onTap: () {}),
                _LinkItem(label: '문의하기', onTap: () async {
                  final uri = Uri.parse('mailto:kimyusong77@gmail.com?subject=Motivating 문의');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                }),
              ]),

              _Section(title: '앱 정보', children: [
                const _InfoItem(label: '버전', value: '1.6.0'),
                const _InfoItem(label: '빌드', value: '2026.04.28'),
              ]),

              _Section(title: '계정', children: [
                _LinkItem(label: '로그아웃', danger: true, onTap: () => setState(() => _logoutModal = true)),
                _LinkItem(label: '회원 탈퇴', danger: true, onTap: () => setState(() => _withdrawModal = true)),
              ]),

              const SizedBox(height: 40),
            ]),
          ),
        ),

        if (_logoutModal)
          _ConfirmModal(title: '로그아웃', body: '로그아웃 하시겠습니까?', confirmLabel: '로그아웃',
              onCancel: () => setState(() => _logoutModal = false),
              onConfirm: () async { setState(() => _logoutModal = false); await app.signOut(); }),

        if (_withdrawModal)
          _WithdrawModal(
              onCancel: () => setState(() => _withdrawModal = false),
              onConfirm: () async { setState(() => _withdrawModal = false); await app.scheduleWithdraw(); }),

        if (_cancelModal)
          _ConfirmModal(title: '탈퇴 취소', body: '탈퇴 신청을 취소하시겠습니까?\n계정이 정상 복구됩니다.', confirmLabel: '탈퇴 취소',
              onCancel: () => setState(() => _cancelModal = false),
              onConfirm: () async { setState(() => _cancelModal = false); await app.cancelWithdraw(); if (mounted) Navigator.pop(context); }),
      ]),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final current = app.themeMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.dividerColor))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('테마', style: TextStyle(fontSize: 15, color: context.textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          _ThemeOption(label: '시스템', icon: Icons.brightness_auto_rounded, selected: current == ThemeMode.system, onTap: () => app.setThemeMode(ThemeMode.system)),
          const SizedBox(width: 8),
          _ThemeOption(label: '라이트', icon: Icons.light_mode_rounded, selected: current == ThemeMode.light, onTap: () => app.setThemeMode(ThemeMode.light)),
          const SizedBox(width: 8),
          _ThemeOption(label: '다크', icon: Icons.dark_mode_rounded, selected: current == ThemeMode.dark, onTap: () => app.setThemeMode(ThemeMode.dark)),
        ]),
      ]),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? context.primaryColor : context.subtleBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? context.primaryColor : context.borderColor, width: selected ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, size: 20, color: selected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? (context.isDark ? Colors.black : Colors.white) : context.textSecondary)),
          ]),
        ),
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
        child: Text(title, style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
      ),
      Container(
        decoration: BoxDecoration(color: context.surfaceColor, border: Border.symmetric(horizontal: BorderSide(color: context.dividerColor))),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.dividerColor))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 15, color: context.textPrimary)),
          Text(sub, style: TextStyle(fontSize: 12, color: context.textSecondary)),
        ])),
        GestureDetector(
          onTap: onChange,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 26,
            decoration: BoxDecoration(
              color: value ? context.primaryColor : (context.isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(99),
            ),
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
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.dividerColor))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 15, color: danger ? AppTheme.danger : context.textPrimary)),
          Icon(Icons.chevron_right, color: context.textSecondary, size: 18),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.dividerColor))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 15, color: context.textPrimary)),
        Text(value, style: TextStyle(fontSize: 14, color: context.textSecondary)),
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
    return Container(
      color: Colors.black54,
      child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: context.modalBg, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.6)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(onTap: onCancel, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('취소', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(onTap: onConfirm, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(confirmLabel, style: TextStyle(color: context.isDark ? Colors.black : Colors.white, fontSize: 15, fontWeight: FontWeight.w500)))))),
            ]),
          ]),
        ),
      )),
    );
  }
}

class _WithdrawModal extends StatelessWidget {
  final VoidCallback onCancel, onConfirm;
  const _WithdrawModal({required this.onCancel, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: context.modalBg, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚠️', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text('회원 탈퇴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
            const SizedBox(height: 8),
            Text('탈퇴 신청 후 30일 유예기간이 적용됩니다.', style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)),
              child: Text('• 30일 후 모든 데이터가 영구 삭제돼요\n• 삭제된 데이터는 복구할 수 없어요\n• 유예기간 중 재로그인하여 취소할 수 있어요',
                  style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.7)),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(onTap: onCancel, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('취소', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(onTap: onConfirm, child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('탈퇴 신청', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)))))),
            ]),
          ]),
        ),
      )),
    );
  }
}