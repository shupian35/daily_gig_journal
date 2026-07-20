import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

/// 外观设置次级页 — 列表选择模式，选中即写 provider + pop 回上一页
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget option({
      required ThemeMode value,
      required String label,
      required String subtitle,
      required IconData icon,
    }) {
      final selected = value == themeMode;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          border: Border.all(
            color: selected
                ? AppConstants.primaryColor.withValues(alpha: 0.45)
                : (isDark
                    ? const Color(0xFF3A3A44)
                    : const Color(0xFFEDE8E2)),
            width: selected ? 1.0 : 0.5,
          ),
          boxShadow: AppConstants.cardShadow(isDark),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppConstants.primaryColor
                  .withValues(alpha: selected ? 0.18 : 0.08),
            ),
            child: Icon(icon, color: AppConstants.primaryDark, size: 20),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppConstants.primaryDark : null,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
          ),
          trailing: selected
              ? const Icon(
                  Icons.check_rounded,
                  color: AppConstants.primaryColor,
                  size: 22,
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: AppConstants.textSecondary,
                  size: 20,
                ),
          onTap: () {
            ref.read(themeModeProvider.notifier).state = value;
            Navigator.of(context).pop();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          option(
            value: ThemeMode.system,
            label: l10n.followSystem,
            subtitle: l10n.followSystemSubtitle,
            icon: Icons.settings_suggest_rounded,
          ),
          option(
            value: ThemeMode.light,
            label: l10n.lightMode,
            subtitle: l10n.lightModeSubtitle,
            icon: Icons.light_mode_rounded,
          ),
          option(
            value: ThemeMode.dark,
            label: l10n.darkMode,
            subtitle: l10n.darkModeSubtitle,
            icon: Icons.dark_mode_rounded,
          ),
        ],
      ),
    );
  }
}