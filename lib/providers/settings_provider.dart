import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置持久化 Key
const _keyThemeMode = 'theme_mode';
const _keyHideIncome = 'hide_income';
const _keyHideStatistics = 'hide_statistics';
const _keyWebDavUrl = 'webdav_url';
const _keyWebDavUsername = 'webdav_username';
const _keyWebDavPassword = 'webdav_password';

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

// ===================== WebDAV 云备份设置 =====================

/// 坚果云默认 WebDAV 地址
const defaultWebDavUrl = 'https://dav.jianguoyun.com/dav';

/// WebDAV 服务器地址
final webDavUrlProvider = StateProvider<String>((ref) {
  return defaultWebDavUrl;
});

/// WebDAV 账号
final webDavUsernameProvider = StateProvider<String>((ref) {
  return '';
});

/// WebDAV 密码（应用令牌）
final webDavPasswordProvider = StateProvider<String>((ref) {
  return '';
});

/// WebDAV 是否已配置（至少填写了地址和账号）
final webDavConfiguredProvider = Provider<bool>((ref) {
  final url = ref.watch(webDavUrlProvider);
  final username = ref.watch(webDavUsernameProvider);
  return url.isNotEmpty && username.isNotEmpty;
});

// ===================== 持久化读写 =====================

/// 从本地加载所有持久化设置到 provider
Future<void> loadSettings(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt(_keyThemeMode) ?? 0;
  ref.read(themeModeProvider.notifier).state =
      ThemeMode.values[themeIndex.clamp(0, 2)];
  ref.read(hideIncomeProvider.notifier).state =
      prefs.getBool(_keyHideIncome) ?? false;
  ref.read(hideStatisticsProvider.notifier).state =
      prefs.getBool(_keyHideStatistics) ?? false;

  // WebDAV 配置
  ref.read(webDavUrlProvider.notifier).state =
      prefs.getString(_keyWebDavUrl) ?? defaultWebDavUrl;
  ref.read(webDavUsernameProvider.notifier).state =
      prefs.getString(_keyWebDavUsername) ?? '';
  ref.read(webDavPasswordProvider.notifier).state =
      prefs.getString(_keyWebDavPassword) ?? '';
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

/// 保存 WebDAV 服务器地址
Future<void> saveWebDavUrl(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyWebDavUrl, value);
}

/// 保存 WebDAV 账号
Future<void> saveWebDavUsername(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyWebDavUsername, value);
}

/// 保存 WebDAV 密码
Future<void> saveWebDavPassword(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyWebDavPassword, value);
}
