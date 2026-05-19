import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_note.dart';
import '../database/database_helper.dart';
import '../utils/helpers.dart';

/// 数据库帮助类实例（单例）
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// 有工资记录的笔记列表（用于统计）
final wageNotesProvider = FutureProvider<List<WorkNote>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getNotesWithWage();
});

/// 最近N个月的月度汇总（用于统计图表）
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
  return notes.where((n) => n.dailyWage > 0).length;
});

/// 根据日期获取该天所有笔记列表
final notesByDateListProvider =
    FutureProvider.autoDispose.family<List<WorkNote>, String>((ref, dateStr) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getNotesByDateList(dateStr);
});

/// 根据日期范围获取笔记列表（用于本周计划等）
final notesByDateRangeProvider = FutureProvider.autoDispose
    .family<List<WorkNote>, ({String start, String end})>((ref, range) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getNotesByDateRange(range.start, range.end);
});

/// 笔记保存操作（mutation）
/// id 不为 null 则更新，否则插入
final saveNoteProvider = FutureProvider.autoDispose
    .family<void, WorkNote>((ref, note) async {
  final db = ref.watch(databaseHelperProvider);
  if (note.id != null) {
    await db.updateNote(note);
  } else {
    await db.insertNote(note);
  }
  // 使相关缓存失效
  ref.invalidate(workDatesProvider);
  ref.invalidate(wageNotesProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(monthlyTotalWageProvider);
  ref.invalidate(monthlyWorkDaysProvider);
  ref.invalidate(notesByDateListProvider(note.date));
  ref.invalidate(notesByDateRangeProvider);
});

/// 笔记删除操作（mutation）
final deleteNoteProvider =
    FutureProvider.autoDispose.family<void, ({int id, String date})>(
        (ref, params) async {
  final db = ref.watch(databaseHelperProvider);
  await db.deleteNote(params.id);
  // 使相关缓存失效
  ref.invalidate(workDatesProvider);
  ref.invalidate(wageNotesProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(monthlyTotalWageProvider);
  ref.invalidate(monthlyWorkDaysProvider);
  ref.invalidate(notesByDateListProvider(params.date));
  ref.invalidate(notesByDateRangeProvider);
});
