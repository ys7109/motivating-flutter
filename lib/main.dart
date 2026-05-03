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

// 백그라운드 FCM 핸들러 — 최상위 함수로 등록해야 함 (main 밖)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 백그라운드에서는 FCM이 자동으로 시스템 알림을 표시해줌
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init();
  runApp(const MyApp());
}

Future<void> _requestNotificationPermissionOnFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyAsked = prefs.getBool('notif_permission_asked') ?? false;
  if (alreadyAsked) return;

  await prefs.setBool('notif_permission_asked', true);
  await prefs.setBool('notif_goal', true);
  await prefs.setBool('notif_streak', true);
  await prefs.setBool('notif_mail', true);

  final granted = await NotificationService.requestPermission();
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
        builder: (_, app, __) => MaterialApp(
          title: 'Motivating',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: app.themeMode,
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
        ),
      ),
    );
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

    if (app.loading) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: Center(child: CircularProgressIndicator(color: context.primaryColor)),
      );
    }
    if (app.authUser == null || app.userData == null) return const LoginScreen();
    if (app.userData!.withdrawScheduledAt != null) return const WithdrawPendingScreen();
    if (!app.userData!.onboardingDone) return const OnboardingScreen();
    return MainNav(key: mainNavKey);
  }
}