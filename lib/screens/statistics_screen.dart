import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/work_note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

/// 工资统计页 —— 精致杂志风
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wageNotesAsync = ref.watch(wageNotesProvider);
    final monthlySummaryAsync = ref.watch(monthlySummaryProvider(6));
    final hideStatistics = ref.watch(hideStatisticsProvider);
    final hideIncome = ref.watch(hideIncomeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('工资统计'),
      ),
      body: wageNotesAsync.when(
        data: (notes) {
          if (hideStatistics) {
            return _buildPrivacyProtectedState();
          }
          if (notes.isEmpty) {
            return _buildEmptyState();
          }
          return _buildContent(context, notes, monthlySummaryAsync, hideIncome);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.dangerRed.withValues(alpha: 0.08),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 28, color: AppConstants.dangerRed),
              ),
              const SizedBox(height: 16),
              Text('加载失败: $err',
                  style: const TextStyle(color: AppConstants.dangerRed)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  ref.invalidate(wageNotesProvider);
                  ref.invalidate(monthlySummaryProvider);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryDark,
                  side: const BorderSide(color: AppConstants.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyProtectedState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppConstants.primaryColor.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.shield_outlined,
                size: 36,
                color: AppConstants.primaryColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          const Text(
            '统计数据已隐藏',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '可在 设置 → 隐私设置 中关闭隐藏',
            style: TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppConstants.primaryColor.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.bar_chart_rounded,
                size: 36,
                color: AppConstants.primaryColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          const Text(
            '还没有工资记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '添加工作笔记并填写工资后即可查看统计',
            style: TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<WorkNote> notes,
    AsyncValue<List<Map<String, dynamic>>> monthlySummaryAsync,
    bool hideIncome,
  ) {
    final grouped = _groupByMonth(notes);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isTablet = constraints.maxWidth >= 700;

        if (isTablet) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildBarChart(context, monthlySummaryAsync, hideIncome),
                ),
              ),
              Container(
                width: 0.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3A3A44)
                    : const Color(0xFFEDE8E2),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: grouped.entries.map((entry) {
                      final mn = entry.value;
                      return _buildMonthSection(
                        context,
                        monthKey: entry.key,
                        notes: mn,
                        monthlyTotal: mn.fold(0.0, (s, n) => s + n.dailyWage),
                        workDays: mn.length,
                        hideIncome: hideIncome,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBarChart(context, monthlySummaryAsync, hideIncome),
              const SizedBox(height: 8),
              ...grouped.entries.map((entry) {
                final mn = entry.value;
                return _buildMonthSection(
                  context,
                  monthKey: entry.key,
                  notes: mn,
                  monthlyTotal: mn.fold(0.0, (s, n) => s + n.dailyWage),
                  workDays: mn.length,
                  hideIncome: hideIncome,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<WorkNote>> _groupByMonth(List<WorkNote> notes) {
    final map = <String, List<WorkNote>>{};
    for (final note in notes) {
      final monthKey = note.date.substring(0, 7);
      map.putIfAbsent(monthKey, () => []).add(note);
    }
    return map;
  }

  Widget _buildBarChart(BuildContext context,
      AsyncValue<List<Map<String, dynamic>>> async, bool hideIncome) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 18, color: AppConstants.primaryDark),
                const SizedBox(width: 8),
                const Text(
                  '近6个月收入趋势',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: async.when(
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(
                      child: Text('暂无数据',
                          style: TextStyle(color: AppConstants.textSecondary)),
                    );
                  }
                  return _buildFlBarChart(data, hideIncome);
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, _) => Center(
                  child: Text('加载失败',
                      style: TextStyle(
                          color: AppConstants.dangerRed.withValues(alpha: 0.8))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlBarChart(List<Map<String, dynamic>> data, bool hideIncome) {
    final sortedData = data.reversed.toList();
    if (sortedData.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    double maxTotal = 0;
    for (final d in sortedData) {
      final total = (d['total'] as num?)?.toDouble() ?? 0.0;
      if (total > maxTotal) maxTotal = total;
    }
    maxTotal = maxTotal > 0 ? maxTotal * 1.2 : 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxTotal,
        barTouchData: hideIncome
            ? BarTouchData(enabled: false)
            : BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= sortedData.length) {
                      return null;
                    }
                    final month =
                        sortedData[groupIndex]['month'] as String? ?? '';
                    final total = (rod.toY).toStringAsFixed(1);
                    return BarTooltipItem(
                      '${Helpers.toDisplayMonth(month)}\n¥$total',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedData.length) {
                  final month = sortedData[index]['month'] as String;
                  final parts = month.split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${parts[1]}月',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !hideIncome,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                return Text(
                  '¥${value.toInt()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppConstants.textSecondary,
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: !hideIncome,
          drawVerticalLine: false,
          horizontalInterval: maxTotal / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5DFD8).withValues(alpha: 0.5),
              strokeWidth: 0.5,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: sortedData.asMap().entries.map((entry) {
          final index = entry.key;
          final d = entry.value;
          final total = (d['total'] as num?)?.toDouble() ?? 0.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total,
                color: AppConstants.primaryColor,
                width: 22,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
                gradient: LinearGradient(
                  colors: [
                    AppConstants.primaryColor,
                    AppConstants.primaryDark,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthSection(
    BuildContext context, {
    required String monthKey,
    required List<WorkNote> notes,
    required double monthlyTotal,
    required int workDays,
    required bool hideIncome,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 月份头部
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusXl),
                topRight: Radius.circular(AppConstants.radiusXl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Helpers.toDisplayMonth(monthKey),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '共$workDays天',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppConstants.textSecondaryDark
                            : AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      hideIncome
                          ? '***'
                          : Helpers.formatCurrency(monthlyTotal),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.incomeGreen,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 日期条目列表
          ...notes.map((note) {
            final displayDate = Helpers.toDisplayDate(note.date);
            final date = Helpers.parseDate(note.date);
            final weekday = date != null ? Helpers.getChineseWeekday(date) : '';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        weekday,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppConstants.textSecondaryDark
                              : AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : '(无标题)',
                      style: TextStyle(
                        fontSize: 14,
                        color: note.title.isNotEmpty
                            ? null
                            : AppConstants.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Helpers.formatHours(note.workHours),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppConstants.textSecondaryDark
                              : AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hideIncome
                            ? '***'
                            : Helpers.formatCurrency(note.dailyWage),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.incomeGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
