import 'package:shared_preferences/shared_preferences.dart';

/// 设置持久化 Key
const keyThemeMode = 'theme_mode';
const keyHideIncome = 'hide_income';
const keyHideStatistics = 'hide_statistics';
const keyWebDavUrl = 'webdav_url';
const keyWebDavUsername = 'webdav_username';
const keyWebDavPassword = 'webdav_password';
const keyAutoBackup = 'auto_backup';
const keyLocale = 'locale';

/// 设置持久化服务
/// 封装 SharedPreferences 访问，消除 7 处重复的 getInstance 样板
class SettingsService {
  SettingsService._();

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<int> loadInt(String key, int fallback) async {
    final prefs = await _prefs;
    return prefs.getInt(key) ?? fallback;
  }

  static Future<bool> loadBool(String key, bool fallback) async {
    final prefs = await _prefs;
    return prefs.getBool(key) ?? fallback;
  }

  static Future<String> loadString(String key, String fallback) async {
    final prefs = await _prefs;
    return prefs.getString(key) ?? fallback;
  }

  static Future<void> saveInt(String key, int value) async {
    final prefs = await _prefs;
    await prefs.setInt(key, value);
  }

  static Future<void> saveBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  static Future<void> saveString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }
}
