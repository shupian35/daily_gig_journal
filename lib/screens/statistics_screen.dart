import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_localizations.dart';
import '../models/work_entry.dart';
import '../data/work_entry_repository.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import 'day_entries_screen.dart';

/// 工资统计页 —— 精致杂志风
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  String? _selectedTag; // null = 全部

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wageNotesAsync = ref.watch(wageNotesProvider);
    final monthlySummaryAsync = ref.watch(monthlySummaryProvider(6));
    final hideStatistics = ref.watch(hideStatisticsProvider);
    final hideIncome = ref.watch(hideIncomeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wageStatistics),
      ),
      body: wageNotesAsync.when(
        data: (notes) {
          if (hideStatistics) {
            return _buildPrivacyProtectedState(context);
          }
          if (notes.isEmpty) {
            return _buildEmptyState(context);
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
              Text('${l10n.loadFailed}: $err',
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
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyProtectedState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Text(
            l10n.statsHidden,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.statsHiddenHint,
            style: TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Text(
            l10n.noWageRecords,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noWageRecordsSubtitle,
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
    List<WorkEntry> notes,
    AsyncValue<List<MonthSummary>> monthlySummaryAsync,
    bool hideIncome,
  ) {
    // 应用当前 tag 筛选。null = 全部。
    final filtered = _selectedTag == null
        ? notes
        : notes.where((n) => n.tags.contains(_selectedTag)).toList();
    final grouped = _groupByMonth(filtered);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTagFilterBar(),
                      _buildBarChart(context, monthlySummaryAsync, hideIncome),
                    ],
                  ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildTagFilterBar(),
              ),
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

  Map<String, List<WorkEntry>> _groupByMonth(List<WorkEntry> notes) {
    final map = <String, List<WorkEntry>>{};
    for (final note in notes) {
      final monthKey = note.date.substring(0, 7);
      map.putIfAbsent(monthKey, () => []).add(note);
    }
    return map;
  }

  /// 横滑 chip 行：点击切到对应 tag，仅展示该 tag 条目。
  Widget _buildTagFilterBar() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTagsAsync = ref.watch(allTagsProvider);
    return allTagsAsync.maybeWhen(
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.tagsStatisticsByTag,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppConstants.textSecondaryDark
                        : AppConstants.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: tags.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final selected = _selectedTag == null;
                      return _FilterChipPill(
                        label: l10n.searchAllTimeFilter,
                        selected: selected,
                        onTap: () => setState(() => _selectedTag = null),
                      );
                    }
                    final tag = tags[i - 1];
                    final selected = _selectedTag == tag;
                    return _FilterChipPill(
                      label: tag,
                      selected: selected,
                      onTap: () => setState(() => _selectedTag = tag),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildBarChart(BuildContext context,
      AsyncValue<List<MonthSummary>> async, bool hideIncome) {
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.recent6MonthsTrend,
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
                    return Center(
                      child: Text(l10n.noData,
                          style: const TextStyle(color: AppConstants.textSecondary)),
                    );
                  }
                  return _buildFlBarChart(context, data, hideIncome);
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, _) => Center(
                  child: Text(l10n.loadFailed,
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

  Widget _buildFlBarChart(BuildContext context, List<MonthSummary> data, bool hideIncome) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final sortedData = data.reversed.toList();
    if (sortedData.isEmpty) {
      return Center(child: Text(l10n.noData));
    }

    double maxTotal = 0;
    for (final d in sortedData) {
      final total = d.total;
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
                        sortedData[groupIndex].month;
                    final total = (rod.toY).toStringAsFixed(1);
                    return BarTooltipItem(
                      '${Helpers.toDisplayMonth(month, locale)}\n¥$total',
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
                  final month = sortedData[index].month;
                  final parts = month.split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      locale == 'en' ? '${parts[1]}' : '${parts[1]}月',
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
          final total = d.total;
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
    required List<WorkEntry> notes,
    required double monthlyTotal,
    required int workDays,
    required bool hideIncome,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
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
                  Helpers.toDisplayMonth(monthKey, locale),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      l10n.workCount(workDays),
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
                          : Helpers.formatCurrency(monthlyTotal, locale),
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
            final displayDate = Helpers.toDisplayDate(note.date, locale);
            final date = Helpers.parseDate(note.date);
            final weekday = date != null ? Helpers.getWeekday(date, locale) : '';

            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DayEntriesScreen(dateStr: note.date),
                  ),
                );
              },
              child: Container(
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
                        note.title.isNotEmpty ? note.title : l10n.noTitle,
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
                              : Helpers.formatCurrency(note.dailyWage, locale),
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
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// 统计页 tag 筛选条所用的胶囊按钮。
class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppConstants.primaryColor.withValues(alpha: isDark ? 0.24 : 0.16)
              : (isDark ? const Color(0xFF262630) : Colors.white),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(
            color: selected
                ? AppConstants.primaryColor
                : (isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2)),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppConstants.primaryDark
                : (isDark
                    ? AppConstants.textPrimaryDark
                    : AppConstants.textPrimary),
          ),
        ),
      ),
    );
  }
}
