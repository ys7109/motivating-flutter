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
    const typeIcon = {'attendance': '📅', 'attendance_special': '🎁', 'admin': '📣'};
    const typeLabel = {'attendance': '출석 보상', 'attendance_special': '특별 보상', 'admin': '관리자 지급'};

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios, size: 18, color: context.textSecondary)),
                const SizedBox(width: 12),
                Text('우편함', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.textPrimary)),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(99)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () async { setState(() => _refreshing = true); await app.loadMailbox(); setState(() => _refreshing = false); },
                  child: Text(_refreshing ? '새로고침 중...' : '새로고침', style: TextStyle(fontSize: 13, color: context.textSecondary)),
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
                      style: const TextStyle(fontSize: 13, color: Color(0xFFc47f00))),
                ),
              ),
            Expanded(
              child: mailbox.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('📭', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 12),
                      Text('우편함이 비어있어요', style: TextStyle(fontSize: 15, color: context.textSecondary)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: mailbox.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final mail = mailbox[i];
                        final isSelected = _selected == mail.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = isSelected ? null : mail.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: !mail.read ? context.primaryColor : context.borderColor, width: !mail.read ? 1.5 : 0.5),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(typeIcon[mail.type] ?? '📬', style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    if (!mail.read) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.danger)),
                                    Expanded(child: Text(mail.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary), overflow: TextOverflow.ellipsis)),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(typeLabel[mail.type] ?? '보상', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                ])),
                                if (!mail.claimed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(99)),
                                    child: const Text('수령 가능', style: TextStyle(fontSize: 11, color: Color(0xFF2e7d32), fontWeight: FontWeight.w500)),
                                  )
                                else
                                  Text('수령 완료', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                              ]),
                              if (isSelected) ...[
                                const SizedBox(height: 14),
                                Divider(height: 1, color: context.dividerColor),
                                const SizedBox(height: 14),
                                Text(mail.body, style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.7)),
                                if (mail.reward.xp > 0 || mail.reward.reviveItem > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: context.subtleBg, borderRadius: BorderRadius.circular(10)),
                                    child: Row(children: [
                                      if (mail.reward.xp > 0) Column(children: [
                                        Text('+${mail.reward.xp}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                        Text('XP', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                      ]),
                                      if (mail.reward.reviveItem > 0) ...[
                                        const SizedBox(width: 16),
                                        Column(children: [
                                          Text('🛡️ +${mail.reward.reviveItem}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                          Text('부활 아이템', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                        ]),
                                      ],
                                    ]),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(children: [
                                  if (!mail.claimed)
                                    Expanded(child: GestureDetector(
                                      onTap: () { app.claimMailReward(mail.id); setState(() => _selected = null); },
                                      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(10)),
                                        child: Center(child: Text('보상 수령', style: TextStyle(
                                            color: context.isDark ? Colors.black : Colors.white, fontSize: 14, fontWeight: FontWeight.w500)))),
                                    )),
                                  if (!mail.claimed) const SizedBox(width: 8),
                                  Expanded(child: GestureDetector(
                                    onTap: () { app.deleteMailItem(mail.id); setState(() => _selected = null); },
                                    child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(10)),
                                      child: Center(child: Text('삭제', style: TextStyle(color: context.textSecondary, fontSize: 14)))),
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
