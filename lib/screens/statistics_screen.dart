import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/work_note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

/// 工资统计页
/// 按月份分组展示有工资记录的笔记，并提供月度柱状图
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
          // 如果用户开启了隐藏统计，显示隐私保护页面
          if (hideStatistics) {
            return _buildPrivacyProtectedState();
          }
          if (notes.isEmpty) {
            return _buildEmptyState();
          }
          return _buildContent(notes, monthlySummaryAsync, hideIncome);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('加载失败: $err', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(wageNotesProvider);
                  ref.invalidate(monthlySummaryProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建隐私保护状态
  Widget _buildPrivacyProtectedState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '统计数据已隐藏',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '可在 设置 → 隐私设置 中关闭隐藏',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '还没有工资记录',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '添加工作笔记并填写工资后即可查看统计',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// 构建统计内容
  Widget _buildContent(
    List<WorkNote> notes,
    AsyncValue<List<Map<String, dynamic>>> monthlySummaryAsync,
    bool hideIncome,
  ) {
    // 按月份分组
    final grouped = _groupByMonth(notes);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== 月度柱状图 =====
          _buildBarChart(monthlySummaryAsync, hideIncome),

          const SizedBox(height: 8),

          // ===== 月度详细列表 =====
          ...grouped.entries.map((entry) {
            final monthNotes = entry.value;
            final monthlyTotal =
                monthNotes.fold(0.0, (sum, n) => sum + n.dailyWage);
            final monthWorkDays = monthNotes.length;

            return _buildMonthSection(
              monthKey: entry.key,
              notes: monthNotes,
              monthlyTotal: monthlyTotal,
              workDays: monthWorkDays,
              hideIncome: hideIncome,
            );
          }),
        ],
      ),
    );
  }

  /// 按月份分组
  Map<String, List<WorkNote>> _groupByMonth(List<WorkNote> notes) {
    final map = <String, List<WorkNote>>{};
    for (final note in notes) {
      final monthKey = note.date.substring(0, 7); // YYYY-MM
      map.putIfAbsent(monthKey, () => []).add(note);
    }
    return map;
  }

  /// 构建月度柱状图
  Widget _buildBarChart(AsyncValue<List<Map<String, dynamic>>> async, bool hideIncome) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '近6个月收入趋势',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: async.when(
                data: (data) {
                  if (data.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    );
                  }
                  return _buildFlBarChart(data, hideIncome);
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, _) => Center(
                  child: Text('加载失败', style: TextStyle(color: Colors.red.shade300)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 使用 fl_chart 构建柱状图
  Widget _buildFlBarChart(List<Map<String, dynamic>> data, bool hideIncome) {
    // data 按 month DESC 排序，需要反转以显示从左到右的时间顺序
    final sortedData = data.reversed.toList();

    // 找出最大值用于 Y 轴
    double maxTotal = 0;
    for (final d in sortedData) {
      final total = (d['total'] as num?)?.toDouble() ?? 0.0;
      if (total > maxTotal) maxTotal = total;
    }
    // 给一点余量
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
                    final month = sortedData[groupIndex]['month'] as String;
                    final total = (rod.toY).toStringAsFixed(1);
                    return BarTooltipItem(
                      '${Helpers.toDisplayMonth(month)}\n¥$total',
                      const TextStyle(color: Colors.white, fontSize: 12),
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
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${parts[1]}月',
                      style: const TextStyle(fontSize: 11),
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
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                return Text(
                  '¥${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: !hideIncome,
          drawVerticalLine: false,
          horizontalInterval: maxTotal / 4,
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
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 构建月度收入详情区域
  Widget _buildMonthSection({
    required String monthKey,
    required List<WorkNote> notes,
    required double monthlyTotal,
    required int workDays,
    required bool hideIncome,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 月份头部
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Helpers.toDisplayMonth(monthKey),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '共$workDays天',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      hideIncome
                          ? '***'
                          : Helpers.formatCurrency(monthlyTotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.incomeGreen,
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

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 日期
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        weekday,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 工作标题
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : '(无标题)',
                      style: TextStyle(
                        fontSize: 14,
                        color: note.title.isNotEmpty
                            ? null
                            : Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 工作时长 & 日工资
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Helpers.formatHours(note.workHours),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

          const Divider(height: 1),
        ],
      ),
    );
  }
}
