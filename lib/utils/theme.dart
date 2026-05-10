import 'package:flutter/material.dart';

class AppTheme {
  // 고정 색상
  static const Color danger = Color(0xFFE24B4A);

  // 라이트 테마 기본 색상
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0a0a0a);
  static const Color textSecondary = Color(0xFF9e9e9e);
  static const Color border = Color(0xFFE0E0E0);
  static const Color xpColor = Color(0xFF1b8a5a);

  // 다크 테마 기본 색상
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkCard = Color(0xFF2C2C2E);

  // 기본 포인트 색상
  static const Color defaultPrimary = Color(0xFF0a0a0a);

  // 커스텀 테마 — 배경색과 포인트 색상 모두 사용자 지정
  static ThemeData custom({
    required Color bgColor,
    required Color primary,
    required Brightness brightness,
  }) {
    // 배경색 기반으로 카드/서피스 색상 계산
    final isDark = brightness == Brightness.dark;
    // 서피스 색상 = 배경색과 동일 — 회색빛 없이 통일된 배경
    final surfaceColor = bgColor;
    // 포인트 색상 = 글꼴(텍스트) 색상으로 사용
    final textColor = primary;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: primary,
        onSecondary: isDark ? Colors.black : Colors.white,
        surface: surfaceColor,
        onSurface: textColor,
        error: danger,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(color: surfaceColor, elevation: 0),
      dividerColor: isDark ? Colors.white12 : Colors.black12,
    );
  }

  // 포인트 색상을 받아서 테마 생성
  static ThemeData light(Color primary) => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: surface,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(color: surface, elevation: 0),
        dividerColor: border,
      );

  static ThemeData dark(Color primary) => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          // 다크모드에서 포인트 색상이 너무 어두우면 흰색으로 대체
          seedColor: _isTooDark(primary) ? Colors.white : primary,
          brightness: Brightness.dark,
          surface: darkSurface,
          onSurface: darkTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackground,
          foregroundColor: darkTextPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(color: darkSurface, elevation: 0),
        dividerColor: darkBorder,
      );

  // 색상이 너무 어두운지 확인 — 다크모드에서 가독성 보장
  static bool _isTooDark(Color color) {
    final luminance = color.computeLuminance();
    return luminance < 0.1;
  }
}

// Context extension으로 다크/라이트 색상 자동 전환
// primaryColor는 AppProvider를 통해 설정된 포인트 색상 사용
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // 커스텀 모드 여부
  bool get isCustomTheme => AppPrimaryColor.isCustomMode(this);

  Color get bgColor {
    if (isCustomTheme) return AppPrimaryColor.bgOf(this);
    return isDark ? AppTheme.darkBackground : AppTheme.background;
  }
  Color get surfaceColor {
    // 커스텀 모드에서 surfaceColor = bgColor 그대로 — 회색빛 방지
    if (isCustomTheme) return AppPrimaryColor.bgOf(this);
    return isDark ? AppTheme.darkSurface : AppTheme.surface;
  }
  Color get cardColor => surfaceColor;
  Color get textPrimary {
    // 커스텀 모드에서 포인트 색상 = 글꼴 색상
    if (isCustomTheme) return AppPrimaryColor.of(this);
    return isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  }
  Color get textSecondary {
    // 커스텀 모드에서도 기본 보조 텍스트 색상 사용
    return isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  }
  // surfaceColor 위에 올라가는 텍스트 색상 — 배경색과 대비되도록 자동 계산
  // 카드, 버튼 등 surfaceColor 배경 위에서 사용
  Color get onSurfaceText {
    if (!isCustomTheme) return textPrimary;
    final surface = surfaceColor;
    // surfaceColor의 밝기에 따라 흰색/검정 중 대비 높은 색 선택
    return surface.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }
  Color get onSurfaceTextSecondary {
    if (!isCustomTheme) return textSecondary;
    final surface = surfaceColor;
    return surface.computeLuminance() > 0.5
        ? Colors.black45
        : Colors.white60;
  }
  Color get borderColor {
    if (isCustomTheme) return isDark ? Colors.white12 : Colors.black12;
    return isDark ? AppTheme.darkBorder : AppTheme.border;
  }
  // primaryColor — 포인트 색상 (다크모드에서 너무 어두우면 흰색)
  Color get primaryColor {
    final color = AppPrimaryColor.of(this);
    if (isDark && AppTheme._isTooDark(color)) return Colors.white;
    return color;
  }
  // primaryColor 위의 텍스트 색상 — 밝기에 따라 자동 대비
  Color get onPrimary {
    final c = primaryColor;
    return c.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
  }

  Color get inputFill {
    if (isCustomTheme) return AppPrimaryColor.bgOf(this);
    return isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9);
  }
  Color get modalBg {
    if (isCustomTheme) return AppPrimaryColor.bgOf(this);
    return isDark ? const Color(0xFF1C1C1E) : Colors.white;
  }
  Color get dividerColor {
    if (isCustomTheme) return isDark ? Colors.white10 : Colors.black.withOpacity(0.06);
    return isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F0);
  }
  Color get subtleBg {
    // 커스텀 모드에서 subtleBg = bgColor 그대로 — 회색빛 방지
    if (isCustomTheme) return AppPrimaryColor.bgOf(this);
    return isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9F9);
  }
}

// 커스텀 테마 색상을 위젯 트리에 전달하는 InheritedWidget
class AppPrimaryColor extends InheritedWidget {
  final Color color;      // 포인트 색상
  final Color bgColor;    // 배경 색상
  final bool isCustom;    // 사용자 설정 모드 여부

  const AppPrimaryColor({
    super.key,
    required this.color,
    required this.bgColor,
    required this.isCustom,
    required super.child,
  });

  // 포인트 색상 조회
  static Color of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppPrimaryColor>();
    return result?.color ?? AppTheme.defaultPrimary;
  }

  // 배경 색상 조회
  static Color bgOf(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppPrimaryColor>();
    return result?.bgColor ?? AppTheme.background;
  }

  // 커스텀 모드 여부 조회
  static bool isCustomMode(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppPrimaryColor>();
    return result?.isCustom ?? false;
  }

  @override
  bool updateShouldNotify(AppPrimaryColor oldWidget) =>
      color != oldWidget.color || bgColor != oldWidget.bgColor || isCustom != oldWidget.isCustom;
}