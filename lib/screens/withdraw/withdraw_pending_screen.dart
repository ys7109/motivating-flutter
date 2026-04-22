import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class WithdrawPendingScreen extends StatefulWidget {
  const WithdrawPendingScreen({super.key});
  @override
  State<WithdrawPendingScreen> createState() => _WithdrawPendingScreenState();
}

class _WithdrawPendingScreenState extends State<WithdrawPendingScreen> {
  bool _loading = false;

  String get _dateStr {
    final d = context.read<AppProvider>().userData?.withdrawScheduledAt;
    if (d == null) return '';
    return '${d.month}월 ${d.day}일';
  }

  Future<void> _handleCancel() async {
    setState(() => _loading = true);
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;
      await FirestoreService().updateUser(uid, {'withdrawScheduledAt': null});
      await context.read<AppProvider>().init();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: const Color(0xFFFFF3F3), borderRadius: BorderRadius.circular(20)),
                child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 24),
              const Text('탈퇴 진행 중', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              const Text('이 계정은 현재 탈퇴가 진행 중입니다.', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text('$_dateStr에 탈퇴가 완료될 예정입니다.', style: const TextStyle(fontSize: 15, color: AppTheme.danger, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(16)),
                child: const Text('탈퇴를 취소하시겠습니까?\n취소 시 계정이 정상 복구됩니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.7)),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _loading ? null : _handleCancel,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(14)),
                  child: Center(child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('예, 탈퇴를 취소합니다', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _loading ? null : () => app.signOut(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('아니오, 로그아웃합니다', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}