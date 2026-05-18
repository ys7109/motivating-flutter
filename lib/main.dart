import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'providers/app_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/withdraw/withdraw_pending_screen.dart';
import 'widgets/main_nav.dart';
import 'services/notification_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// 백그라운드 FCM 핸들러 — 최상위 함수로 등록해야 함 (main 밖)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 백그라운드에서는 FCM이 자동으로 시스템 알림을 표시해줌
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 기기 최대 주사율 사용 (120fps 지원 기기)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check 초기화 — Storage 접근 시 No AppCheckProvider 에러 방지
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  // 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init();
  runApp(const MyApp());
}

Future<void> _requestNotificationPermissionOnFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyAsked = prefs.getBool('notif_permission_asked') ?? false;
  final notifEnabled = [
    prefs.getBool('notif_goal') ?? true,
    prefs.getBool('notif_streak') ?? true,
    prefs.getBool('notif_mail') ?? true,
    prefs.getBool('notif_activity_like') ?? true,
    prefs.getBool('notif_activity_comment') ?? true,
    prefs.getBool('notif_activity_friend') ?? true,
    prefs.getBool('notif_activity_chat') ?? true,
  ].any((enabled) => enabled);
  if (alreadyAsked && (!notifEnabled || await NotificationService.hasPermission())) return;

  // 업데이트 후 권한이 사라진 기존 사용자도 다시 알림 권한을 확인한다.
  if (!alreadyAsked) {
    await prefs.setBool('notif_goal', true);
    await prefs.setBool('notif_streak', true);
    await prefs.setBool('notif_mail', true);
  }

  final granted = await NotificationService.requestPermission();
  await prefs.setBool('notif_permission_asked', true);
  if (granted) {
    await NotificationService.scheduleDailyGoalReminder();
    await NotificationService.scheduleStreakRiskReminder(0);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (_, app, __) => AppPrimaryColor(
          // 커스텀 테마가 아니면 기본 포인트 색상 사용
          color: app.isCustomTheme ? app.userPrimaryColor : AppTheme.defaultPrimary,
          bgColor: app.isCustomTheme ? app.userBgColor : AppTheme.background,
          isCustom: app.isCustomTheme,
          child: Builder(builder: (ctx) {
            // 커스텀 테마이면 custom() 사용, 아니면 기본 light/dark
            final customLight = app.isCustomTheme
                ? AppTheme.custom(bgColor: app.userBgColor, primary: app.userPrimaryColor, brightness: Brightness.light)
                : AppTheme.light(app.userPrimaryColor);
            final customDark = app.isCustomTheme
                ? AppTheme.custom(bgColor: app.userBgColor, primary: app.userPrimaryColor, brightness: Brightness.dark)
                : AppTheme.dark(app.userPrimaryColor);
            return MaterialApp(
          title: 'Motivating',
          debugShowCheckedModeBanner: false,
          theme: customLight,
          darkTheme: customDark,
          // 커스텀 테마일 때 themeMode를 light로 고정 — theme(customLight)가 적용되도록
          themeMode: app.isCustomTheme ? ThemeMode.light : app.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              systemNavigationBarColor: isDark ? const Color(0xFF1a1a1a) : Colors.white,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ));
            // 휴대폰 글꼴 크기 설정 무시 — 앱 내 텍스트 크기 고정
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            );
          },
          home: const RootScreen(),
          navigatorKey: AppProvider.navigatorKey,
        ); // MaterialApp
          }), // Builder
        ), // AppPrimaryColor
      ), // Consumer
    ); // ChangeNotifierProvider
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermissionOnFirstLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (app.loading || (app.authUser != null && app.userData == null)) {
      // 인증 세션이 남아있으면 사용자 문서 복구가 끝날 때까지 로그인 화면을 숨긴다.
      return Scaffold(
        backgroundColor: context.bgColor,
        body: Center(child: CircularProgressIndicator(color: context.primaryColor)),
      );
    }
    if (app.authUser == null) return const LoginScreen();
    if (app.userData!.withdrawScheduledAt != null) return const WithdrawPendingScreen();
    if (!app.userData!.onboardingDone) return const OnboardingScreen();
    return const MainNav();
  }
}
