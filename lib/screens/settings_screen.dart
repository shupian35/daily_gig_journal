import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/export_helper.dart';
import 'privacy_screen.dart';
import 'webdav_backup_screen.dart';

/// 设置页面 —— 精致杂志风
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isBackingUp = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 主题设置 ──
          _buildSectionLabel('外观', Icons.brightness_6_rounded),
          const SizedBox(height: 8),
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<ThemeMode>(
                    groupValue: themeMode,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(themeModeProvider.notifier).state = v;
                      }
                    },
                    child: Column(
                      children: [
                        _buildRadioTile(
                          ThemeMode.system,
                          themeMode,
                          Icons.settings_suggest_rounded,
                          '跟随系统',
                          '自动跟随系统亮色/暗色设置',
                        ),
                        _buildRadioTile(
                          ThemeMode.light,
                          themeMode,
                          Icons.light_mode_rounded,
                          '浅色模式',
                          '始终使用浅色主题',
                        ),
                        _buildRadioTile(
                          ThemeMode.dark,
                          themeMode,
                          Icons.dark_mode_rounded,
                          '深色模式',
                          '始终使用暗色主题',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 隐私设置 ──
          _buildSectionLabel('隐私', Icons.shield_outlined),
          const SizedBox(height: 8),
          _buildCard(
            child: _buildNavTile(
              icon: Icons.shield_outlined,
              title: '隐私设置',
              subtitle: '控制收入金额和统计数据的显示',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── 数据管理 ──
          _buildSectionLabel('数据', Icons.folder_outlined),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                _buildNavTile(
                  icon: Icons.file_download_outlined,
                  title: '导出数据',
                  subtitle: _isExporting ? '正在导出...' : '将全部工作笔记导出为文件',
                  trailing: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !_isExporting,
                  onTap: _isExporting ? null : _showExportDialog,
                ),
                _buildDivider(isDark),
                _buildNavTile(
                  icon: Icons.backup_outlined,
                  title: '备份与恢复',
                  subtitle: _isBackingUp ? '处理中...' : '导出数据库备份或从备份恢复',
                  trailing: _isBackingUp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !_isBackingUp,
                  onTap: _isBackingUp ? null : _showBackupDialog,
                ),
                _buildDivider(isDark),
                _buildNavTile(
                  icon: Icons.cloud_outlined,
                  title: '云备份 (WebDAV)',
                  subtitle: '备份到坚果云或自定义服务器',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WebDavBackupScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 关于 ──
          _buildSectionLabel('关于', Icons.info_outline_rounded),
          const SizedBox(height: 8),
          _buildCard(
            child: _buildNavTile(
              icon: Icons.info_outline_rounded,
              title: '关于日程清单',
              subtitle: '版本 1.0.0 —— 让每一份付出都有记录',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: '日程清单',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '帮助日结兼职人员轻松记录工作与收入',
                  children: [
                    const SizedBox(height: 12),
                    const Text('温暖地记录每一天的辛劳，让付出可视化。'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppConstants.primaryDark, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppConstants.textSecondary, size: 20),
      enabled: enabled,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildRadioTile(
    ThemeMode value,
    ThemeMode groupValue,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = value == groupValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => ref.read(themeModeProvider.notifier).state = value,
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryColor.withValues(alpha: isDark ? 0.12 : 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: isSelected
              ? Border.all(
                  color: AppConstants.primaryColor.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppConstants.primaryColor.withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? AppConstants.primaryDark : AppConstants.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppConstants.primaryDark : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<ThemeMode>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) ref.read(themeModeProvider.notifier).state = v;
              },
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppConstants.primaryColor;
                }
                return AppConstants.textSecondary;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
    );
  }

  void _showExportDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择导出格式'),
        content: const Text('将全部工作笔记导出为文件，请选择格式：'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportData(ExportHelper.csv);
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportData(ExportHelper.json);
            },
            child: const Text('JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(String format) async {
    setState(() => _isExporting = true);

    try {
      final filePath = await ExportHelper.exportToFile(format);

      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '日程清单数据导出',
        text: '日程清单导出的工作笔记数据',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: AppConstants.dangerRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showBackupDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备份与恢复'),
        content:
            const Text('备份：将数据库导出为文件\n恢复：从备份文件恢复数据（会覆盖当前数据）'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _backupDatabase();
            },
            child: const Text('备份'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreDatabase();
            },
            child: const Text('恢复'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _backupDatabase() async {
    setState(() => _isBackingUp = true);
    try {
      final dbPath = await DatabaseHelper.getDatabasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception('数据库文件不存在');
      }
      final tempDir = Directory.systemTemp;
      final backupName =
          '日程清单_备份_${DateTime.now().toIso8601String().substring(0, 10)}.db';
      final backupFile = File('${tempDir.path}/$backupName');
      await dbFile.copy(backupFile.path);

      if (!mounted) return;
      setState(() => _isBackingUp = false);

      await Share.shareXFiles([XFile(backupFile.path)],
          subject: '日程清单数据备份', text: '日程清单数据库备份文件');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('备份失败: $e'),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
    }
  }

  Future<void> _restoreDatabase() async {
    setState(() => _isBackingUp = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isBackingUp = false);
        return;
      }

      final pickedPath = result.files.single.path;
      if (pickedPath == null) {
        if (mounted) setState(() => _isBackingUp = false);
        return;
      }

      final dbPath = await DatabaseHelper.getDatabasePath();
      final bakPath = '$dbPath.bak';
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(bakPath);
      }
      try {
        await File(pickedPath).copy(dbPath);
      } catch (e) {
        final bakFile = File(bakPath);
        if (await bakFile.exists()) {
          await bakFile.copy(dbPath);
        }
        rethrow;
      }

      if (!mounted) return;
      setState(() => _isBackingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('恢复成功！请重启应用以加载数据'),
          backgroundColor: AppConstants.incomeGreen,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('恢复失败: $e'),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
    }
  }
}
