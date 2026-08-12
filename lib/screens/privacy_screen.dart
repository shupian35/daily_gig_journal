import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_card.dart';

/// 隐私设置页面 —— 精致杂志风
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hideIncome = ref.watch(hideIncomeProvider);
    final hideStatistics = ref.watch(hideStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacySettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppConstants.primaryColor.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppConstants.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.privacyDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppConstants.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 隐藏收入金额
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.primaryColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  hideIncome
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppConstants.primaryDark,
                  size: 20,
                ),
              ),
              title: Text(l10n.hideIncomeAmount,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text(l10n.hideIncomeAmountSubtitle),
              value: hideIncome,
              onChanged: (value) {
                ref.read(hideIncomeProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(height: 10),

          // 隐藏统计数据
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.primaryColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  hideStatistics
                      ? Icons.bar_chart_outlined
                      : Icons.bar_chart_rounded,
                  color: AppConstants.primaryDark,
                  size: 20,
                ),
              ),
              title: Text(l10n.hideStatisticsPage,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text(l10n.hideStatisticsPageSubtitle),
              value: hideStatistics,
              onChanged: (value) {
                ref.read(hideStatisticsProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(height: 24),

          // 底部提示
          Center(
            child: Text(
              l10n.privacyHint,
              style: TextStyle(
                fontSize: 12,
                color: AppConstants.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
