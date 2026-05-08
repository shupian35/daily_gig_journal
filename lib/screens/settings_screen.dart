import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/export_helper.dart';
import 'privacy_screen.dart';

/// 设置页面
/// 包含主题切换、隐私设置、数据导出、备份恢复等功能
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题设置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.brightness_6, size: 20,
                            color: AppConstants.primaryDark),
                        const SizedBox(width: 8),
                        const Text('主题模式',
                            style:
                                TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: themeMode,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(themeModeProvider.notifier).state = v;
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: const Text('跟随系统'),
                          subtitle: const Text('自动跟随系统亮色/暗色设置'),
                          value: ThemeMode.system,
                          dense: true,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('浅色模式'),
                          subtitle: const Text('始终使用浅色主题'),
                          value: ThemeMode.light,
                          dense: true,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('深色模式'),
                          subtitle: const Text('始终使用暗色主题'),
                          value: ThemeMode.dark,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 隐私设置
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined,
                  color: AppConstants.primaryDark),
              title: const Text('隐私设置'),
              subtitle: const Text('控制收入金额和统计数据的显示'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 数据导出
          Card(
            child: ListTile(
              leading: _isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined,
                      color: AppConstants.primaryDark),
              title: const Text('导出数据'),
              subtitle: Text(
                _isExporting ? '正在导出...' : '将全部工作笔记导出为文件',
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: !_isExporting,
              onTap: _isExporting ? null : _showExportDialog,
            ),
          ),
          const SizedBox(height: 12),

          // 数据备份
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined,
                  color: AppConstants.primaryDark),
              title: const Text('备份与恢复'),
              subtitle: const Text('本地备份或从备份恢复数据（即将上线）'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('备份功能即将上线~'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 关于
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline,
                  color: AppConstants.primaryDark),
              title: const Text('关于日程清单'),
              subtitle: const Text('版本 1.0.0 —— 让每一份付出都有记录'),
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

  /// 显示导出格式选择对话框
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

  /// 执行导出并调起系统分享面板
  Future<void> _exportData(String format) async {
    setState(() => _isExporting = true);

    try {
      final filePath = await ExportHelper.exportToFile(format);

      if (!mounted) return;
      setState(() => _isExporting = false);

      // 通过系统分享面板保存/发送文件
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
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
