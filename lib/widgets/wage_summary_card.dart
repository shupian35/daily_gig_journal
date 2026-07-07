import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

/// 月度工资摘要卡片 —— 精致杂志风
/// 显示当月预计总收入和工作次数
class WageSummaryCard extends StatelessWidget {
  final double totalWage;
  final int workDays;
  final String monthDisplay;

  const WageSummaryCard({
    super.key,
    required this.totalWage,
    required this.workDays,
    required this.monthDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF3D2A1E), Color(0xFF2D2018)]
              : const [Color(0xFFFFF6ED), Color(0xFFFCE8D5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFFC8895A).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark
              ? const Color(0xFF4A3422)
              : const Color(0xFFF2D5B8),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            // 左侧装饰
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFFC8895A).withValues(alpha: 0.2)
                    : const Color(0xFFFFFFFF).withValues(alpha: 0.6),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFC8895A).withValues(alpha: 0.3)
                      : const Color(0xFFC8895A).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppConstants.primaryDark,
                size: 24,
              ),
            ),
            const SizedBox(width: 18),
            // 收入信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$monthDisplay ${l10n.estimatedIncome}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFB8A898)
                          : const Color(0xFF8D7E76),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Helpers.formatCurrency(totalWage, locale),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppConstants.primaryLight
                          : AppConstants.primaryDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            // 天数指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF5A8F7B).withValues(alpha: 0.15)
                    : const Color(0xFF5A8F7B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    '$workDays',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF7BBBA5)
                          : AppConstants.incomeGreen,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    l10n.workTimes,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF8AA89A)
                          : const Color(0xFF7A9E8E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
