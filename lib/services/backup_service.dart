import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/settings_service.dart';
import '../utils/webdav_helper.dart';

/// Auto-backup period's collected change set (ADR-0010).
class BackupChangeSet {
  final Set<String> imagesToUpload;
  final Set<String> draftsToUpload;
  final Set<String> imagesToTrash;
  final Set<String> draftsToTrash;
  const BackupChangeSet({
    this.imagesToUpload = const {},
    this.draftsToUpload = const {},
    this.imagesToTrash = const {},
    this.draftsToTrash = const {},
  });
  bool get isEmpty =>
      imagesToUpload.isEmpty &&
      draftsToUpload.isEmpty &&
      imagesToTrash.isEmpty &&
      draftsToTrash.isEmpty;
}

/// ADR-0011: auto-backup summary on success.
@immutable
class AutoBackupSummary {
  final DateTime completedAt;
  final int uploadedImages;
  final int skippedImages;
  final int uploadedDrafts;
  final int uploadedBytes;
  final bool dbUploaded;
  const AutoBackupSummary({
    required this.completedAt,
    required this.uploadedImages,
    required this.skippedImages,
    required this.uploadedDrafts,
    required this.uploadedBytes,
    required this.dbUploaded,
  });
}

/// ADR-0011: auto-backup error.
@immutable
class AutoBackupError {
  final DateTime occurredAt;
  final String reason;
  final int consecutiveCount;
  const AutoBackupError({
    required this.occurredAt,
    required this.reason,
    required this.consecutiveCount,
  });
}

/// Change set tracking provider (ADR-0010).
final backupChangeSetProvider = StateProvider<BackupChangeSet>((ref) {
  return const BackupChangeSet();
});

/// ADR-0011: last successful summary.
final lastAutoBackupSummaryProvider =
    StateProvider<AutoBackupSummary?>((ref) => null);

/// ADR-0011: last error.
final lastAutoBackupErrorProvider =
    StateProvider<AutoBackupError?>((ref) => null);

/// Unified backup service (ADR-0010 incremental + ADR-0011 observability).
class BackupService {
  BackupService._();

  static const String cloudDbName = 'daily_gig_journal.db';
  static const String imagesSubDir = 'images';
  static const String draftsSubDir = 'drafts';
  static const String trashedSubDir = 'trashed';

  /// Old API kept for backwards compatibility (Q4 decision: throttling moved to EntryCoordinator).
  static const int autoBackupRetentionDays = 30;

  /// 云端恢复（ADR-0010）：云端唯一可恢复对象是固定名 [cloudDbName]。
  /// 先 HEAD 校验存在，再下载并用 [WebDavHelper.downloadFile] 已有的
  /// .bak/.restore 安全覆写语义覆写本地数据库，返回结果供 UI 提示。
  static Future<WebDavResult> restoreFromCloud({
    required WebDavHelper helper,
    required String localDbPath,
  }) async {
    final exists = await helper.headFile(cloudDbName);
    if (!exists) {
      return const WebDavResult.error('云盘上未找到 daily_gig_journal.db，无法恢复喵~');
    }
    return helper.downloadFile(cloudDbName, localDbPath);
  }

  static WebDavHelper buildWebDavHelper(ProviderContainer container) {
    return WebDavHelper(
      serverUrl: container.read(webDavUrlProvider),
      username: container.read(webDavUsernameProvider),
      password: container.read(webDavPasswordProvider),
    );
  }

  /// Auto-backup: incremental upload of DB + images/ + drafts/ changes + soft-delete (ADR-0010).
  static Future<void> autoBackup(dynamic container) async {
    AutoBackupSummary? summary;
    try {
      final enabled = container.read(autoBackupProvider);
      final configured = container.read(webDavConfiguredProvider);
      if (!enabled || !configured) return;

      final helper = buildWebDavHelper(container);
      final repo = container.read(workEntryRepositoryProvider);
      final localDbPath = await repo.filePath();

      final changes = container.read(backupChangeSetProvider);
      container.read(backupChangeSetProvider.notifier).state = const BackupChangeSet();

      // 1. Ensure sub directories exist.
      for (final sub in [imagesSubDir, draftsSubDir, trashedSubDir]) {
        final r = await helper.ensureSubDir(sub);
        if (!r.isSuccess) throw Exception('create $sub failed: ${r.message}');
      }

      int uploadedBytes = 0;
      int uploadedImages = 0;
      int skippedImages = 0;
      int uploadedDrafts = 0;
      bool dbUploaded = false;

      // 2. Upload DB (Q3: always full, overwrite).
      final dbFile = File(localDbPath);
      final dbBytes = await dbFile.readAsBytes();
      final dbResult = await helper.uploadBytes(dbBytes, cloudDbName);
      if (dbResult.isSuccess) {
        uploadedBytes += dbBytes.length;
        dbUploaded = true;
      } else {
        throw Exception('DB upload failed: ${dbResult.message}');
      }

      // 3. Incremental image upload (Q1: HEAD probe skip).
      for (final imgRel in changes.imagesToUpload) {
        final exists = await helper.headFile(imgRel);
        if (exists) {
          skippedImages++;
          continue;
        }
        final abs = await _resolveRelativeToAbs(localDbPath, imgRel);
        final f = File(abs);
        if (!await f.exists()) continue;
        final bytes = await f.readAsBytes();
        final r = await helper.uploadBytes(bytes, imgRel);
        if (r.isSuccess) {
          uploadedBytes += bytes.length;
          uploadedImages++;
        }
      }

      // 4. Incremental draft upload (Q1: all drafts full backup).
      for (final draftRel in changes.draftsToUpload) {
        final exists = await helper.headFile(draftRel);
        if (exists) continue;
        final abs = await _resolveRelativeToAbs(localDbPath, draftRel);
        final f = File(abs);
        if (!await f.exists()) continue;
        final bytes = await f.readAsBytes();
        final r = await helper.uploadBytes(bytes, draftRel);
        if (r.isSuccess) {
          uploadedBytes += bytes.length;
          uploadedDrafts++;
        }
      }

      // 5. Soft delete (Q2: move to trashed/ instead of DELETE).
      for (final imgRel in changes.imagesToTrash) {
        await _moveToTrashed(helper, imgRel);
      }
      for (final draftRel in changes.draftsToTrash) {
        await _moveToTrashed(helper, draftRel);
      }

      // 6. Clean up trashed/ older than 30 days.
      await _cleanupTrashed(helper);

      summary = AutoBackupSummary(
        completedAt: DateTime.now(),
        uploadedImages: uploadedImages,
        skippedImages: skippedImages,
        uploadedDrafts: uploadedDrafts,
        uploadedBytes: uploadedBytes,
        dbUploaded: dbUploaded,
      );
    } catch (e) {
      final prev = container.read(lastAutoBackupErrorProvider);
      final err = AutoBackupError(
        occurredAt: DateTime.now(),
        reason: e.toString(),
        consecutiveCount: (prev?.consecutiveCount ?? 0) + 1,
      );
      container.read(lastAutoBackupErrorProvider.notifier).state = err;
      await _persistError(err);
      return;
    }

    // Success: write summary, clear error, persist (ADR-0011 cross-restart).
    container.read(lastAutoBackupSummaryProvider.notifier).state = summary;
    container.read(lastAutoBackupErrorProvider.notifier).state = null;
    await _persistSummary(summary);
    await _clearPersistedError();
  }

  /// ADR-0011: Persist summary so the banner survives app restart.
  static Future<void> _persistSummary(AutoBackupSummary summary) async {
    await SettingsService.saveString(
        keyLastAutoBackupAt, summary.completedAt.toIso8601String());
    await SettingsService.saveInt(
        keyLastAutoBackupUploadedImages, summary.uploadedImages);
    await SettingsService.saveInt(
        keyLastAutoBackupSkippedImages, summary.skippedImages);
    await SettingsService.saveInt(
        keyLastAutoBackupUploadedBytes, summary.uploadedBytes);
  }

  /// ADR-0011: Persist error so the banner survives app restart.
  static Future<void> _persistError(AutoBackupError err) async {
    await SettingsService.saveString(
        keyLastAutoBackupErrorAt, err.occurredAt.toIso8601String());
    await SettingsService.saveString(keyLastAutoBackupErrorReason, err.reason);
    await SettingsService.saveInt(
        keyLastAutoBackupErrorConsecutiveCount, err.consecutiveCount);
  }

  /// Clear persisted error keys after a successful backup.
  static Future<void> _clearPersistedError() async {
    await SettingsService.remove(keyLastAutoBackupErrorAt);
    await SettingsService.remove(keyLastAutoBackupErrorReason);
    await SettingsService.remove(keyLastAutoBackupErrorConsecutiveCount);
  }

  /// Resolve relative path (e.g. images/img_x.png) to local absolute path under appDocsDir.
  static Future<String> _resolveRelativeToAbs(
    String dbPath,
    String relPath,
  ) async {
    final appDocsDir = dbPath.substring(0, dbPath.lastIndexOf('/'));
    return '$appDocsDir/$relPath';
  }

  /// Soft-delete: move images/x.png -> trashed/x.png.
  static Future<void> _moveToTrashed(WebDavHelper helper, String relPath) async {
    try {
      final exists = await helper.headFile(relPath);
      if (!exists) return;
      final bytesResult = await helper.downloadFileToBytes(relPath);
      if (!bytesResult.isSuccess || bytesResult.bytes == null) return;
      final filename = relPath.substring(relPath.lastIndexOf('/') + 1);
      await helper.uploadBytes(bytesResult.bytes!, '$trashedSubDir/$filename');
      await helper.deleteFile(relPath);
    } catch (_) {}
  }

  /// Clean up trashed/ older than 30 days.
  static Future<void> _cleanupTrashed(WebDavHelper helper) async {
    try {
      final list = await helper.listFilesInSubDir(trashedSubDir);
      if (!list.isSuccess) return;
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      for (final f in list.files) {
        final lm = parseDavLastModified(f.lastModified);
        if (lm == null || !lm.isBefore(cutoff)) continue;
        await helper.deleteFile('$trashedSubDir/${f.name}');
      }
    } catch (_) {}
  }

  /// 解析 WebDAV PROPFIND 返回的 getlastmodified 值（RFC 1123 HTTP-date，
  /// 如 `Mon, 14 Jun 2026 08:30:00 GMT`）为本地时间；无法解析返回 null。
  /// 注意不能用 [DateTime.parse]：它只接受 ISO 8601。
  @visibleForTesting
  static DateTime? parseDavLastModified(String raw) {
    try {
      return HttpDate.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Record image insert (UI calls this).
  static void trackImageUpload(dynamic ref, String relPath) {
    final cur = ref.read(backupChangeSetProvider);
    ref.read(backupChangeSetProvider.notifier).state = BackupChangeSet(
      imagesToUpload: {...cur.imagesToUpload, relPath},
      draftsToUpload: cur.draftsToUpload,
      imagesToTrash: cur.imagesToTrash,
      draftsToTrash: cur.draftsToTrash,
    );
  }

  /// Record draft save.
  static void trackDraftUpload(dynamic ref, String relPath) {
    final cur = ref.read(backupChangeSetProvider);
    ref.read(backupChangeSetProvider.notifier).state = BackupChangeSet(
      imagesToUpload: cur.imagesToUpload,
      draftsToUpload: {...cur.draftsToUpload, relPath},
      imagesToTrash: cur.imagesToTrash,
      draftsToTrash: cur.draftsToTrash,
    );
  }

  /// Record image delete (soft-delete).
  static void trackImageTrash(dynamic ref, String relPath) {
    final cur = ref.read(backupChangeSetProvider);
    ref.read(backupChangeSetProvider.notifier).state = BackupChangeSet(
      imagesToUpload: cur.imagesToUpload,
      draftsToUpload: cur.draftsToUpload,
      imagesToTrash: {...cur.imagesToTrash, relPath},
      draftsToTrash: cur.draftsToTrash,
    );
  }

  /// Record draft delete.
  static void trackDraftTrash(dynamic ref, String relPath) {
    final cur = ref.read(backupChangeSetProvider);
    ref.read(backupChangeSetProvider.notifier).state = BackupChangeSet(
      imagesToUpload: cur.imagesToUpload,
      draftsToUpload: cur.draftsToUpload,
      imagesToTrash: cur.imagesToTrash,
      draftsToTrash: {...cur.draftsToTrash, relPath},
    );
  }

  /// ADR-0011: 应用启动时从 SharedPreferences 恢复上次备份状态 (summary + error).
  /// 调用方在 settings_provider.loadSettings 内统一调入.
  static Future<void> loadInitial(dynamic container) async {
    // Summary
    final atStr = await SettingsService.loadString(keyLastAutoBackupAt, '');
    if (atStr.isNotEmpty) {
      final at = DateTime.tryParse(atStr);
      if (at != null) {
        final uploaded = await SettingsService.loadInt(
            keyLastAutoBackupUploadedImages, 0);
        final skipped = await SettingsService.loadInt(
            keyLastAutoBackupSkippedImages, 0);
        final bytes = await SettingsService.loadInt(
            keyLastAutoBackupUploadedBytes, 0);
        container.read(lastAutoBackupSummaryProvider.notifier).state =
            AutoBackupSummary(
          completedAt: at,
          uploadedImages: uploaded,
          skippedImages: skipped,
          uploadedDrafts: 0,
          uploadedBytes: bytes,
          dbUploaded: true,
        );
      }
    }
    // Error
    final errAtStr =
        await SettingsService.loadString(keyLastAutoBackupErrorAt, '');
    if (errAtStr.isNotEmpty) {
      final at = DateTime.tryParse(errAtStr);
      if (at != null) {
        final reason = await SettingsService.loadString(
            keyLastAutoBackupErrorReason, '');
        final count = await SettingsService.loadInt(
            keyLastAutoBackupErrorConsecutiveCount, 1);
        container.read(lastAutoBackupErrorProvider.notifier).state =
            AutoBackupError(
          occurredAt: at,
          reason: reason,
          consecutiveCount: count,
        );
      }
    }
  }
}
