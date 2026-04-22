import 'package:flutter/material.dart';

class AppTheme {
  // 기존 앱 라이트 테마 컬러
  static const Color primary = Color(0xFF0a0a0a);
  static const Color primaryLight = Color(0xFF424242);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0a0a0a);
  static const Color textSecondary = Color(0xFF9e9e9e);
  static const Color xpColor = Color(0xFF1b8a5a);
  static const Color tagShort = Color(0xFF4CAF50);
  static const Color tagMid = Color(0xFFFF9800);
  static const Color tagLong = Color(0xFFE91E63);
  static const Color danger = Color(0xFFE24B4A);
  static const Color border = Color(0xFFE0E0E0);

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: cardBg,
          elevation: 0,
        ),
      );

  // 다크 테마 (나중에 테마 선택 기능용)
  static const Color darkPrimary = Color(0xFF7C4DFF);
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF242442);
  static const Color darkCardBg = Color(0xFF2D2D50);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAAAAAA);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkPrimary,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackground,
          foregroundColor: darkTextPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: darkCardBg,
          elevation: 0,
        ),
      );
}