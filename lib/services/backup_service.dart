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

  /// 复制并替换部分集合（merge/标记类操作的基础）。
  BackupChangeSet copyWith({
    Set<String>? imagesToUpload,
    Set<String>? draftsToUpload,
    Set<String>? imagesToTrash,
    Set<String>? draftsToTrash,
  }) {
    return BackupChangeSet(
      imagesToUpload: imagesToUpload ?? this.imagesToUpload,
      draftsToUpload: draftsToUpload ?? this.draftsToUpload,
      imagesToTrash: imagesToTrash ?? this.imagesToTrash,
      draftsToTrash: draftsToTrash ?? this.draftsToTrash,
    );
  }
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

/// 变更集的类型化写入口（ADR-0010）。资源接缝（[ResourceStore]）在落盘后
/// 调用 markXxx 上报；全量同步用 [mergeForFullSync]，禁止覆盖式赋值。
class BackupChangeSetNotifier extends Notifier<BackupChangeSet> {
  @override
  BackupChangeSet build() => const BackupChangeSet();

  void markImageUpload(String relPath) =>
      state = state.copyWith(imagesToUpload: {...state.imagesToUpload, relPath});

  void markDraftUpload(String relPath) =>
      state = state.copyWith(draftsToUpload: {...state.draftsToUpload, relPath});

  void markImageTrash(String relPath) =>
      state = state.copyWith(imagesToTrash: {...state.imagesToTrash, relPath});

  void markDraftTrash(String relPath) =>
      state = state.copyWith(draftsToTrash: {...state.draftsToTrash, relPath});

  /// 手动"备份到云盘"的 merge 语义：上传集 = 已有 pending ∪ 本次扫描结果，
  /// trash 条目原样保留（软删除不得因全量同步而静默丢失）。
  /// 调用方扫描的是磁盘现状，理论上已包含 pending upload；取并集是防御
  /// 扫描与标记并发交错。
  void mergeForFullSync({
    required Set<String> imagesToUpload,
    required Set<String> draftsToUpload,
  }) {
    state = state.copyWith(
      imagesToUpload: {...state.imagesToUpload, ...imagesToUpload},
      draftsToUpload: {...state.draftsToUpload, ...draftsToUpload},
    );
  }

  /// autoBackup 成功取走变更集后清空。
  void reset() => state = const BackupChangeSet();
}

/// Change set tracking provider (ADR-0010).
final backupChangeSetProvider =
    NotifierProvider<BackupChangeSetNotifier, BackupChangeSet>(
        BackupChangeSetNotifier.new);

/// ADR-0011: last successful summary.
final lastAutoBackupSummaryProvider =
    StateProvider<AutoBackupSummary?>((ref) => null);

/// ADR-0011: last error.
final lastAutoBackupErrorProvider =
    StateProvider<AutoBackupError?>((ref) => null);

/// Unified backup service (ADR-0010 incremental + ADR-0011 observability).
///
/// 架构审查候选 D：由静态过程 + 服务定位器签名改为实例化深模块。
/// 依赖经构造器注入（helperFactory / localDbPathResolver / clock），
/// Riverpod provider 见 [backupServiceProvider]。
/// 「运行中互斥」是实例状态（[runAutoBackup] 的 Future 锁），手动全量
/// 同步与自动备份共用同一入口；节流窗口仍在 EntryCoordinator。
class BackupService {
  /// WebDAV 客户端工厂。每次运行新建一个 helper；
  /// 测试注入携带 fake transport 的工厂。
  final WebDavHelper Function() _helperFactory;

  /// 本地数据库绝对路径解析器（其所在目录即应用文档目录，ADR-0009 相对路径基准）。
  final Future<String> Function() _localDbPathResolver;

  /// 时钟注入（summary 时间戳 + trashed 清理 cutoff），测试可固定。
  final DateTime Function() _clock;

  /// 设置开关与变更集/横幅状态的读取入口。
  final ProviderContainer _container;

  BackupService({
    required ProviderContainer container,
    WebDavHelper Function()? helperFactory,
    Future<String> Function()? localDbPathResolver,
    DateTime Function()? clock,
  })  : _container = container,
        _helperFactory = helperFactory ??
            (() => WebDavHelper(
                  serverUrl: container.read(webDavUrlProvider),
                  username: container.read(webDavUsernameProvider),
                  password: container.read(webDavPasswordProvider),
                )),
        _localDbPathResolver = localDbPathResolver ??
            (() => container.read(workEntryRepositoryProvider).filePath()),
        _clock = clock ?? DateTime.now;

  static const String cloudDbName = 'daily_gig_journal.db';
  static const String imagesSubDir = 'images';
  static const String draftsSubDir = 'drafts';
  static const String trashedSubDir = 'trashed';

  static const int autoBackupRetentionDays = 30;

  // ==================== 运行中互斥（候选 D 下沉到 service） ====================

  Future<void>? _active;

  AutoBackupRun runAutoBackup() {
    final active = _active;
    if (active != null) {
      return AutoBackupRun(started: false, completion: active);
    }
    final done = _execute();
    _active = done;
    return AutoBackupRun(started: true, completion: done);
  }

  Future<void> _execute() async {
    try {
      await _doAutoBackup();
    } finally {
      _active = null;
    }
  }

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

  /// Auto-backup: incremental upload of DB + images/ + drafts/ changes + soft-delete (ADR-0010).
  Future<void> _doAutoBackup() async {
    AutoBackupSummary? summary;
    try {
      final enabled = _container.read(autoBackupProvider);
      final configured = _container.read(webDavConfiguredProvider);
      if (!enabled || !configured) return;

      final helper = _helperFactory();
      final localDbPath = await _localDbPathResolver();

      final changes = _container.read(backupChangeSetProvider);
      _container.read(backupChangeSetProvider.notifier).reset();

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
        completedAt: _clock(),
        uploadedImages: uploadedImages,
        skippedImages: skippedImages,
        uploadedDrafts: uploadedDrafts,
        uploadedBytes: uploadedBytes,
        dbUploaded: dbUploaded,
      );
    } catch (e) {
      final prev = _container.read(lastAutoBackupErrorProvider);
      final err = AutoBackupError(
        occurredAt: _clock(),
        reason: e.toString(),
        consecutiveCount: (prev?.consecutiveCount ?? 0) + 1,
      );
      _container.read(lastAutoBackupErrorProvider.notifier).state = err;
      await _persistError(err);
      return;
    }

    // Success: write summary, clear error, persist (ADR-0011 cross-restart).
    _container.read(lastAutoBackupSummaryProvider.notifier).state = summary;
    _container.read(lastAutoBackupErrorProvider.notifier).state = null;
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

  /// Clean up trashed/ older than 30 days（消费 [WebDavFileInfo.lastModified]
  /// 类型化时间；解析失败的条目视为未过期，不动）。
  Future<void> _cleanupTrashed(WebDavHelper helper) async {
    try {
      final list = await helper.listFilesInSubDir(trashedSubDir);
      if (!list.isSuccess) return;
      final cutoff =
          _clock().subtract(const Duration(days: autoBackupRetentionDays));
      for (final f in list.files) {
        final lm = f.lastModified;
        if (lm == null || !lm.isBefore(cutoff)) continue;
        await helper.deleteFile('$trashedSubDir/${f.name}');
      }
    } catch (_) {}
  }

  /// ADR-0011: 应用启动时从 SharedPreferences 恢复上次备份状态 (summary + error).
  /// 调用方在 settings_provider.loadSettings 内统一调入。
  /// 不再吃 container/ref：由调用方注入两个状态写入口。
  static Future<void> loadInitial({
    required void Function(AutoBackupSummary?) setSummary,
    required void Function(AutoBackupError?) setError,
  }) async {
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
        setSummary(AutoBackupSummary(
          completedAt: at,
          uploadedImages: uploaded,
          skippedImages: skipped,
          uploadedDrafts: 0,
          uploadedBytes: bytes,
          dbUploaded: true,
        ));
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
        setError(AutoBackupError(
          occurredAt: at,
          reason: reason,
          consecutiveCount: count,
        ));
      }
    }
  }
}

/// [BackupService.runAutoBackup] 的返回值：本次调用是否真正启动了备份
/// （false = 已有备份在跑，被互斥跳过），以及该次运行的完成信号
/// （跳过时即已在跑的那次的完成信号）。
class AutoBackupRun {
  final bool started;
  final Future<void> completion;

  const AutoBackupRun({required this.started, required this.completion});
}

/// 实例化 BackupService 的注入点。手动全量同步与自动备份共用同一实例，
/// 因此共用其内部互斥。
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(container: ref.container);
});
