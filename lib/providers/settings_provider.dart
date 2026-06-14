import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

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

/// 是否开启自动备份（添加/删除日程时自动备份到云盘）
final autoBackupProvider = StateProvider<bool>((ref) {
  return false;
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
  ref.read(themeModeProvider.notifier).state = ThemeMode.values[
    (await SettingsService.loadInt(keyThemeMode, 0)).clamp(0, 2)
  ];
  ref.read(hideIncomeProvider.notifier).state =
      await SettingsService.loadBool(keyHideIncome, false);
  ref.read(hideStatisticsProvider.notifier).state =
      await SettingsService.loadBool(keyHideStatistics, false);
  ref.read(webDavUrlProvider.notifier).state =
      await SettingsService.loadString(keyWebDavUrl, defaultWebDavUrl);
  ref.read(webDavUsernameProvider.notifier).state =
      await SettingsService.loadString(keyWebDavUsername, '');
  ref.read(webDavPasswordProvider.notifier).state =
      await SettingsService.loadString(keyWebDavPassword, '');
  ref.read(autoBackupProvider.notifier).state =
      await SettingsService.loadBool(keyAutoBackup, false);
}

/// 保存主题模式
Future<void> saveThemeMode(ThemeMode mode) =>
    SettingsService.saveInt(keyThemeMode, mode.index);

/// 保存隐藏收入设置
Future<void> saveHideIncome(bool value) =>
    SettingsService.saveBool(keyHideIncome, value);

/// 保存隐藏统计设置
Future<void> saveHideStatistics(bool value) =>
    SettingsService.saveBool(keyHideStatistics, value);

/// 保存 WebDAV 服务器地址
Future<void> saveWebDavUrl(String value) =>
    SettingsService.saveString(keyWebDavUrl, value);

/// 保存 WebDAV 账号
Future<void> saveWebDavUsername(String value) =>
    SettingsService.saveString(keyWebDavUsername, value);

/// 保存 WebDAV 密码
Future<void> saveWebDavPassword(String value) =>
    SettingsService.saveString(keyWebDavPassword, value);

/// 保存自动备份开关
Future<void> saveAutoBackup(bool value) =>
    SettingsService.saveBool(keyAutoBackup, value);
