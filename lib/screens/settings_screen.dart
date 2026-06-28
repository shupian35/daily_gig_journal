import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/database_helper.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/export_helper.dart';
import '../widgets/app_card.dart';
import '../widgets/app_section_label.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 语言设置 ──
          AppSectionLabel(title: l10n.language, icon: Icons.language_rounded),
          const SizedBox(height: 8),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocaleRadioTile(
                    null,
                    currentLocale,
                    Icons.phone_android_rounded,
                    l10n.followSystem,
                    '',
                  ),
                  _buildLocaleRadioTile(
                    const Locale('zh'),
                    currentLocale,
                    Icons.language_rounded,
                    l10n.chinese,
                    '',
                  ),
                  _buildLocaleRadioTile(
                    const Locale('en'),
                    currentLocale,
                    Icons.language_rounded,
                    l10n.english,
                    '',
                  ),
                  _buildLocaleRadioTile(
                    const Locale('zh', 'TW'),
                    currentLocale,
                    Icons.language_rounded,
                    l10n.traditionalChinese,
                    '',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 主题设置 ──
          AppSectionLabel(title: l10n.appearance, icon: Icons.brightness_6_rounded),
          const SizedBox(height: 8),
          AppCard(
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
                          l10n.followSystem,
                          l10n.followSystemSubtitle,
                        ),
                        _buildRadioTile(
                          ThemeMode.light,
                          themeMode,
                          Icons.light_mode_rounded,
                          l10n.lightMode,
                          l10n.lightModeSubtitle,
                        ),
                        _buildRadioTile(
                          ThemeMode.dark,
                          themeMode,
                          Icons.dark_mode_rounded,
                          l10n.darkMode,
                          l10n.darkModeSubtitle,
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
          AppSectionLabel(title: l10n.privacy, icon: Icons.shield_outlined),
          const SizedBox(height: 8),
          AppCard(
            child: _buildNavTile(
              icon: Icons.shield_outlined,
              title: l10n.privacyNavTitle,
              subtitle: l10n.privacyNavSubtitle,
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
          AppSectionLabel(title: l10n.data, icon: Icons.folder_outlined),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _buildNavTile(
                  icon: Icons.file_download_outlined,
                  title: l10n.exportData,
                  subtitle: _isExporting ? l10n.exporting : l10n.exportDataSubtitle,
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
                  title: l10n.backupAndRestore,
                  subtitle: _isBackingUp ? l10n.processing : l10n.backupAndRestoreSubtitle,
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
                  title: l10n.cloudBackupWebDAV,
                  subtitle: l10n.cloudBackupSubtitle,
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
          AppSectionLabel(title: l10n.about, icon: Icons.info_outline_rounded),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _buildNavTile(
                  icon: Icons.info_outline_rounded,
                  title: l10n.aboutAppTitle,
                  subtitle: l10n.aboutAppSubtitle,
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: l10n.aboutAppName,
                      applicationVersion: '1.2.0',
                      applicationLegalese: l10n.aboutAppLegalese,
                      children: [
                        const SizedBox(height: 12),
                        Text(l10n.aboutAppBody),
                      ],
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildNavTile(
                  icon: Icons.open_in_new_rounded,
                  title: l10n.projectHomepage,
                  subtitle: l10n.projectHomepageSubtitle,
                  onTap: _openProjectHomepage,
                ),
                _buildDivider(isDark),
                _buildNavTile(
                  icon: Icons.bug_report_outlined,
                  title: l10n.errorLog,
                  subtitle: l10n.errorLogSubtitle,
                  onTap: _showErrorLog,
                ),
                _buildDivider(isDark),
                _buildNavTile(
                  icon: Icons.system_update_rounded,
                  title: l10n.checkUpdate,
                  subtitle: l10n.checkUpdateSubtitle,
                  onTap: _checkForUpdates,
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildLocaleRadioTile(
    Locale? value,
    Locale? groupValue,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = value == groupValue ||
        (value == null && groupValue == null) ||
        (value != null &&
            groupValue != null &&
            value.languageCode == groupValue.languageCode &&
            (value.countryCode ?? '') == (groupValue.countryCode ?? ''));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => ref.read(localeProvider.notifier).state = value,
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
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppConstants.primaryDark : null,
                ),
              ),
            ),
            Radio<Locale?>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                ref.read(localeProvider.notifier).state = v;
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
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectExportFormat),
        content: Text(l10n.exportDialogContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportData(ExportHelper.csv);
            },
            child: Text(l10n.csv),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportData(ExportHelper.json);
            },
            child: Text(l10n.json),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(String format) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);

    try {
      final filePath = await ExportHelper.exportToFile(format);

      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: l10n.exportShareSubject,
        text: l10n.exportShareText,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.exportFailed}: $e'),
          backgroundColor: AppConstants.dangerRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showBackupDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupRestoreDialogTitle),
        content: Text(l10n.backupRestoreDialogContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _backupDatabase();
            },
            child: Text(l10n.backup),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreDatabase();
            },
            child: Text(l10n.restore),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _backupDatabase() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBackingUp = true);
    try {
      final dbPath = await DatabaseHelper.getDatabasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception(l10n.dbFileNotExist);
      }
      final tempDir = Directory.systemTemp;
      final backupName =
          '${l10n.backupFilePrefix}${DateTime.now().toIso8601String().substring(0, 10)}.db';
      final backupFile = File('${tempDir.path}/$backupName');
      await dbFile.copy(backupFile.path);

      if (!mounted) return;
      setState(() => _isBackingUp = false);

      await Share.shareXFiles([XFile(backupFile.path)],
          subject: l10n.backupShareSubject, text: l10n.backupShareText);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.backupFailed}: $e'),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
    }
  }

  Future<void> _restoreDatabase() async {
    final l10n = AppLocalizations.of(context)!;
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
        SnackBar(
          content: Text(l10n.restoreSuccess),
          backgroundColor: AppConstants.incomeGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.restoreFailed}: $e'),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
    }
  }

  static const String _githubUrl =
      'https://github.com/shupian35/daily_gig_journal';
  static const String _githubApiUrl =
      'https://api.github.com/repos/shupian35/daily_gig_journal/releases/latest';

  Future<void> _openProjectHomepage() async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse(_githubUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.checkUpdateFailed),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
    }
  }

  void _showErrorLog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.errorLogTitle),
        content: Text(l10n.noErrorLogs),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final response = await http.get(Uri.parse(_githubApiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String? ?? '';
        final latestVersion = tagName.replaceFirst('v', '');

        if (latestVersion.isNotEmpty && latestVersion != '1.2.0') {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.updateAvailable(latestVersion)),
              content: Text(data['body'] as String? ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    launchUrl(
                      Uri.parse('${_githubUrl}/releases/latest'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(l10n.checkUpdate),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noUpdatesAvailable),
              backgroundColor: AppConstants.incomeGreen,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkUpdateFailed),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.checkUpdateFailed}: $e'),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
    }
  }
}
