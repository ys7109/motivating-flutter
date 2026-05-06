import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../providers/app_provider.dart';

// 백그라운드 FCM 메시지 핸들러 — Firebase Messaging에서 최상위 함수로 호출
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서는 FCM 시스템 알림이 자동 표시되므로 별도 처리를 하지 않음
}

// 현재 열려 있는 채팅방 ID — 같은 채팅방의 foreground 알림을 숨길 때 사용
String? currentOpenChatId;

class NotificationService {
  // 알림 탭 이동 예약 — MainNav가 준비된 뒤 소셜 탭으로 이동할 때 사용
  static int? pendingTab;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;

  // 활동 알림 채널 — 좋아요, 댓글, 친구 요청 알림 표시
  static const _activityChannel = AndroidNotificationChannel(
    'activity',
    '활동 알림',
    description: '좋아요, 댓글, 친구 요청 알림',
    importance: Importance.high,
  );

  // 채팅 알림 채널 — 새 채팅 메시지 알림 표시
  static const _chatChannel = AndroidNotificationChannel(
    'chat',
    '채팅 알림',
    description: '새 채팅 메시지 알림',
    importance: Importance.high,
  );

  // 알림 서비스 초기화 — 로컬 알림, FCM 수신, 알림 탭 처리를 설정
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

  // foreground FCM 수신 처리 — 현재 채팅방 알림은 숨기고 나머지는 로컬 알림으로 표시
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? '';
    final msgChatId = message.data['chatId'] ?? '';
    if (type == 'chat' && msgChatId == currentOpenChatId) return;

    final channelId = type == 'chat' ? 'chat' : 'activity';
    final channelName = type == 'chat' ? '채팅 알림' : '활동 알림';

    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // 알림 탭 처리 — 채팅/활동 알림을 누르면 소셜 탭 이동을 예약
  static void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'] ?? '';
    final navigatorState = AppProvider.navigatorKey.currentState;
    if (navigatorState == null) return;

    if (type == 'chat') {
      pendingTab = 3;
    } else if (type == 'like' ||
        type == 'comment' ||
        type == 'reply' ||
        type == 'friend_request' ||
        type == 'friend_accepted') {
      pendingTab = 3;
    }
  }

  // FCM 토큰 조회 및 Firestore 저장 — 단일 토큰과 기기별 토큰 목록을 함께 유지
  static Future<void> saveFcmToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('FCM token is null for $uid');
        return;
      }

      await _saveTokenToFirestore(uid, token);
      debugPrint('FCM token saved for $uid');

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
        await _saveTokenToFirestore(uid, newToken);
        debugPrint('FCM token refreshed for $uid');
      });
    } catch (e) {
      debugPrint('FCM token save failed for $uid: $e');
    }
  }

  // FCM 토큰 저장 — 기존 fcmToken 호환성과 다중 기기 fcmTokens 배열을 동시에 갱신
  static Future<void> _saveTokenToFirestore(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  // FCM 토큰 삭제 — 로그아웃 기기 토큰만 제거하고 다른 기기 토큰은 보존
  static Future<void> deleteFcmToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      await _fcm.deleteToken();

      if (token == null) {
        debugPrint('FCM token delete skipped because token is null for $uid');
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data();
        final currentToken = data?['fcmToken'];
        final tokens = List<String>.from(data?['fcmTokens'] as List? ?? []);
        final remainingTokens = tokens.where((item) => item != token).toList();
        tx.set(userRef, {
          'fcmTokens': FieldValue.arrayRemove([token]),
          if (currentToken == token && remainingTokens.isNotEmpty)
            'fcmToken': remainingTokens.last,
          if (currentToken == token && remainingTokens.isEmpty)
            'fcmToken': FieldValue.delete(),
        }, SetOptions(merge: true));
      });

      debugPrint('FCM token deleted for $uid');
    } catch (e) {
      debugPrint('FCM token delete failed for $uid: $e');
    }
  }

  // 알림 권한 요청 — Android 알림 표시 권한을 사용자에게 요청
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission();
    return result ?? false;
  }

  // 알림 권한 확인 — 현재 Android 알림 표시 권한 상태를 반환
  static Future<bool> hasPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.areNotificationsEnabled();
    return granted ?? false;
  }

  // 일일 목표 알림 예약 — 매일 오전 9시에 목표 확인 알림 표시
  static Future<void> scheduleDailyGoalReminder() async {
    await _plugin.zonedSchedule(
      1,
      '오늘의 목표를 확인하세요 🔔',
      '오늘 달성할 목표가 기다리고 있어요.',
      _nextInstanceOf(9, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goal',
          '목표 리마인더',
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

  // 스트릭 위기 알림 예약 — 매일 오후 8시에 출석 유지 알림 표시
  static Future<void> scheduleStreakRiskReminder(int streak) async {
    await _plugin.zonedSchedule(
      2,
      '스트릭이 끊길 수 있어요! 🔥',
      '오늘 접속하지 않으면 $streak일 스트릭이 사라져요.',
      _nextInstanceOf(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_risk',
          '스트릭 위기 알림',
          channelDescription: '스트릭이 끊기기 전 보내는 알림',
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

  // 단일 알림 취소 — 지정된 알림 ID의 예약/표시 알림을 제거
  static Future<void> cancelNotification(int id) async => await _plugin.cancel(id);

  // 전체 알림 취소 — 앱에서 예약하거나 표시한 모든 로컬 알림을 제거
  static Future<void> cancelAll() async => await _plugin.cancelAll();

  // 다음 예약 시각 계산 — 이미 지난 시간이면 다음 날 같은 시간으로 예약
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}
