import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/webdav_helper.dart';

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
  bool _isListing = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  bool _statusError = false;
  List<WebDavFileInfo> _remoteFiles = [];

  // 使用稳定的控制器
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
    final isConfigured = ref.watch(webDavConfiguredProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('云备份'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 说明卡片 ──
          _buildSectionLabel('说明', Icons.info_outline_rounded),
          const SizedBox(height: 8),
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.cloud_outlined,
                    '支持坚果云等标准 WebDAV 服务器',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.vpn_key_outlined,
                    '坚果云用户请在「账户信息 → 安全选项」中生成应用密码',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.backup_outlined,
                    '备份文件将存储在你的云盘根目录下',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 服务器配置 ──
          _buildSectionLabel('服务器配置', Icons.dns_outlined),
          const SizedBox(height: 8),
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('服务器地址'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _urlController,
                    hint: defaultWebDavUrl,
                    onChanged: (v) {
                      ref.read(webDavUrlProvider.notifier).state = v;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('账号（坚果云为注册邮箱）'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _usernameController,
                    hint: 'your_email@example.com',
                    onChanged: (v) {
                      ref.read(webDavUsernameProvider.notifier).state = v;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('密码（坚果云需使用应用密码）'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _passwordController,
                    hint: '应用密码（非登录密码）',
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
                      label: Text(_isTesting ? '测试中...' : '测试连接'),
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
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 备份操作 ──
          _buildSectionLabel('操作', Icons.sync_rounded),
          const SizedBox(height: 8),
          _buildCard(
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
                      label: Text(_isBackingUp ? '备份中...' : '备份到云盘'),
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
                          : _restoreFromCloud,
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_rounded, size: 18),
                      label: Text(_isRestoring ? '恢复中...' : '从云盘恢复'),
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
                ],
              ),
            ),
          ),

          // ── 状态消息 ──
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _statusError
                    ? AppConstants.dangerRed.withValues(alpha: 0.06)
                    : AppConstants.incomeGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(
                  color: _statusError
                      ? AppConstants.dangerRed.withValues(alpha: 0.2)
                      : AppConstants.incomeGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: _statusError ? AppConstants.dangerRed : AppConstants.incomeGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _statusError ? AppConstants.dangerRed : AppConstants.incomeGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── 云端备份列表 ──
          if (isConfigured) ...[
            const SizedBox(height: 20),
            _buildSectionLabel('云端备份列表', Icons.list_alt_rounded),
            const SizedBox(height: 8),
            _buildCard(
              child: Column(
                children: [
                  // 刷新列表按钮
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Text(
                          '备份文件',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _isListing ? null : _listRemoteFiles,
                          icon: _isListing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('刷新'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppConstants.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_remoteFiles.isEmpty && !_isListing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: const Text(
                        '暂无备份文件',
                        style: TextStyle(
                          color: AppConstants.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ..._remoteFiles.map((file) => _buildFileItem(file, isDark)),
                ],
              ),
            ),
          ],
        ],
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

  Widget _buildFileItem(WebDavFileInfo file, bool isDark) {
    return Column(
      children: [
        Container(
          height: 0.5,
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.insert_drive_file_outlined,
              size: 20, color: AppConstants.primaryDark),
          title: Text(
            file.name,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${file.formattedSize}  ·  ${file.lastModified}',
            style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppConstants.dangerRed),
            onPressed: () => _deleteRemoteFile(file.name),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      ],
    );
  }

  // ======================== UI 组件 ========================

  Widget _buildSectionLabel(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppConstants.primaryDark),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppConstants.primaryDark,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: child,
    );
  }

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

  void _showStatus(String message, {bool error = false}) {
    setState(() {
      _statusMessage = message;
      _statusError = error;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final result = await _buildHelper().testConnection();

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _statusMessage = result.message;
      _statusError = !result.isSuccess;
    });

    // 成功后自动刷新文件列表
    if (result.isSuccess) {
      _listRemoteFiles();
    }
  }

  Future<void> _backupToCloud() async {
    setState(() {
      _isBackingUp = true;
      _statusMessage = null;
    });

    try {
      final dbPath = await DatabaseHelper.getDatabasePath();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final remoteName = 'daily_gig_backup_$timestamp.db';

      final result = await _buildHelper().uploadFile(dbPath, remoteName);

      if (!mounted) return;
      setState(() => _isBackingUp = false);
      _showStatus(result.message, error: !result.isSuccess);

      if (result.isSuccess) {
        _listRemoteFiles();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      _showStatus('备份失败: $e', error: true);
    }
  }

  Future<void> _restoreFromCloud() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text(
          '从云盘恢复数据将覆盖当前所有数据，此操作不可撤销。\n\n建议先备份当前数据再执行恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.dangerRed,
            ),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRestoring = true;
      _statusMessage = null;
    });

    try {
      // 先列出远端文件，选最新的
      final listResult = await _buildHelper().listFiles();
      if (!listResult.isSuccess || listResult.files.isEmpty) {
        if (mounted) {
          setState(() => _isRestoring = false);
        }
        _showStatus('云端没有找到备份文件', error: true);
        return;
      }

      final latest = listResult.files.first;
      final dbPath = await DatabaseHelper.getDatabasePath();

      final result = await _buildHelper().downloadFile(latest.name, dbPath);

      if (!mounted) return;
      setState(() => _isRestoring = false);
      _showStatus(
        result.isSuccess
            ? '恢复成功！请重启应用以加载恢复的数据'
            : result.message,
        error: !result.isSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      _showStatus('恢复失败: $e', error: true);
    }
  }

  Future<void> _listRemoteFiles() async {
    setState(() => _isListing = true);

    final result = await _buildHelper().listFiles();

    if (!mounted) return;
    setState(() {
      _isListing = false;
      if (result.isSuccess) {
        _remoteFiles = result.files;
      }
    });
  }

  Future<void> _deleteRemoteFile(String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除云端备份文件 "$fileName" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.dangerRed,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _buildHelper().deleteFile(fileName);
    _showStatus(result.message, error: !result.isSuccess);

    if (result.isSuccess) {
      _listRemoteFiles();
    }
  }
}
