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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  // 백그라운드 핸들러는 notification_service.dart의 것만 사용 — 중복 등록 금지
  // NotificationService.init() 내부에서 FirebaseMessaging.onBackgroundMessage 등록함
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
          color: app.isCustomTheme ? app.userPrimaryColor : AppTheme.defaultPrimary,
          bgColor: app.isCustomTheme ? app.userBgColor : AppTheme.background,
          isCustom: app.isCustomTheme,
          child: Builder(builder: (ctx) {
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
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                  child: child!,
                );
              },
              home: const RootScreen(),
              navigatorKey: AppProvider.navigatorKey,
            );
          }),
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

    if (app.loading || (app.authUser != null && app.userData == null)) {
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