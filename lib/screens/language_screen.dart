import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_selectable_tile.dart';

/// 语言设置次级页 — 列表选择模式，选中即写 provider + pop 回上一页
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    bool isSelected(Locale? option) {
      if (option == null && currentLocale == null) return true;
      if (option == null || currentLocale == null) return false;
      return option.languageCode == currentLocale.languageCode &&
          (option.countryCode ?? '') == (currentLocale.countryCode ?? '');
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSelectableTile(
            title: l10n.followSystem,
            icon: Icons.phone_android_rounded,
            selected: isSelected(null),
            onTap: () {
              ref.read(localeProvider.notifier).state = null;
              Navigator.of(context).pop();
            },
          ),
          AppSelectableTile(
            title: l10n.chinese,
            icon: Icons.translate_rounded,
            selected: isSelected(const Locale('zh')),
            onTap: () {
              ref.read(localeProvider.notifier).state = const Locale('zh');
              Navigator.of(context).pop();
            },
          ),
          AppSelectableTile(
            title: l10n.english,
            icon: Icons.translate_rounded,
            selected: isSelected(const Locale('en')),
            onTap: () {
              ref.read(localeProvider.notifier).state = const Locale('en');
              Navigator.of(context).pop();
            },
          ),
          AppSelectableTile(
            title: l10n.traditionalChinese,
            icon: Icons.translate_rounded,
            selected: isSelected(const Locale('zh', 'TW')),
            onTap: () {
              ref.read(localeProvider.notifier).state = const Locale('zh', 'TW');
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}