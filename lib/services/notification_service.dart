import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../widgets/main_nav.dart';
import '../providers/app_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// 백그라운드 메시지 핸들러 — 최상위 함수여야 함 (Firebase 요구사항)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서는 FCM이 자동으로 시스템 알림을 표시해줌
}

// 현재 열려있는 채팅방 ID — 포그라운드 알림 필터링용
String? currentOpenChatId;

class NotificationService {
  // 알림 탭으로 앱 실행 시 소셜 탭으로 이동 — MainNav initState에서 처리
  static int? pendingTab;
  // 채팅 알림 탭 시 이동할 채팅방 ID
  static String? pendingChatId;
  static String? pendingChatTitle;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialized = false;

  // 활동 알림 채널 — 좋아요, 댓글, 친구 요청 알림
  static const _activityChannel = AndroidNotificationChannel(
    'activity', '활동 알림',
    description: '좋아요, 댓글, 친구 요청 알림',
    importance: Importance.high,
  );

  // 채팅 알림 채널 — 새 채팅 메시지 알림
  static const _chatChannel = AndroidNotificationChannel(
    'chat', '채팅 알림',
    description: '새 채팅 메시지 알림',
    importance: Importance.high,
  );

  // 알림 서비스 초기화 — 로컬 알림 채널 생성, FCM 권한 요청, 메시지 리스너 등록
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

    // FCM 알림 권한 요청
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 포그라운드 메시지 수신 시 로컬 알림으로 표시
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 백그라운드에서 알림 탭해서 앱 열 때
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // 앱 종료 상태에서 알림 탭해서 앱 열 때
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);

    _initialized = true;
  }

  // 포그라운드 수신 메시지를 로컬 알림으로 표시
  // 현재 열려있는 채팅방의 알림은 무시
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? '';
    final msgChatId = message.data['chatId'] ?? '';
    // 현재 열려있는 채팅방 알림은 표시 안 함
    if (type == 'chat' && msgChatId == currentOpenChatId) return;

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

  // 알림 탭 처리 — 채팅/활동 알림 탭 시 소셜 탭 이동 예약
  // MainNav가 준비된 후 pendingTab을 확인해서 탭 전환
  static void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'] ?? '';

    if (type == 'chat') {
      // 채팅 알림 → 소셜 탭 이동 + 채팅방 정보 저장
      pendingTab = 3;
      pendingChatId = message.data['chatId'];
      pendingChatTitle = message.notification?.title ?? '채팅';
    } else if (type == 'like' || type == 'comment' || type == 'reply'
        || type == 'friend_request' || type == 'friend_accepted') {
      // 활동 알림 → 소셜 탭 이동 예약
      pendingTab = 3;
      pendingChatId = null;
      pendingChatTitle = null;
    }
  }

  // onTokenRefresh 중복 등록 방지용 플래그
  static bool _tokenRefreshRegistered = false;

  // FCM 토큰 조회 및 Firestore에 저장
  // 토큰이 null이면 권한 재요청 후 재시도
  static Future<void> saveFcmToken(String uid) async {
    try {
      // 최대 5회 재시도 — 릴리즈 빌드에서 getToken 지연 대응
      String? token;
      for (int i = 0; i < 5; i++) {
        try {
          token = await _fcm.getToken()
              .timeout(const Duration(seconds: 10), onTimeout: () => null);
        } catch (e) {
          print('FCM getToken 시도 \${i+1} 실패: \$e');
        }
        if (token != null) break;
        print('FCM getToken null, \${i+1}회 재시도 대기중...');
        await Future.delayed(const Duration(seconds: 2));
      }

      if (token == null) {
        print('FCM 토큰 발급 최종 실패: \$uid');
        return;
      }

      // 기존 토큰과 동일하면 Firestore 업데이트 스킵 (단, 기존 토큰이 없으면 무조건 저장)
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final existing = snap.data()?['fcmToken'];
      if (existing != null && existing == token) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      print('FCM 토큰 저장 완료: \${token.substring(0, 20)}...');

      // 토큰 갱신 리스너 — 앱 생애주기당 1회만 등록
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

  // FCM 토큰 삭제 — 로그아웃 시 Firestore에서만 제거 (토큰 폐기 X)
  // deleteToken()은 호출하지 않음 — 폐기하면 재로그인 시 새 토큰 발급 비용 발생
  static Future<void> deleteFcmToken(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      // 토큰 삭제 실패 시 무시
    }
  }

  // 알림 권한 요청
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

  // 일일 목표 리마인더 — 매일 오전 9시 알림 예약
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

  // 스트릭 위기 알림 — 매일 오후 8시 알림 예약
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

  // 특정 알림 취소
  static Future<void> cancelNotification(int id) async => await _plugin.cancel(id);

  // 전체 알림 취소
  static Future<void> cancelAll() async => await _plugin.cancelAll();

  // 다음 예약 시각 계산 — 이미 지난 시간이면 다음 날로 예약
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}