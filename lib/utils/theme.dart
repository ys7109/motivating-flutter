import 'package:flutter/material.dart';

class AppTheme {
  // ── 라이트 고정 색상 (로그인, 온보딩 등 항상 라이트) ──
  static const Color primary = Color(0xFF0a0a0a);
  static const Color danger = Color(0xFFE24B4A);

  // ── 라이트 테마 색상 ──
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0a0a0a);
  static const Color textSecondary = Color(0xFF9e9e9e);
  static const Color border = Color(0xFFE0E0E0);
  static const Color xpColor = Color(0xFF1b8a5a);

  // ── 다크 테마 색상 ──
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkCard = Color(0xFF2C2C2E);

  static ThemeData get light => ThemeData(
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

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
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
}

// ── Context extension으로 다크/라이트 색상 자동 전환 ──
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor => isDark ? AppTheme.darkBackground : AppTheme.background;
  Color get surfaceColor => isDark ? AppTheme.darkSurface : AppTheme.surface;
  Color get cardColor => isDark ? AppTheme.darkCard : AppTheme.surface;
  Color get textPrimary => isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textSecondary => isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get borderColor => isDark ? AppTheme.darkBorder : AppTheme.border;
  Color get primaryColor => isDark ? Colors.white : AppTheme.primary;
  Color get inputFill => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9);
  Color get modalBg => isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get dividerColor => isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F0);
  Color get subtleBg => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9F9);
}