import 'dart:convert';
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
  // 백그라운드에서 채팅 알림을 인박스 스타일로 표시
  await NotificationService._showLocalNotification(message);
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

  // 목표 알림 채널 — 사용자가 설정한 시간에 목표별 개인 알림
  static const _goalAlarmChannel = AndroidNotificationChannel(
    'goal_alarm', '목표 알림',
    description: '목표별 개인 알림',
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
    // 목표 알림 채널 생성
    await androidPlugin?.createNotificationChannel(_goalAlarmChannel);

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

    // 채팅 알림 — 인박스 스타일로 메시지 누적 표시
    if (type == 'chat' && msgChatId.isNotEmpty) {
      // inboxLines: FCM data에서 서버가 보내준 최근 메시지 목록
      List<String> lines;
      final inboxJson = message.data['inboxLines'];
      if (inboxJson != null && inboxJson.isNotEmpty) {
        // 서버에서 받은 최근 메시지 목록 사용
        try {
          lines = List<String>.from(
            (jsonDecode(inboxJson) as List).map((e) => e.toString()));
        } catch (_) {
          lines = [notification.body ?? ''];
        }
      } else {
        // fallback — 로컬 누적 메시지 사용 (포그라운드)
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
            // 인박스 스타일 — 여러 메시지를 펼쳐서 보여줌
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

    // 활동 알림은 각각 별도 알림으로 표시
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

  // 채팅방별 누적 메시지 목록 — 인박스 스타일 알림용
  static final Map<String, List<String>> _chatMessages = {};

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

      // 기존 토큰과 동일하면 Firestore 업데이트 스킵 (단, 기존 토큰이 없으면 무조건 저장)
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
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
  // exact alarm 권한 있으면 정확한 시간, 없으면 inexact로 폴백
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
      // 권한 있으면 exact, 없으면 inexact — 런타임 분기로 에러 방지
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 스트릭 위기 알림 — 매일 오후 8시 알림 예약
  // exact alarm 권한 있으면 정확한 시간, 없으면 inexact로 폴백
  static Future<void> scheduleStreakRiskReminder(int streak) async {
    final mode = await _getScheduleMode();
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
      // 권한 있으면 exact, 없으면 inexact — 런타임 분기로 에러 방지
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // exact alarm 권한 런타임 체크 — 권한 있으면 exact, 없으면 inexact 반환
  // Android 12+ (API 31+)부터 exact alarm에 별도 권한 필요
  // ManifestÈ SCHEDULE_EXACT_ALARM 선언 없이도 기기가 허용한 경우 exact 사용 가능
  static Future<AndroidScheduleMode> _getScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle   // 정확한 시간 알림
        : AndroidScheduleMode.inexactAllowWhileIdle; // 권한 없으면 근사 시간으로 폴백
  }

  // 목표별 알림 예약 — 사용자가 설정한 시간에 정확히 1회 또는 매일 반복
  // notificationId: 목표 ID 해시 기반 고유값 — 목표마다 별도 알림 슬롯 사용
  // scheduledDate: 단일 목표는 해당 날짜, 반복 목표는 매일 반복
  static Future<void> scheduleGoalAlarm({
    required String goalId,
    required String goalTitle,
    required String amPm,      // '오전' | '오후'
    required int hour,         // 1~12
    required int minute,       // 0~59
    required bool isRepeat,    // 반복 목표 여부 — true면 매일 반복, false면 1회
    required String scheduledDate, // 단일 목표 날짜 (yyyy-MM-dd)
  }) async {
    // 알림 ID — goalId 해시값 절댓값 사용 (int 범위 초과 방지)
    final notifId = goalId.hashCode.abs() % 100000 + 10000;

    // 12시간제 → 24시간제 변환
    int hour24 = hour;
    if (amPm == '오전' && hour == 12) hour24 = 0;       // 오전 12시 → 0시
    if (amPm == '오후' && hour != 12) hour24 = hour + 12; // 오후 1~11시 → 13~23시

    final mode = await _getScheduleMode();

    if (isRepeat) {
      // 반복 목표 — 매일 같은 시간 반복 알림
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
        // 매일 같은 시간 반복 — time 컴포넌트만 매칭
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      // 단일 목표 — 해당 날짜 1회만 알림
      final parts = scheduledDate.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      // 지정 날짜의 설정 시간으로 정확히 1회 예약
      final scheduledTime = tz.TZDateTime(
          tz.local, year, month, day, hour24, minute);
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
        // 1회 알림 — matchDateTimeComponents 없음
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // 목표별 알림 취소 — 목표 삭제 또는 알림 해제 시 호출
  static Future<void> cancelGoalAlarm(String goalId) async {
    final notifId = goalId.hashCode.abs() % 100000 + 10000;
    await _plugin.cancel(notifId);
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