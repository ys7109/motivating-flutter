import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../widgets/main_nav.dart';
import '../providers/app_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// 백그라운드 FCM 핸들러 — 최상위 함수여야 함 (Firebase 요구사항)
// data-only 메시지를 받으므로 백그라운드 isolate에서 직접 로컬 알림을 표시한다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 isolate는 별도 메모리이므로 알림 플러그인을 다시 초기화해야 함
  await NotificationService._initPlugin();
  await NotificationService._showLocalNotification(message);
}

// 현재 열려있는 채팅방 ID — 포그라운드 알림 중복 방지용
String? currentOpenChatId;

class NotificationService {
  // 알림 탭으로 앱 실행 시 이동할 탭/채팅방 정보
  static int? pendingTab;
  static String? pendingChatId;
  static String? pendingChatTitle;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialized = false;

  // 활동 알림 채널 — 좋아요, 댓글, 친구 요청
  static const _activityChannel = AndroidNotificationChannel(
    'activity', '활동 알림',
    description: '좋아요, 댓글, 친구 요청 알림',
    importance: Importance.high,
  );

  // 채팅 알림 채널 — 새 채팅 메시지
  static const _chatChannel = AndroidNotificationChannel(
    'chat', '채팅 알림',
    description: '새 채팅 메시지 알림',
    importance: Importance.high,
  );

  // 목표 알림 채널 — 사용자가 설정한 목표별 알림
  static const _goalAlarmChannel = AndroidNotificationChannel(
    'goal_alarm', '목표 알림',
    description: '목표별 개인 알림',
    importance: Importance.high,
  );

  // 앱 포그라운드 여부 — 백그라운드 전환 시 로컬 알림 중복 방지
  static bool _isAppInForeground = true;
  static void setAppForeground(bool isForeground) => _isAppInForeground = isForeground;

  // 알림 플러그인 초기화 여부 — 포그라운드/백그라운드 isolate 각각에서 1회 보장
  static bool _pluginInitialized = false;

  // 로컬 알림 탭 콜백 — 포그라운드 알림 탭 시 채팅방/소셜 탭 이동
  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // payload 형식: 'chat:{chatId}:{title}' 또는 'activity'
      if (payload.startsWith('chat:')) {
        final parts = payload.split(':');
        if (parts.length >= 2) {
          final chatId = parts[1];
          final title = parts.length >= 3 ? parts.sublist(2).join(':') : '채팅';
          pendingTab = 3;
          pendingChatId = chatId;
          pendingChatTitle = title;
          dismissChatNotification(chatId);
        }
      } else if (payload == 'activity') {
        pendingTab = 3;
        pendingChatId = null;
        pendingChatTitle = null;
      }
    }
  }

  // 로컬 알림 플러그인 + 채널 초기화 — 백그라운드 isolate에서도 호출됨
  static Future<void> _initPlugin() async {
    if (_pluginInitialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_activityChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);
    await androidPlugin?.createNotificationChannel(_goalAlarmChannel);
    _pluginInitialized = true;
  }

  // 알림 서비스 초기화 — 채널 생성, 권한 요청, FCM 리스너 등록
  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    await _initPlugin();

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 포그라운드일 때만 로컬 알림 표시 — 백그라운드면 FCM이 시스템 알림으로 자동 표시
    FirebaseMessaging.onMessage.listen((message) {
      if (_isAppInForeground) _showLocalNotification(message);
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

  // FCM 메시지를 로컬 알림으로 표시
  // 현재 열린 채팅방 알림은 표시 안 함
  // data-only 메시지를 받으므로 제목/본문은 data에서 읽는다 (notification 페이로드는 iOS 폴백).
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'] ?? '';
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'] ?? '';
    // 표시할 내용이 없으면 무시
    if ((title == null || title.isEmpty) && body.isEmpty) return;

    final msgChatId = message.data['chatId'] ?? '';
    // 현재 열려있는 채팅방 알림은 무시
    if (type == 'chat' && msgChatId == currentOpenChatId) return;

    final channelId = type == 'chat' ? 'chat' : 'activity';
    final channelName = type == 'chat' ? '채팅 알림' : '활동 알림';

    // 채팅 알림 — 인박스 스타일로 메시지 누적 표시
    if (type == 'chat' && msgChatId.isNotEmpty) {
      List<String> lines;
      final inboxJson = message.data['inboxLines'];
      if (inboxJson != null && inboxJson.isNotEmpty) {
        // 서버에서 받은 최근 메시지 목록 사용
        try {
          lines = List<String>.from(
              (jsonDecode(inboxJson) as List).map((e) => e.toString()));
        } catch (_) {
          lines = [body];
        }
      } else {
        // 로컬 캐시로 메시지 누적 (최대 5개)
        _chatMessages.putIfAbsent(msgChatId, () => []);
        _chatMessages[msgChatId]!.add(body);
        if (_chatMessages[msgChatId]!.length > 5) {
          _chatMessages[msgChatId]!.removeAt(0);
        }
        lines = _chatMessages[msgChatId]!;
      }

      await _plugin.show(
        msgChatId.hashCode.abs(),
        title,
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
              contentTitle: title,
              summaryText: '메시지 ${lines.length}개',
            ),
          ),
        ),
        // payload: 탭 시 채팅방 이동에 사용
        payload: 'chat:$msgChatId:${title ?? '채팅'}',
      );
      return;
    }

    // 활동 알림 — 각각 별도 알림으로 표시 (고유 ID로 서로 덮어쓰지 않게)
    await _plugin.show(
      DateTime.now().microsecondsSinceEpoch.remainder(1000000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId, channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'activity',
    );
  }

  // 알림 탭 처리 — 채팅/활동 알림 탭 시 소셜 탭 이동 예약
  static void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'] ?? '';

    if (type == 'chat') {
      // 채팅 알림 → 소셜 탭 + 해당 채팅방으로 이동
      pendingTab = 3;
      pendingChatId = message.data['chatId'];
      pendingChatTitle = message.notification?.title ?? '채팅';
      final chatId = message.data['chatId'];
      if (chatId != null && chatId.isNotEmpty) {
        dismissChatNotification(chatId);
      }
    } else if (type == 'like' || type == 'comment' || type == 'reply'
        || type == 'friend_request' || type == 'friend_accepted') {
      // 활동 알림 → 소셜 탭으로 이동
      pendingTab = 3;
      pendingChatId = null;
      pendingChatTitle = null;
      dismissActivityNotification(message);
    }
  }

  // 채팅방 알림 dismiss — chatId 기반으로 해당 채팅 알림 제거
  static Future<void> dismissChatNotification(String chatId) async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // tag 기반 dismiss (Android)
      await androidPlugin?.cancel(chatId.hashCode.abs(), tag: chatId);
      // id 기반 dismiss (fallback)
      await _plugin.cancel(chatId.hashCode.abs());
      _chatMessages.remove(chatId);
    } catch (_) {}
  }

  // 활동 알림 dismiss — 알림 hashCode 기반으로 해당 알림 제거
  static Future<void> dismissActivityNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification != null) {
        await _plugin.cancel(notification.hashCode.abs());
      }
    } catch (_) {}
  }

  // 활동 알림 전체 dismiss — activity 채널의 모든 알림 제거
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

  // 토큰 갱신 리스너 중복 등록 방지 플래그
  static bool _tokenRefreshRegistered = false;
  // 채팅방별 누적 메시지 목록 — 인박스 스타일 알림용
  static final Map<String, List<String>> _chatMessages = {};

  // FCM 토큰 조회 및 Firestore에 저장
  // 최대 5회 재시도 — 릴리즈 빌드에서 getToken 지연 대응
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

      // 기존 토큰과 동일하면 Firestore 업데이트 스킵
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final existing = snap.data()?['fcmToken'];
      if (existing != null && existing == token) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      print('FCM 토큰 저장 완료: ${token.substring(0, 20)}...');

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

  // FCM 토큰 삭제 — 로그아웃 시 Firestore에서만 제거
  static Future<void> deleteFcmToken(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {}
  }

  // 알림 권한 요청
  static Future<bool> requestPermission() async {
    final fcmPermission = await _fcm.requestPermission(
        alert: true, badge: true, sound: true);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return fcmPermission.authorizationStatus != AuthorizationStatus.denied;
    }
    final result = await android.requestNotificationsPermission();
    // Android 12 이하처럼 런타임 권한이 없는 기기는 null을 허용 상태로 처리
    return (result ?? true) &&
        fcmPermission.authorizationStatus != AuthorizationStatus.denied;
  }

  // 현재 알림 권한 상태 확인
  static Future<bool> hasPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.areNotificationsEnabled();
    return granted ?? true;
  }

  // 일일 목표 리마인더 예약 — 매일 오전 9시
  static Future<void> scheduleDailyGoalReminder() async {
    try {
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
    } catch (e) {
      print('일일 목표 알림 예약 실패: $e');
    }
  }

  // 연속 출석 위기 알림 예약 — 오늘 출석했으면 다음 날 오후 8시로 예약
  static Future<void> scheduleStreakRiskReminder(int streak, {String? lastAttendDate}) async {
    try {
      final mode = await _getScheduleMode();
      final now = tz.TZDateTime.now(tz.local);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
      if (lastAttendDate == today || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await cancelNotification(2);
      await _plugin.zonedSchedule(
        2,
        '연속 출석이 끊길 위기예요! 🔥',
        '오늘 접속하지 않으면 $streak일 연속 출석이 사라져요.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_risk', '연속 출석 위기 알림',
            channelDescription: '연속 출석이 끊길 위기일 때 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('연속 출석 알림 예약 실패: $e');
    }
  }

  // exact alarm 권한 런타임 체크 — 권한 있으면 exact, 없으면 inexact 반환
  static Future<AndroidScheduleMode> _getScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // 목표별 알림 예약 — 단일 목표는 1회, 반복 목표는 매일 반복
  static Future<void> scheduleGoalAlarm({
    required String goalId,
    required String goalTitle,
    required String amPm,
    required int hour,
    required int minute,
    required bool isRepeat,
    required String scheduledDate,
  }) async {
    // 알림 ID — goalId 해시값 기반 고유값
    final notifId = goalId.hashCode.abs() % 100000 + 10000;
    // 12시간제 → 24시간제 변환
    int hour24 = hour;
    if (amPm == '오전' && hour == 12) hour24 = 0;
    if (amPm == '오후' && hour != 12) hour24 = hour + 12;
    final mode = await _getScheduleMode();

    if (isRepeat) {
      // 반복 목표 — 매일 같은 시간 반복
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
      // 단일 목표 — 해당 날짜 1회만
      final parts = scheduledDate.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final scheduledTime = tz.TZDateTime(tz.local, year, month, day, hour24, minute);
      // 이미 지난 시간이면 예약 스킵
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

  // 목표별 알림 취소 — 목표 삭제 또는 알림 해제 시 호출
  static Future<void> cancelGoalAlarm(String goalId) async {
    final notifId = goalId.hashCode.abs() % 100000 + 10000;
    try {
      await _plugin.cancel(notifId);
    } catch (e) {
      print('목표 알림 취소 실패: $e');
    }
  }

  // 특정 알림 취소
  static Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      print('알림 취소 실패: $e');
    }
  }

  // 전체 알림 취소
  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      print('전체 알림 취소 실패: $e');
    }
  }

  // 다음 예약 시각 계산 — 이미 지난 시간이면 다음 날로 예약
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}
