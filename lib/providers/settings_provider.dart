import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置持久化 Key
const _keyThemeMode = 'theme_mode';
const _keyHideIncome = 'hide_income';
const _keyHideStatistics = 'hide_statistics';

/// 主题模式状态提供者
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

/// 是否隐藏收入金额
final hideIncomeProvider = StateProvider<bool>((ref) {
  return false;
});

/// 是否隐藏统计页面
final hideStatisticsProvider = StateProvider<bool>((ref) {
  return false;
});

/// 从本地加载持久化设置到 provider
Future<void> loadSettings(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt(_keyThemeMode) ?? 0;
  ref.read(themeModeProvider.notifier).state = ThemeMode.values[themeIndex.clamp(0, 2)];
  ref.read(hideIncomeProvider.notifier).state = prefs.getBool(_keyHideIncome) ?? false;
  ref.read(hideStatisticsProvider.notifier).state = prefs.getBool(_keyHideStatistics) ?? false;
}

/// 保存主题模式
Future<void> saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_keyThemeMode, mode.index);
}

/// 保存隐藏收入设置
Future<void> saveHideIncome(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyHideIncome, value);
}

/// 保存隐藏统计设置
Future<void> saveHideStatistics(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyHideStatistics, value);
}
