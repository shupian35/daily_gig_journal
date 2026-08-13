import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_work_entry_repository.dart';
import '../data/sqlite_work_entry_repository.dart';
import '../data/work_entry_repository.dart';
import '../models/work_entry.dart';
import '../utils/helpers.dart';

/// WorkEntry 持久化接缝的 provider（见 ADR-0006）。
///
/// 默认返回 SqliteWorkEntryRepository；测试可通过 [ProviderScope.overrides]
/// 替换为 [InMemoryWorkEntryRepository]，无需 sqflite_ffi 仪式。
final workEntryRepositoryProvider = Provider<WorkEntryRepository>((ref) {
  return SqliteWorkEntryRepository();
});

/// 有工资记录的笔记列表（用于统计）。
final wageNotesProvider = FutureProvider<List<WorkEntry>>((ref) async {
  return ref.watch(workEntryRepositoryProvider).findAllWithWage();
});

/// 最近 N 个月的月度汇总（用于统计图表）。
final monthlySummaryProvider =
    FutureProvider.family<List<MonthSummary>, int>((ref, months) async {
  return ref.watch(workEntryRepositoryProvider).recentSummary(months: months);
});

/// 有工作安排的日期集合（用于日历标记）。
final workDatesProvider = FutureProvider<Set<DateTime>>((ref) async {
  final dates =
      await ref.watch(workEntryRepositoryProvider).workDates();
  return dates
      .map((d) => Helpers.parseDate(d))
      .where((d) => d != null)
      .map((d) => DateTime(d!.year, d.month, d.day))
      .toSet();
});

/// 当前选中日期（日历交互）。
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 日历聚焦日期。
final focusedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 当前月份的预计总收入。
final monthlyTotalWageProvider = FutureProvider.autoDispose<double>((ref) async {
  final focusedDay = ref.watch(focusedDateProvider);
  final monthKey = Helpers.toMonthKey(focusedDay);
  return ref.watch(workEntryRepositoryProvider).monthlyTotal(monthKey);
});

/// 当前月份的工作天数。
final monthlyWorkDaysProvider = FutureProvider.autoDispose<int>((ref) async {
  final focusedDay = ref.watch(focusedDateProvider);
  final monthKey = Helpers.toMonthKey(focusedDay);
  return ref.watch(workEntryRepositoryProvider).monthlyDays(monthKey);
});

/// 根据日期获取该天所有笔记列表。
final notesByDateListProvider =
    FutureProvider.autoDispose.family<List<WorkEntry>, String>((ref, dateStr) async {
  return ref.watch(workEntryRepositoryProvider).findByDate(dateStr);
});

/// 根据日期范围获取笔记列表（用于本周计划等）。
final notesByDateRangeProvider = FutureProvider.autoDispose
    .family<List<WorkEntry>, ({String start, String end})>((ref, range) async {
  return ref
      .watch(workEntryRepositoryProvider)
      .findByRange(range.start, range.end);
});

// ── Tags ──

/// 当前数据库中所有去重标签（按字母升序）。
final allTagsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(workEntryRepositoryProvider).allTags();
});

/// 含指定标签的笔记列表。
final entriesByTagProvider = FutureProvider.autoDispose
    .family<List<WorkEntry>, String>((ref, tag) async {
  return ref.watch(workEntryRepositoryProvider).findByTag(tag);
});

// ── Search ──

/// 搜索关键词（StateProvider 跨页面共享）。
final searchKeywordProvider = StateProvider<String>((ref) => '');

/// 日期范围筛选，from/to 为空表示该方向不限。
final searchDateRangeProvider =
    StateProvider<({DateTime? from, DateTime? to})>((ref) {
  return (from: null, to: null);
});

/// 单标签筛选；空串表示不限。
final searchTagFilterProvider = StateProvider<String?>((ref) => null);

/// 搜索结果：watch 三个 StateProvider，任一变化重新计算；
/// 任一参数为空且关键词也为空时短路返回空列表。
final searchResultsProvider =
    FutureProvider.autoDispose<List<WorkEntry>>((ref) async {
  final kw = ref.watch(searchKeywordProvider).trim();
  final range = ref.watch(searchDateRangeProvider);
  final tag = ref.watch(searchTagFilterProvider);

  if (kw.isEmpty &&
      range.from == null &&
      range.to == null &&
      (tag == null || tag.isEmpty)) {
    return const <WorkEntry>[];
  }

  final from = range.from == null
      ? null
      : '${range.from!.year.toString().padLeft(4, '0')}-'
          '${range.from!.month.toString().padLeft(2, '0')}-'
          '${range.from!.day.toString().padLeft(2, '0')}';
  final to = range.to == null
      ? null
      : '${range.to!.year.toString().padLeft(4, '0')}-'
          '${range.to!.month.toString().padLeft(2, '0')}-'
          '${range.to!.day.toString().padLeft(2, '0')}';

  return ref.watch(workEntryRepositoryProvider).search(
        keyword: kw.isEmpty ? null : kw,
        dateFrom: from,
        dateTo: to,
        tag: tag,
      );
});

// 注意：save / delete mutation 已迁出到 lib/providers/entry_coordinator.dart。
// 任何写入操作请走 entryCoordinatorProvider，不要再写新的旧式 mutation。
// 派生缓存失效由 WorkEntryRepository.watch() 事件驱动（ADR-0006）；
// ADR-0002 的静态失效清单已被 Superseded。