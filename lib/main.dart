import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();
  // 5번 수정: 최초 실행 시 알림 권한 요청
  await _requestNotificationPermissionOnFirstLaunch();
  runApp(const MyApp());
}

Future<void> _requestNotificationPermissionOnFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirst = prefs.getBool('notif_permission_asked') ?? false;
  if (!isFirst) {
    await NotificationService.requestPermission();
    await prefs.setBool('notif_permission_asked', true);
    // 최초 실행 시 알림 기본값 true로 저장
    await prefs.setBool('notif_goal', true);
    await prefs.setBool('notif_streak', true);
    await prefs.setBool('notif_mail', true);
    // 권한 허용 시 알림 스케줄링
    final granted = await NotificationService.hasPermission();
    if (granted) {
      await NotificationService.scheduleDailyGoalReminder();
      await NotificationService.scheduleStreakRiskReminder(0);
    }
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
          home: const RootScreen(),
          navigatorKey: AppProvider.navigatorKey,
        ),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

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