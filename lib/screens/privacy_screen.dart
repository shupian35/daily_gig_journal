import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

/// 隐私设置页面
/// 允许用户控制收入金额和统计数据的显示
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideIncome = ref.watch(hideIncomeProvider);
    final hideStatistics = ref.watch(hideStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppConstants.primaryDark,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '隐私设置帮助你控制在应用中显示的敏感信息。'
                      '开启隐藏后，相关数据将以"***"代替。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 隐藏收入金额
          Card(
            child: SwitchListTile(
              secondary: Icon(
                hideIncome
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppConstants.primaryDark,
              ),
              title: const Text('隐藏收入金额'),
              subtitle: const Text('开启后，所有页面的收入金额将显示为"***"'),
              value: hideIncome,
              onChanged: (value) {
                ref.read(hideIncomeProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(height: 12),

          // 隐藏统计数据
          Card(
            child: SwitchListTile(
              secondary: Icon(
                hideStatistics
                    ? Icons.bar_chart_outlined
                    : Icons.bar_chart,
                color: AppConstants.primaryDark,
              ),
              title: const Text('隐藏统计页面'),
              subtitle: const Text('开启后，统计Tab将显示为空状态，保护你的收入数据隐私'),
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
              '隐私设置即时生效，无需重启应用',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
