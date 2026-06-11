import 'package:flutter/material.dart';

/// 应用全局常量与主题配置
/// 设计方向：「精致杂志风」Editorial Warmth
/// 温暖、精致、像一本高级纸质手账
class AppConstants {
  AppConstants._();

  // ===================== 品牌色彩体系 =====================
  /// 主色调：温润琥珀（比之前的橙色更沉稳、更有质感）
  static const Color primaryColor = Color(0xFFC8895A);
  static const Color primaryDark = Color(0xFFA66E42);
  static const Color primaryLight = Color(0xFFF2DBC8);

  /// 辅助色
  static const Color warmGrey = Color(0xFF9B8E84);
  static const Color warmGreyLight = Color(0xFFF6F2ED);

  /// 成功色（鼠尾草绿，比之前更柔和）
  static const Color incomeGreen = Color(0xFF5A8F7B);

  /// 危险/警告色（暖玫瑰）
  static const Color dangerRed = Color(0xFFD4786E);

  // ===================== 文字色彩 =====================
  /// 浅色模式主文字（暖棕黑，不刺眼）
  static const Color textPrimary = Color(0xFF3D3430);
  /// 浅色模式辅助文字
  static const Color textSecondary = Color(0xFF8D7E76);
  /// 深色模式主文字
  static const Color textPrimaryDark = Color(0xFFEDE4DD);
  /// 深色模式辅助文字
  static const Color textSecondaryDark = Color(0xFFA09892);

  // ===================== 背景色 =====================
  /// 浅色模式背景（暖纸色）
  static const Color bgLight = Color(0xFFFBFAF7);
  /// 浅色模式卡片背景
  static const Color cardLight = Color(0xFFFFFFFF);
  /// 浅色模式 AppBar 背景
  static const Color appBarLight = Color(0xFFFDFBF8);

  /// 深色模式背景
  static const Color bgDark = Color(0xFF1B1B22);
  /// 深色模式卡片背景
  static const Color cardDark = Color(0xFF262630);
  /// 深色模式 AppBar 背景
  static const Color appBarDark = Color(0xFF21212B);

  // ===================== 日历标记颜色 =====================
  static const Color workDotColor = Color(0xFFC8895A);
  static const Color noteDotColor = Color(0xFF6B9EC2);

  // ===================== 圆角系统 =====================
  static const double radiusXs = 6.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 18.0;
  static const double radiusXl = 24.0;

  // ===================== 间距系统 =====================
  static const double spaceXs = 6.0;
  static const double spaceSm = 10.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // ===================== 阴影系统 =====================
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.2)
              : const Color(0x1A8D7E76),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.1)
              : const Color(0x0D8D7E76),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // ===================== 主题 =====================
  /// 浅色主题 —— 精致杂志风
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: cardLight,
      onSurface: textPrimary,
      error: dangerRed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgLight,

      // ---- AppBar ----
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: appBarLight,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.3,
        ),
      ),

      // ---- 卡片 ----
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(
            color: const Color(0xFFEDE8E2),
            width: 0.5,
          ),
        ),
        color: cardLight,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceXs),
      ),

      // ---- FAB ----
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      // ---- 底部导航栏 ----
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryDark,
        unselectedItemColor: warmGrey,
        backgroundColor: cardLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ---- 输入框 ----
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFE5DFD8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFE5DFD8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: 14,
        ),
        filled: true,
        fillColor: cardLight,
        hintStyle: TextStyle(
          color: const Color(0xFFC5BDB6),
          fontSize: 14,
        ),
      ),

      // ---- 文本体系 ----
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),

      // ---- 分隔线 ----
      dividerTheme: DividerThemeData(
        color: const Color(0xFFEDE8E2),
        thickness: 0.5,
        space: 0,
      ),

      // ---- SnackBar ----
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      // ---- Dialog ----
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),

      // ---- 图标 ----
      iconTheme: IconThemeData(
        color: textSecondary,
        size: 22,
      ),
    );
  }

  /// 深色主题 —— 精致暗夜杂志风
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryLight,
      onPrimary: Colors.black,
      surface: cardDark,
      onSurface: textPrimaryDark,
      error: dangerRed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgDark,

      // ---- AppBar ----
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: appBarDark,
        foregroundColor: textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
          letterSpacing: 0.3,
        ),
      ),

      // ---- 卡片 ----
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(
            color: const Color(0xFF3A3A44),
            width: 0.5,
          ),
        ),
        color: cardDark,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceXs),
      ),

      // ---- FAB ----
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      // ---- 底部导航栏 ----
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryLight,
        unselectedItemColor: textSecondaryDark,
        backgroundColor: cardDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ---- 输入框 ----
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFF3A3A44)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFF3A3A44)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: primaryLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: 14,
        ),
        filled: true,
        fillColor: cardDark,
        hintStyle: TextStyle(
          color: const Color(0xFF6A6560),
          fontSize: 14,
        ),
      ),

      // ---- 文本体系 ----
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimaryDark,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondaryDark,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondaryDark,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryDark,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryDark,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: textSecondaryDark,
        ),
      ),

      // ---- 分隔线 ----
      dividerTheme: DividerThemeData(
        color: const Color(0xFF3A3A44),
        thickness: 0.5,
        space: 0,
      ),

      // ---- SnackBar ----
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      // ---- Dialog ----
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
    );
  }

  // ===================== 默认值 =====================
  static const String defaultStartTime = '09:00';
  static const String defaultEndTime = '18:00';
  static const double defaultHourlyWage = 0.0;
}
