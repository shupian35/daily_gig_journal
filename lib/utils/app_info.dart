import 'package:package_info_plus/package_info_plus.dart';

/// 应用版本信息真相源 —— 单一 PackageInfo 单例。
///
/// 在 [main] 启动时由 [initAppInfo] 预加载一次；之后所有 UI 同步读取，
/// 不重复发起 platform channel call（Android PackageManager / iOS Bundle）。
///
/// 消除之前 settings_screen × 2 + l10n × 3 共 5 处硬编码版本号冗余喵~
PackageInfo? _cached;

/// 在 `runApp()` 之前调用一次。失败不抛 —— 降级到 '—' 占位。
Future<void> initAppInfo() async {
  try {
    _cached = await PackageInfo.fromPlatform();
  } catch (_) {
    _cached = null;
  }
}

/// 当前版本字符串（如 "1.0.1"）；未初始化或初始化失败时返回 '—'。
String get currentVersion => _cached?.version ?? '—';