import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../providers/settings_provider.dart';
import '../utils/webdav_helper.dart';

/// 统一备份服务
/// 封装本地备份、云备份、自动备份的共用逻辑
class BackupService {
  BackupService._();

  /// 获取数据库文件路径
  static Future<String> get dbPath => DatabaseHelper.getDatabasePath();

  /// 安全覆盖：先备份当前文件到 .bak，再写入新内容
  /// 写入失败时自动回滚
  static Future<void> safeOverwrite({
    required String sourcePath,
    required String targetPath,
  }) async {
    final target = File(targetPath);
    final bakPath = '$targetPath.bak';

    if (await target.exists()) {
      await target.copy(bakPath);
    }

    try {
      await File(sourcePath).copy(targetPath);
    } catch (e) {
      // 回滚
      final bak = File(bakPath);
      if (await bak.exists()) {
        await bak.copy(targetPath);
      }
      rethrow;
    }
  }

  /// 安全写入字节：先备份，再写入，失败回滚
  static Future<void> safeWriteBytes({
    required List<int> bytes,
    required String targetPath,
  }) async {
    final target = File(targetPath);
    final bakPath = '$targetPath.bak';

    if (await target.exists()) {
      await target.copy(bakPath);
    }

    try {
      await target.writeAsBytes(bytes);
    } catch (e) {
      final bak = File(bakPath);
      if (await bak.exists()) {
        await bak.copy(targetPath);
      }
      rethrow;
    }
  }

  /// 备份数据库到本地临时文件，返回文件路径
  static Future<String> backupToLocalFile() async {
    final db = await dbPath;
    final file = File(db);
    if (!await file.exists()) {
      throw Exception('数据库文件不存在');
    }

    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final backupName = 'daily_gig_backup_$timestamp.db';
    final backupPath = '${tempDir.path}/$backupName';
    await file.copy(backupPath);
    return backupPath;
  }

  /// 构建 WebDAV helper（从 provider 读取配置）
  static WebDavHelper buildWebDavHelper(Ref ref) {
    return WebDavHelper(
      serverUrl: ref.read(webDavUrlProvider),
      username: ref.read(webDavUsernameProvider),
      password: ref.read(webDavPasswordProvider),
    );
  }

  /// 自动备份保留天数
  static const int autoBackupRetentionDays = 30;

  /// 自动备份：在保存/删除后调用，静默失败
  static Future<void> autoBackup(Ref ref) async {
    try {
      final enabled = ref.read(autoBackupProvider);
      final configured = ref.read(webDavConfiguredProvider);
      if (!enabled || !configured) return;

      final helper = buildWebDavHelper(ref);
      final localPath = await dbPath;
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final remoteName = 'daily_gig_backup_auto_$timestamp.db';

      await helper.uploadFile(localPath, remoteName);

      // 清理 30 天前的旧备份
      await _cleanupOldBackups(helper);
    } catch (_) {
      // 自动备份失败不打扰用户
    }
  }

  /// 清理超过保留期的自动备份文件
  static Future<void> _cleanupOldBackups(WebDavHelper helper) async {
    try {
      final listResult = await helper.listFiles(prefix: 'daily_gig_backup_auto_');
      if (!listResult.isSuccess) return;

      final cutoff = DateTime.now().subtract(
        Duration(days: autoBackupRetentionDays),
      );

      for (final file in listResult.files) {
        final parsed = _parseTimestampFromName(file.name);
        if (parsed != null && parsed.isBefore(cutoff)) {
          await helper.deleteFile(file.name);
        }
      }
    } catch (_) {
      // 清理失败不影响主流程
    }
  }

  /// 从备份文件名中提取时间戳
  /// 文件名格式: daily_gig_backup_auto_2025-06-14T08-30-00.db
  static DateTime? _parseTimestampFromName(String name) {
    try {
      final start = name.indexOf('auto_');
      if (start == -1) return null;
      final tsStr = name.substring(start + 5).replaceAll('.db', '');
      // 还原 ISO 8601 格式：日期部分的 - 保留，时间部分的 - 替换为 :
      if (tsStr.length >= 16) {
        final datePart = tsStr.substring(0, 10);
        final timePart = tsStr.substring(11).replaceAll('-', ':');
        return DateTime.tryParse('${datePart}T$timePart');
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
