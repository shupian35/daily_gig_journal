import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/webdav_helper.dart';
import '../widgets/app_card.dart';
import '../widgets/app_section_label.dart';

/// WebDAV 云备份页面 —— 精致杂志风
class WebDavBackupScreen extends ConsumerStatefulWidget {
  const WebDavBackupScreen({super.key});

  @override
  ConsumerState<WebDavBackupScreen> createState() => _WebDavBackupScreenState();
}

class _WebDavBackupScreenState extends ConsumerState<WebDavBackupScreen> {
  bool _isTesting = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _obscurePassword = true;

  // 测试连接的提示
  String? _testMessage;
  bool _testError = false;

  // 备份/恢复操作的提示
  String? _opMessage;
  bool _opError = false;

  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: ref.read(webDavUrlProvider),
    );
    _usernameController = TextEditingController(
      text: ref.read(webDavUsernameProvider),
    );
    _passwordController = TextEditingController(
      text: ref.read(webDavPasswordProvider),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isConfigured = ref.watch(webDavConfiguredProvider);
    final lastError = ref.watch(lastAutoBackupErrorProvider);
    final lastSummary = ref.watch(lastAutoBackupSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cloudBackup),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── ADR-0011: 自动备份状态 banner ──
          if (lastError != null)
            _buildErrorBanner(context, l10n, lastError)
          else if (lastSummary != null)
            _buildSummaryBanner(context, l10n, lastSummary),
          // ── 说明卡片 ──
          AppSectionLabel(title: l10n.instructions, icon: Icons.info_outline_rounded),
          const SizedBox(height: 8),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.cloud_outlined,
                    l10n.webdavInfo,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.vpn_key_outlined,
                    l10n.jianguoyunInfo,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.backup_outlined,
                    l10n.backupPathInfo,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 服务器配置 ──
          AppSectionLabel(title: l10n.serverConfig, icon: Icons.dns_outlined),
          const SizedBox(height: 8),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(l10n.serverAddress),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _urlController,
                    hint: defaultWebDavUrl,
                    onChanged: (v) {
                      ref.read(webDavUrlProvider.notifier).state = v;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(l10n.accountLabel),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _usernameController,
                    hint: 'your_email@example.com',
                    onChanged: (v) {
                      ref.read(webDavUsernameProvider.notifier).state = v;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel(l10n.passwordLabel),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _passwordController,
                    hint: l10n.appPasswordHint,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                        color: AppConstants.textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    onChanged: (v) {
                      ref.read(webDavPasswordProvider.notifier).state = v;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 测试连接按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTesting || !isConfigured
                          ? null
                          : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find_rounded, size: 18),
                      label: Text(_isTesting ? l10n.testing : l10n.testConnection),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.primaryDark,
                        side: const BorderSide(color: AppConstants.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  // 测试连接提示
                  if (_testMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildStatusMessage(_testMessage!, error: _testError),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 备份操作 ──
          AppSectionLabel(title: l10n.actions, icon: Icons.sync_rounded),
          const SizedBox(height: 8),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 备份按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isBackingUp || !isConfigured ? null : _backupToCloud,
                      icon: _isBackingUp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(_isBackingUp ? l10n.backingUp : l10n.backupToCloud),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 恢复按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isRestoring || !isConfigured
                          ? null
                          : _confirmAndRestore,
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_rounded, size: 18),
                      label: Text(_isRestoring ? l10n.restoring : l10n.restoreFromCloud),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.incomeGreen,
                        side: const BorderSide(color: AppConstants.incomeGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  // 备份/恢复操作提示
                  if (_opMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildStatusMessage(_opMessage!, error: _opError),
                  ],
                ],
              ),
            ),
          ),

          // ── 自动备份 ──
          AppSectionLabel(title: l10n.autoBackup, icon: Icons.auto_mode_rounded),
          const SizedBox(height: 8),
          AppCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.sync_rounded,
                  size: 22, color: AppConstants.primaryDark),
              title: Text(l10n.autoBackupTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text(l10n.autoBackupSubtitle),
              value: ref.watch(autoBackupProvider),
              onChanged: isConfigured
                  ? (v) => ref.read(autoBackupProvider.notifier).state = v
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String message, {required bool error}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error
            ? AppConstants.dangerRed.withValues(alpha: 0.06)
            : AppConstants.incomeGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(
          color: error
              ? AppConstants.dangerRed.withValues(alpha: 0.2)
              : AppConstants.incomeGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: error ? AppConstants.dangerRed : AppConstants.incomeGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: error ? AppConstants.dangerRed : AppConstants.incomeGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ADR-0011: 上次备份失败 banner
  Widget _buildErrorBanner(BuildContext context, AppLocalizations l10n, AutoBackupError err) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCritical = err.consecutiveCount >= 3;
    final bgColor = isCritical
        ? (isDark ? const Color(0xFF5C2D1A) : const Color(0xFFFFEBE0))
        : (isDark ? const Color(0xFF4D4A2A) : const Color(0xFFFFF8E1));
    final iconColor = isCritical ? Colors.orange : Colors.amber.shade700;
    final timeStr = Helpers.formatTime(err.occurredAt);
    final titleText = isCritical
        ? l10n.autoBackupConsecutiveFailures(err.consecutiveCount)
        : l10n.autoBackupFailedBanner(timeStr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCritical ? Icons.error_outline : Icons.warning_amber_rounded,
                    size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              err.reason.isEmpty
                  ? l10n.autoBackupErrorUnknownReason
                  : err.reason,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (isCritical) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                    // ADR-1: ignore: use_build_context_synchronously
                    _fullSyncToCloud();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(l10n.autoBackupRetry,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      // 跳到本页（本页就是配置页）
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(l10n.autoBackupGoSettings,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ADR-0011: 上次备份成功 summary banner
  Widget _buildSummaryBanner(BuildContext context, AppLocalizations l10n, AutoBackupSummary summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = Helpers.formatTime(summary.completedAt);
    final stats = l10n.autoBackupSummaryUploadedN(
      summary.uploadedImages,
      summary.uploadedBytes,
      summary.skippedImages,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F3A2D) : const Color(0xFFE7F6EC),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: (isDark ? const Color(0xFF2E5340) : const Color(0xFFCFE3D6)),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 16, color: isDark ? const Color(0xFF7CC397) : const Color(0xFF3F8556)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.autoBackupSummaryRecent(timeStr, stats),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppConstants.primaryDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ======================== UI 组件 ========================

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppConstants.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  // ======================== WebDAV 操作 ========================

  WebDavHelper _buildHelper() {
    final url = ref.read(webDavUrlProvider);
    final username = ref.read(webDavUsernameProvider);
    final password = ref.read(webDavPasswordProvider);
    return WebDavHelper(
      serverUrl: url,
      username: username,
      password: password,
    );
  }

  void _showTestStatus(String message, {bool error = false}) {
    setState(() {
      _testMessage = message;
      _testError = error;
    });
  }

  void _showOpStatus(String message, {bool error = false}) {
    setState(() {
      _opMessage = message;
      _opError = error;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    final result = await _buildHelper().testConnection();

    if (!mounted) return;
    setState(() => _isTesting = false);
    _showTestStatus(result.message, error: !result.isSuccess);
  }

  Future<void> _backupToCloud() async {
    setState(() {
      _isBackingUp = true;
      _opMessage = null;
    });

    try {
      // ADR-0010: 手动备份也走增量路径 (DB + images/ + drafts/ 各自 PUT)
      // 复用 autoBackup 内部逻辑：构造全量变更集，确保所有本地资源都上传
      await _fullSyncToCloud();

      if (!mounted) return;
      setState(() => _isBackingUp = false);
      _showOpStatus('已上传 DB + images/ + drafts/ 到云盘', error: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      _showOpStatus('${AppLocalizations.of(context)!.backupFailedCloud}: $e', error: true);
    }
  }

  /// 手动"备份到云盘"按钮：把本地所有图片/草稿塞入变更集, 触发增量上传。
  /// 走 backupServiceProvider 实例入口——与自动备份共用同一运行中互斥
  /// （架构审查候选 D），不再 containerOf 直调静态方法。
  Future<void> _fullSyncToCloud() async {
    final service = ref.read(backupServiceProvider);
    final repo = ref.read(workEntryRepositoryProvider);
    final dbPath = await repo.filePath();
    final appDocsDir = dbPath.substring(0, dbPath.lastIndexOf('/'));

    // 1. 扫描本地所有 images/ 和 drafts/
    final imagesDir = Directory(p.join(appDocsDir, 'images'));
    final draftsDir = Directory(p.join(appDocsDir, 'drafts'));
    final allImages = <String>{};
    final allDrafts = <String>{};
    if (imagesDir.existsSync()) {
      for (final f in imagesDir.listSync()) {
        if (f is File) allImages.add('images/${p.basename(f.path)}');
      }
    }
    if (draftsDir.existsSync()) {
      for (final f in draftsDir.listSync()) {
        if (f is File) allDrafts.add('drafts/${p.basename(f.path)}');
      }
    }

    // 2. merge 进变更集（候选 A）：上传集取并集，pending trash 条目原样保留，
    //    不做覆盖式赋值——软删除不得因全量同步静默丢失
    ref.read(backupChangeSetProvider.notifier).mergeForFullSync(
          imagesToUpload: allImages,
          draftsToUpload: allDrafts,
        );

    // 3. 触发备份（互斥在 service 内部：自动备份进行中时本次直接跳过）
    final run = service.runAutoBackup();
    await run.completion;
  }

  Future<void> _confirmAndRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmRestore),
        content: Text(l10n.confirmRestoreDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.dangerRed,
            ),
            child: Text(l10n.confirmRestoreButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isRestoring = true;
      _opMessage = null;
    });

    try {
      final repo = ref.read(workEntryRepositoryProvider);
      final dbPath = await repo.filePath();
      // ADR-0010: 云端唯一可恢复对象是固定名 daily_gig_journal.db
      final result = await BackupService.restoreFromCloud(
        helper: _buildHelper(),
        localDbPath: dbPath,
      );
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess ? l10n.restoreSuccessCloud : '${l10n.restoreFailedCloud}: ${result.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.restoreFailedCloud}: $e')),
      );
    }
  }
}
