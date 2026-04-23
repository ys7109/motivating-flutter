import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';

class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});
  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  String? _selected;
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final mailbox = app.mailbox;
    final unread = mailbox.where((m) => !m.read).length;
    final unclaimed = mailbox.where((m) => !m.claimed).length;
    const typeIcon = {
      'attendance': '📅',
      'attendance_special': '🎁',
      'admin': '📣',
    };
    const typeLabel = {
      'attendance': '출석 보상',
      'attendance_special': '특별 보상',
      'admin': '관리자 지급',
    };

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(children: [
                GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 18, color: AppTheme.textSecondary)),
                const SizedBox(width: 12),
                const Text('우편함',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(99)),
                    child: Text('$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    setState(() => _refreshing = true);
                    await app.loadMailbox();
                    setState(() => _refreshing = false);
                  },
                  child: Text(_refreshing ? '새로고침 중...' : '새로고침',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ]),
            ),
            if (unclaimed > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      border: Border.all(color: const Color(0xFFFFE082)),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('📬 수령 가능한 보상이 $unclaimed개 있어요!',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFc47f00))),
                ),
              ),
            Expanded(
              child: mailbox.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('📭', style: TextStyle(fontSize: 32)),
                        SizedBox(height: 12),
                        Text('우편함이 비어있어요',
                            style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.textSecondary)),
                      ]))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: mailbox.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final mail = mailbox[i];
                        final isSelected = _selected == mail.id;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _selected = isSelected ? null : mail.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: !mail.read
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                  width: !mail.read ? 1.5 : 0.5),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(typeIcon[mail.type] ?? '📬',
                                        style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Row(children: [
                                            if (!mail.read)
                                              Container(
                                                  width: 6, height: 6,
                                                  margin: const EdgeInsets.only(right: 6),
                                                  decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: AppTheme.danger)),
                                            Expanded(
                                                child: Text(mail.title,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500),
                                                    overflow: TextOverflow.ellipsis)),
                                          ]),
                                          const SizedBox(height: 2),
                                          Text(typeLabel[mail.type] ?? '보상',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary)),
                                        ])),
                                    if (!mail.claimed)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius: BorderRadius.circular(99)),
                                        child: const Text('수령 가능',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF2e7d32),
                                                fontWeight: FontWeight.w500)),
                                      )
                                    else
                                      const Text('수령 완료',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary)),
                                  ]),
                                  if (isSelected) ...[
                                    const SizedBox(height: 14),
                                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                                    const SizedBox(height: 14),
                                    Text(mail.body,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary,
                                            height: 1.7)),
                                    if (mail.reward.xp > 0 ||
                                        mail.reward.reviveItem > 0) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFF9F9F9),
                                            borderRadius: BorderRadius.circular(10)),
                                        child: Row(children: [
                                          if (mail.reward.xp > 0)
                                            Column(children: [
                                              Text('+${mail.reward.xp}',
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w600)),
                                              const Text('XP',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.textSecondary)),
                                            ]),
                                          if (mail.reward.reviveItem > 0) ...[
                                            const SizedBox(width: 16),
                                            Column(children: [
                                              Text('🛡️ +${mail.reward.reviveItem}',
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w600)),
                                              const Text('부활 아이템',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.textSecondary)),
                                            ]),
                                          ],
                                        ]),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      if (!mail.claimed)
                                        Expanded(
                                            child: GestureDetector(
                                          onTap: () {
                                            app.claimMailReward(mail.id);
                                            setState(() => _selected = null);
                                          },
                                          child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 10),
                                              decoration: BoxDecoration(
                                                  color: AppTheme.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(10)),
                                              child: const Center(
                                                  child: Text('보상 수령',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500)))),
                                        )),
                                      if (!mail.claimed) const SizedBox(width: 8),
                                      Expanded(
                                          child: GestureDetector(
                                        onTap: () {
                                          app.deleteMailItem(mail.id);
                                          setState(() => _selected = null);
                                        },
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: AppTheme.border),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: const Center(
                                                child: Text('삭제',
                                                    style: TextStyle(
                                                        color: AppTheme.textSecondary,
                                                        fontSize: 14)))),
                                      )),
                                    ]),
                                  ],
                                ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}