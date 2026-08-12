import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_selectable_tile.dart';

/// 外观设置次级页 — 列表选择模式，选中即写 provider + pop 回上一页
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSelectableTile(
            title: l10n.followSystem,
            subtitle: l10n.followSystemSubtitle,
            icon: Icons.settings_suggest_rounded,
            selected: themeMode == ThemeMode.system,
            onTap: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.system;
              Navigator.of(context).pop();
            },
          ),
          AppSelectableTile(
            title: l10n.lightMode,
            subtitle: l10n.lightModeSubtitle,
            icon: Icons.light_mode_rounded,
            selected: themeMode == ThemeMode.light,
            onTap: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.light;
              Navigator.of(context).pop();
            },
          ),
          AppSelectableTile(
            title: l10n.darkMode,
            subtitle: l10n.darkModeSubtitle,
            icon: Icons.dark_mode_rounded,
            selected: themeMode == ThemeMode.dark,
            onTap: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}