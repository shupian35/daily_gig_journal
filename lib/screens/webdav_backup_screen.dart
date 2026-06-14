import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
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
    final isConfigured = ref.watch(webDavConfiguredProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('云备份'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 说明卡片 ──
          AppSectionLabel(title: '说明', icon: Icons.info_outline_rounded),
          const SizedBox(height: 8),
          AppCard(
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
                    '备份文件将存储在云盘 daily_gig_journal 目录下',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 服务器配置 ──
          AppSectionLabel(title: '服务器配置', icon: Icons.dns_outlined),
          const SizedBox(height: 8),
          AppCard(
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
          AppSectionLabel(title: '操作', icon: Icons.sync_rounded),
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
                          : _showRestoreFilePicker,
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
          AppSectionLabel(title: '自动备份', icon: Icons.auto_mode_rounded),
          const SizedBox(height: 8),
          AppCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.sync_rounded,
                  size: 22, color: AppConstants.primaryDark),
              title: const Text('保存/删除时自动备份',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: const Text('开启后，每次新增、修改或删除日程时自动备份到云盘'),
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
      final dbPath = await DatabaseHelper.getDatabasePath();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final remoteName = 'daily_gig_backup_$timestamp.db';

      final result = await _buildHelper().uploadFile(dbPath, remoteName);

      if (!mounted) return;
      setState(() => _isBackingUp = false);
      _showOpStatus(result.message, error: !result.isSuccess);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      _showOpStatus('备份失败: $e', error: true);
    }
  }

  Future<void> _showRestoreFilePicker() async {
    if (!mounted) return;
    final helper = _buildHelper();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _CloudFileListSheet(
        helper: helper,
        onFileSelected: (file) {
          Navigator.pop(sheetCtx);
          _restoreSelectedFile(file);
        },
      ),
    );
  }

  Future<void> _restoreSelectedFile(WebDavFileInfo file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: Text(
          '即将从云盘恢复备份文件：\n\n${file.name}\n'
          '${file.formattedSize}  |  ${file.formattedDate}\n\n'
          '恢复数据将覆盖当前所有数据，此操作不可撤销。\n建议先备份当前数据再执行恢复。',
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
      _opMessage = null;
    });

    try {
      final dbPath = await DatabaseHelper.getDatabasePath();
      final result = await _buildHelper().downloadFile(file.href, dbPath);

      if (!mounted) return;
      setState(() => _isRestoring = false);
      _showOpStatus(
        result.isSuccess
            ? '恢复成功！请重启应用以加载恢复的数据'
            : result.message,
        error: !result.isSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      _showOpStatus('恢复失败: $e', error: true);
    }
  }
}

class _CloudFileListSheet extends StatefulWidget {
  final WebDavHelper helper;
  final ValueChanged<WebDavFileInfo> onFileSelected;

  const _CloudFileListSheet({
    required this.helper,
    required this.onFileSelected,
  });

  @override
  State<_CloudFileListSheet> createState() => _CloudFileListSheetState();
}

class _CloudFileListSheetState extends State<_CloudFileListSheet> {
  bool _loading = true;
  String? _error;
  List<WebDavFileInfo> _files = [];

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    final result = await widget.helper.listFiles();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _files = result.files;
      } else {
        _error = result.errorMessage ?? '获取文件列表失败';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '选择备份文件',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '点击文件即可恢复该日期的备份',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppConstants.textSecondaryDark : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2)),
              Expanded(child: _buildContent(scrollCtrl)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollCtrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('正在获取备份文件列表...',
                style: TextStyle(fontSize: 13, color: AppConstants.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(
                    color: isDark ? AppConstants.textSecondaryDark : Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _fetchFiles();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('云端没有找到备份文件',
                style: TextStyle(
                    color: isDark ? AppConstants.textSecondaryDark : Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollCtrl,
      itemCount: _files.length,
      itemBuilder: (_, i) {
        final file = _files[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            side: BorderSide(
              color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
            ),
          ),
          color: isDark ? const Color(0xFF262630) : Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined,
                size: 22, color: AppConstants.primaryDark),
            title: Text(file.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${file.formattedSize}  |  ${file.formattedDate}',
              style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
            ),
            trailing: const Icon(Icons.download_rounded,
                size: 20, color: AppConstants.primaryDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            onTap: () => widget.onFileSelected(file),
          ),
        );
      },
    );
  }
}
