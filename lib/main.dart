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
  // 권한 요청을 블로킹하지 않고 runApp 먼저 실행
  runApp(const MyApp());
}

// 앱 첫 화면 로드 후 권한 요청 (블로킹 없음)
Future<void> _requestNotificationPermissionOnFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyAsked = prefs.getBool('notif_permission_asked') ?? false;
  if (alreadyAsked) return;

  await prefs.setBool('notif_permission_asked', true);
  await prefs.setBool('notif_goal', true);
  await prefs.setBool('notif_streak', true);
  await prefs.setBool('notif_mail', true);

  // 권한 요청 (UI가 준비된 후)
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
    // 앱 UI 준비 후 권한 요청 (다음 프레임)
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