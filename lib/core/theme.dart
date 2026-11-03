import 'package:flutter/material.dart';

class AppColors {
  static const bgDark = Color(0xFF111418);
  static const cardDark = Color(0xFF1B1F26);
  static const textDark = Color(0xFFECE9E4);
  static const mutedDark = Color(0xFF9C9A96);
  static const accent = Color(0xFF7CC4F5);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? AppColors.bgDark : const Color(0xFFF6F4F0);
  final text = dark ? AppColors.textDark : const Color(0xFF16191D);
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: b,
    ).copyWith(
      surface: bg,
      onSurface: text,
      primary: dark ? AppColors.accent : const Color(0xFF1F6FB2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? AppColors.cardDark : Colors.white,
      indicatorColor: dark ? const Color(0xFF262C36) : const Color(0xFFE6EEF6),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
  );
}

extension ThemeCtx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardBg => isDark ? AppColors.cardDark : Colors.white;
  Color get muted => isDark ? AppColors.mutedDark : const Color(0xFF6B6F76);
  Color get fg => Theme.of(this).colorScheme.onSurface;
  Color get bg => Theme.of(this).scaffoldBackgroundColor;
  Color get track => isDark ? const Color(0xFF2A3038) : const Color(0xFFDDE1E6);
}
