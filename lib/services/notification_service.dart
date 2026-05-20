import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../widgets/main_nav.dart';
import '../providers/app_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService._showLocalNotification(message);
}

String? currentOpenChatId;

class NotificationService {
  static int? pendingTab;
  static String? pendingChatId;
  static String? pendingChatTitle;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialized = false;

  static const _activityChannel = AndroidNotificationChannel(
    'activity', '활동 알림',
    description: '좋아요, 댓글, 친구 요청 알림',
    importance: Importance.high,
  );

  static const _chatChannel = AndroidNotificationChannel(
    'chat', '채팅 알림',
    description: '새 채팅 메시지 알림',
    importance: Importance.high,
  );

  static const _goalAlarmChannel = AndroidNotificationChannel(
    'goal_alarm', '목표 알림',
    description: '목표별 개인 알림',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_activityChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);
    await androidPlugin?.createNotificationChannel(_goalAlarmChannel);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);

    _initialized = true;
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? '';
    final msgChatId = message.data['chatId'] ?? '';
    if (type == 'chat' && msgChatId == currentOpenChatId) return;

    final channelId = type == 'chat' ? 'chat' : 'activity';
    final channelName = type == 'chat' ? '채팅 알림' : '활동 알림';

    if (type == 'chat' && msgChatId.isNotEmpty) {
      List<String> lines;
      final inboxJson = message.data['inboxLines'];
      if (inboxJson != null && inboxJson.isNotEmpty) {
        try {
          lines = List<String>.from(
              (jsonDecode(inboxJson) as List).map((e) => e.toString()));
        } catch (_) {
          lines = [notification.body ?? ''];
        }
      } else {
        _chatMessages.putIfAbsent(msgChatId, () => []);
        _chatMessages[msgChatId]!.add(notification.body ?? '');
        if (_chatMessages[msgChatId]!.length > 5) {
          _chatMessages[msgChatId]!.removeAt(0);
        }
        lines = _chatMessages[msgChatId]!;
      }

      await _plugin.show(
        msgChatId.hashCode.abs(),
        notification.title,
        lines.last,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId, channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            tag: msgChatId,
            styleInformation: InboxStyleInformation(
              lines,
              contentTitle: notification.title,
              summaryText: '메시지 ${lines.length}개',
            ),
          ),
        ),
      );
      return;
    }

    await _plugin.show(
      notification.hashCode.abs(),
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId, channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'] ?? '';

    if (type == 'chat') {
      pendingTab = 3;
      pendingChatId = message.data['chatId'];
      pendingChatTitle = message.notification?.title ?? '채팅';
      // 2번: 채팅 알림 탭 시 해당 채팅방 알림 dismiss
      final chatId = message.data['chatId'];
      if (chatId != null && chatId.isNotEmpty) {
        dismissChatNotification(chatId);
      }
    } else if (type == 'like' || type == 'comment' || type == 'reply'
        || type == 'friend_request' || type == 'friend_accepted') {
      pendingTab = 3;
      pendingChatId = null;
      pendingChatTitle = null;
      // 2번: 활동 알림 탭 시 해당 알림 dismiss
      dismissActivityNotification(message);
    }
  }

  // 2번: 채팅방 알림 dismiss — chatId 기반으로 해당 채팅 알림 제거
  static Future<void> dismissChatNotification(String chatId) async {
    try {
      // tag 기반 dismiss (Android)
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.cancel(chatId.hashCode.abs(), tag: chatId);
      // id 기반도 함께 취소 (fallback)
      await _plugin.cancel(chatId.hashCode.abs());
      // 메모리 캐시 초기화
      _chatMessages.remove(chatId);
    } catch (_) {}
  }

  // 2번: 활동 알림 dismiss — 알림 hashCode 기반으로 해당 알림 제거
  static Future<void> dismissActivityNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification != null) {
        await _plugin.cancel(notification.hashCode.abs());
      }
    } catch (_) {}
  }

  // 2번: 활동 알림 전체 dismiss — activity 채널의 모든 알림 제거
  static Future<void> dismissAllActivityNotifications() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final activeNotifs = await androidPlugin?.getActiveNotifications();
      if (activeNotifs == null) return;
      for (final notif in activeNotifs) {
        if (notif.channelId == 'activity') {
          await _plugin.cancel(notif.id ?? 0);
        }
      }
    } catch (_) {}
  }

  static bool _tokenRefreshRegistered = false;
  static final Map<String, List<String>> _chatMessages = {};

  static Future<void> saveFcmToken(String uid) async {
    try {
      await _fcm.setAutoInitEnabled(true);
      String? token;
      for (int i = 0; i < 5; i++) {
        try {
          token = await _fcm.getToken()
              .timeout(const Duration(seconds: 10), onTimeout: () => null);
        } catch (e) {
          print('FCM getToken 시도 ${i+1} 실패: $e');
        }
        if (token != null) break;
        print('FCM getToken null, ${i+1}회 재시도 대기중...');
        await Future.delayed(const Duration(seconds: 2));
      }

      if (token == null) {
        print('FCM 토큰 발급 최종 실패: $uid');
        return;
      }

      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final existing = snap.data()?['fcmToken'];
      if (existing != null && existing == token) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      print('FCM 토큰 저장 완료: ${token.substring(0, 20)}...');

      if (!_tokenRefreshRegistered) {
        _tokenRefreshRegistered = true;
        _fcm.onTokenRefresh.listen((newToken) {
          FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': newToken,
          }, SetOptions(merge: true));
          print('FCM 토큰 갱신: ${newToken.substring(0, 20)}...');
        });
      }
    } catch (e) {
      print('FCM 토큰 저장 실패: $e');
    }
  }

  static Future<void> deleteFcmToken(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {}
  }

  static Future<bool> requestPermission() async {
    final fcmPermission = await _fcm.requestPermission(
        alert: true, badge: true, sound: true);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return fcmPermission.authorizationStatus != AuthorizationStatus.denied;
    }
    final result = await android.requestNotificationsPermission();
    return (result ?? true) &&
        fcmPermission.authorizationStatus != AuthorizationStatus.denied;
  }

  static Future<bool> hasPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.areNotificationsEnabled();
    return granted ?? true;
  }

  static Future<void> scheduleDailyGoalReminder() async {
    final mode = await _getScheduleMode();
    await _plugin.zonedSchedule(
      1,
      '오늘의 목표를 확인하세요 🎯',
      '오늘 달성할 목표가 기다리고 있어요!',
      _nextInstanceOf(9, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goal', '목표 리마인더',
          channelDescription: '매일 아침 목표 확인 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 1번: 스트릭 → 연속 출석으로 텍스트 수정
  static Future<void> scheduleStreakRiskReminder(int streak) async {
    final mode = await _getScheduleMode();
    await _plugin.zonedSchedule(
      2,
      '연속 출석이 끊길 위기예요! 🔥',
      '오늘 접속하지 않으면 $streak일 연속 출석이 사라져요.',
      _nextInstanceOf(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_risk', '연속 출석 위기 알림',
          channelDescription: '연속 출석이 끊길 위기일 때 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<AndroidScheduleMode> _getScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> scheduleGoalAlarm({
    required String goalId,
    required String goalTitle,
    required String amPm,
    required int hour,
    required int minute,
    required bool isRepeat,
    required String scheduledDate,
  }) async {
    final notifId = goalId.hashCode.abs() % 100000 + 10000;
    int hour24 = hour;
    if (amPm == '오전' && hour == 12) hour24 = 0;
    if (amPm == '오후' && hour != 12) hour24 = hour + 12;
    final mode = await _getScheduleMode();

    if (isRepeat) {
      final scheduledTime = _nextInstanceOf(hour24, minute);
      await _plugin.zonedSchedule(
        notifId,
        '반복 목표 알림 🔄',
        '[$goalTitle] 오늘 완료했나요?',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'goal_alarm', '목표 알림',
            channelDescription: '목표별 개인 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      final parts = scheduledDate.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final scheduledTime = tz.TZDateTime(tz.local, year, month, day, hour24, minute);
      if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        notifId,
        '목표 알림 🎯',
        '[$goalTitle] 오늘 완료했나요?',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'goal_alarm', '목표 알림',
            channelDescription: '목표별 개인 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelGoalAlarm(String goalId) async {
    final notifId = goalId.hashCode.abs() % 100000 + 10000;
    await _plugin.cancel(notifId);
  }

  static Future<void> cancelNotification(int id) async => await _plugin.cancel(id);
  static Future<void> cancelAll() async => await _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}