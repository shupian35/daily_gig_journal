import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_entry.dart';
import '../database/database_helper.dart';
import '../utils/helpers.dart';

/// 数据库辅助类实例（单例）
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// 有工资记录的笔记列表（用于统计）
final wageNotesProvider = FutureProvider<List<WorkEntry>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getNotesWithWage();
});

/// 最近 N 个月的月度汇总（用于统计图表）
final monthlySummaryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, months) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getRecentMonthlySummary(months: months);
});

/// 有工作安排的日期集合（用于日历标记）
final workDatesProvider = FutureProvider<Set<DateTime>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  final dates = await db.getWorkDates();
  return dates
      .map((d) => Helpers.parseDate(d))
      .where((d) => d != null)
      .map((d) => DateTime(d!.year, d.month, d.day))
      .toSet();
});

/// 当前选中日期（日历交互）
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 日历聚焦日期
final focusedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 当前月份的预计总收入
final monthlyTotalWageProvider = FutureProvider.autoDispose<double>((ref) async {
  final focusedDay = ref.watch(focusedDateProvider);
  final monthKey = Helpers.toMonthKey(focusedDay);
  final db = ref.watch(databaseHelperProvider);
  return await db.getMonthlyTotalWage(monthKey);
});

/// 当前月份的工作天数
final monthlyWorkDaysProvider = FutureProvider.autoDispose<int>((ref) async {
  final focusedDay = ref.watch(focusedDateProvider);
  final monthKey = Helpers.toMonthKey(focusedDay);
  final db = ref.watch(databaseHelperProvider);
  final notes = await db.getNotesByMonth(monthKey);
  return notes.length;
});

/// 根据日期获取该天所有笔记列表
final notesByDateListProvider =
    FutureProvider.autoDispose.family<List<WorkEntry>, String>((ref, dateStr) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getNotesByDateList(dateStr);
});

/// 根据日期范围获取笔记列表（用于本周计划等）
final notesByDateRangeProvider = FutureProvider.autoDispose
    .family<List<WorkEntry>, ({String start, String end})>((ref, range) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getNotesByDateRange(range.start, range.end);
});

// 注意：save/delete mutation 已迁出到 lib/providers/entry_coordinator.dart。
// 任何写入操作请走 `entryCoordinatorProvider`，不要再加旧式 mutation。
// 历史背景与决策记录见 ADR-0001 / ADR-0002。