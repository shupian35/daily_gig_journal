import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

/// 语言设置次级页 — 列表选择模式，选中即写 provider + pop 回上一页
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool isSelected(Locale? option) {
      if (option == null && currentLocale == null) return true;
      if (option == null || currentLocale == null) return false;
      return option.languageCode == currentLocale.languageCode &&
          (option.countryCode ?? '') == (currentLocale.countryCode ?? '');
    }

    Widget option({
      required Locale? value,
      required String label,
      required IconData icon,
    }) {
      final selected = isSelected(value);
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
            ref.read(localeProvider.notifier).state = value;
            Navigator.of(context).pop();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          option(
            value: null,
            label: l10n.followSystem,
            icon: Icons.phone_android_rounded,
          ),
          option(
            value: const Locale('zh'),
            label: l10n.chinese,
            icon: Icons.translate_rounded,
          ),
          option(
            value: const Locale('en'),
            label: l10n.english,
            icon: Icons.translate_rounded,
          ),
          option(
            value: const Locale('zh', 'TW'),
            label: l10n.traditionalChinese,
            icon: Icons.translate_rounded,
          ),
        ],
      ),
    );
  }
}