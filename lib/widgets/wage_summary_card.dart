import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

/// 月度工资摘要卡片
/// 显示当月预计总收入和工作天数
class WageSummaryCard extends StatelessWidget {
  /// 当月总收入
  final double totalWage;
  /// 当月工作天数
  final int workDays;
  /// 月份显示文字，如 "2025年3月"
  final String monthDisplay;

  const WageSummaryCard({
    super.key,
    required this.totalWage,
    required this.workDays,
    required this.monthDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF3D2800), const Color(0xFF4A3500)]
                : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 左侧圆形图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppConstants.primaryColor.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppConstants.primaryDark,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // 收入信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$monthDisplay 预计收入',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Helpers.formatCurrency(totalWage),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppConstants.primaryLight
                          : AppConstants.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            // 天数
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$workDays',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.incomeGreen,
                  ),
                ),
                Text(
                  '工作天数',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
