import 'package:flutter/material.dart';

/// J&Z 弦渡 品牌主题
///
/// 视觉语言呼应 Logo：白底、炭黑细线、大留白、简约高级，
/// 香槟金只作少量强调，绝不喧宾夺主。
class AppColors {
  AppColors._();

  /// 炭黑——主文字与主色
  static const Color ink = Color(0xFF1A1A1A);

  /// 深灰——次级文字
  static const Color inkSoft = Color(0xFF5A5A5A);

  /// 纯白——背景
  static const Color paper = Color(0xFFFFFFFF);

  /// 浅灰——卡片/分组底
  static const Color mist = Color(0xFFF6F6F4);

  /// 香槟金——唯一强调色
  static const Color gold = Color(0xFFBFA16D);

  /// 细线——分隔线
  static const Color hairline = Color(0xFFE8E6E0);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        primary: AppColors.ink,
        surface: AppColors.paper,
        error: const Color(0xFFB3261E),
      ),
      scaffoldBackgroundColor: AppColors.paper,
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'Noto Sans SC'],
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.mist,
        hintStyle: const TextStyle(color: AppColors.inkSoft),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
