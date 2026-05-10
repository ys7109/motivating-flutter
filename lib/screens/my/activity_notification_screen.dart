import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/activity_notification_service.dart';
import '../../models/notification_model.dart';
import '../social/character_avatar.dart';

class ActivityNotificationScreen extends StatefulWidget {
  const ActivityNotificationScreen({super.key});
  @override
  State<ActivityNotificationScreen> createState() => _ActivityNotificationScreenState();
}

class _ActivityNotificationScreenState extends State<ActivityNotificationScreen> {
  final _service = ActivityNotificationService();
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AppProvider>().authUser!.uid;
    setState(() => _loading = true);
    try {
      _notifications = await _service.getNotifications(uid);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final uid = context.read<AppProvider>().authUser!.uid;
    await _service.markAllAsRead(uid);
    await _load();
    // 앱 프로바이더의 unread count도 갱신
    if (mounted) context.read<AppProvider>().reloadUnreadNotifCount();
  }

  Future<void> _delete(String notifId) async {
    final uid = context.read<AppProvider>().authUser!.uid;
    await _service.deleteNotification(uid, notifId);
    await _load();
    if (mounted) context.read<AppProvider>().reloadUnreadNotifCount();
  }

  Future<void> _markRead(String notifId) async {
    final uid = context.read<AppProvider>().authUser!.uid;
    await _service.markAsRead(uid, notifId);
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == notifId);
      if (idx != -1) {
        _notifications[idx] = NotificationModel(
          id: _notifications[idx].id, type: _notifications[idx].type,
          fromUid: _notifications[idx].fromUid, fromName: _notifications[idx].fromName,
          fromCharacter: _notifications[idx].fromCharacter,
          diaryId: _notifications[idx].diaryId, diaryContent: _notifications[idx].diaryContent,
          commentContent: _notifications[idx].commentContent,
          read: true, createdAt: _notifications[idx].createdAt,
        );
      }
    });
    context.read<AppProvider>().reloadUnreadNotifCount();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_ios, size: 18, color: context.textSecondary),
                ),
                const SizedBox(width: 12),
                Text('활동 알림', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(99)),
                    child: Text('$unread', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: context.onPrimary)),
                  ),
                ],
              ]),
              if (unread > 0)
                GestureDetector(
                  onTap: _markAllRead,
                  child: Text('모두 읽음', style: TextStyle(fontSize: 13, color: context.primaryColor)),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: context.primaryColor))
                : _notifications.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🔔', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text('아직 활동 알림이 없어요', style: TextStyle(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 4),
                        Text('친구가 좋아요나 댓글을 남기면 여기에 표시돼요',
                            style: TextStyle(fontSize: 12, color: context.textSecondary)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load, color: context.primaryColor,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = _notifications[i];
                            return _NotifTile(
                              notif: n,
                              onTap: () => _markRead(n.id),
                              onDelete: () => _delete(n.id),
                            );
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _NotifTile({required this.notif, required this.onTap, required this.onDelete});

  IconData get _typeIcon {
    switch (notif.type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'reply': return Icons.reply_rounded;
      case 'friend_request': return Icons.person_add_rounded;
      case 'friend_accepted': return Icons.people_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _typeColor(BuildContext context) {
    switch (notif.type) {
      case 'like': return AppTheme.danger;
      case 'comment': return context.primaryColor;
      case 'reply': return context.primaryColor;
      case 'friend_request': return const Color(0xFF1b8a5a);
      case 'friend_accepted': return const Color(0xFF1b8a5a);
      default: return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(context);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.danger.withOpacity(0.1),
        child: const Icon(Icons.delete_outline, color: AppTheme.danger),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: notif.read ? Colors.transparent : context.primaryColor.withOpacity(0.05),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 아바타 + 타입 아이콘 오버레이
            Stack(clipBehavior: Clip.none, children: [
              CharacterAvatar(character: notif.fromCharacter, size: 42),
              Positioned(bottom: -2, right: -2, child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                    border: Border.all(color: context.surfaceColor, width: 1.5)),
                child: Icon(_typeIcon, size: 10, color: Colors.white),
              )),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 닉네임 + 메시지
              RichText(text: TextSpan(
                style: TextStyle(fontSize: 13, color: context.textPrimary, height: 1.4),
                children: [
                  TextSpan(text: notif.fromName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' ${notif.message}'),
                ],
              )),
              // 다이어리/댓글 내용 미리보기
              if (notif.commentContent != null) ...[
                const SizedBox(height: 4),
                Text(notif.commentContent!, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ] else if (notif.diaryContent != null) ...[
                const SizedBox(height: 4),
                Text(notif.diaryContent!, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
              const SizedBox(height: 4),
              Text(notif.timeAgo, style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ])),
            // 읽지 않은 경우 파란 점
            if (!notif.read)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.primaryColor),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}