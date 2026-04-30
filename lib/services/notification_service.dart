import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// 백그라운드 메시지 핸들러 — 최상위 함수여야 함
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서는 FCM이 자동으로 시스템 알림을 표시해줌
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialized = false;

  // 알림 채널 (포그라운드 FCM용)
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

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // 로컬 알림 초기화
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    // 포그라운드 FCM 알림 채널 생성
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_activityChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);

    // FCM 권한 요청
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 포그라운드 메시지 수신 시 로컬 알림으로 표시
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _initialized = true;
  }

  // 포그라운드 수신 메시지를 로컬 알림으로 표시
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? '';
    final channelId = type == 'chat' ? 'chat' : 'activity';
    final channelName = type == 'chat' ? '채팅 알림' : '활동 알림';

    await _plugin.show(
      notification.hashCode,
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

  // FCM 토큰 조회 및 Firestore에 저장
  static Future<void> saveFcmToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
      // 토큰 갱신 시 자동 업데이트
      _fcm.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': newToken,
        });
      });
    } catch (e) {
      // 토큰 저장 실패 시 무시 (알림 없이 앱 동작)
    }
  }

  // FCM 토큰 삭제 (로그아웃 시)
  static Future<void> deleteFcmToken(String uid) async {
    try {
      await _fcm.deleteToken();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      // 무시
    }
  }

  // 권한 요청
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission();
    return result ?? false;
  }

  // 현재 알림 권한 상태 확인
  static Future<bool> hasPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.areNotificationsEnabled();
    return granted ?? false;
  }

  static Future<void> scheduleDailyGoalReminder() async {
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleStreakRiskReminder(int streak) async {
    await _plugin.zonedSchedule(
      2,
      '스트릭이 끊길 위기예요! 🔥',
      '오늘 접속하지 않으면 $streak일 스트릭이 사라져요.',
      _nextInstanceOf(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_risk', '스트릭 위기 알림',
          channelDescription: '스트릭이 끊길 위기일 때 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(int id) async => await _plugin.cancel(id);
  static Future<void> cancelAll() async => await _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}