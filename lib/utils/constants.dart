import 'package:flutter/material.dart';

/// 应用全局常量与主题配置
class AppConstants {
  AppConstants._();

  // ===================== 品牌色彩 =====================
  /// 主色调：温暖橙色（代表活力、打工人）
  static const Color primaryColor = Color(0xFFF4A261);
  static const Color primaryDark = Color(0xFFE07B3E);
  static const Color primaryLight = Color(0xFFFFD6A5);

  /// 辅助色：暖灰色
  static const Color warmGrey = Color(0xFF8D99AE);
  static const Color warmGreyLight = Color(0xFFF5F0EB);

  /// 成功色（用于收入显示）
  static const Color incomeGreen = Color(0xFF2E8B57);

  /// 危险/警告色
  static const Color dangerRed = Color(0xFFE76F51);

  // ===================== 日历标记颜色 =====================
  /// 有工作安排的日期圆点颜色
  static const Color workDotColor = Color(0xFFF4A261);
  /// 有笔记记录的日期圆点颜色
  static const Color noteDotColor = Color(0xFF6C9BCF);

  // ===================== 配色方案 =====================
  /// 温暖风格明亮主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFFAF8F5),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFFFF9F2),
        foregroundColor: Color(0xFF3D3D3D),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3D3D3D),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryDark,
        unselectedItemColor: warmGrey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3D3D3D)),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF3D3D3D)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF5C5C5C)),
      ),
    );
  }

  /// 深色主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF252540),
        foregroundColor: Color(0xFFEAEAEA),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEAEAEA),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: const Color(0xFF2D2D44),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryLight,
        unselectedItemColor: warmGrey,
        backgroundColor: Color(0xFF252540),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: const Color(0xFF2D2D44),
      ),
    );
  }

  // ===================== 尺寸常量 =====================
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double cardRadius = 12.0;

  // ===================== 默认值 =====================
  static const String defaultStartTime = '09:00';
  static const String defaultEndTime = '18:00';
  static const double defaultHourlyWage = 0.0;
}
