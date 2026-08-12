import '../models/work_entry.dart';
import 'work_entry_change.dart';

/// WorkEntry 持久化的接缝。
///
/// 设计动机与接口宽度取舍见 ADR-0006。约定：
///
/// * 所有日期形参采用 `YYYY-MM-DD` 字符串，与库表 `work_notes.date` 一致；
///   调用方需自行用 [Helpers.formatDate] / [Helpers.parseDate] 转换。
/// * 写方法严格区分 add / update / remove，禁止用 `id == null` 隐式分支；
///   不变式：调用方传给 add 的 entry 必须 `id == null`，update 必须 `id != null`，
///   违反则实现层抛出 [ArgumentError]。
/// * [watch] 是 broadcast stream，事件 dropped if no subscriber；当前
///   [EntryCoordinator] 是唯一订阅者，无 replay 需求。
abstract class WorkEntryRepository {
  // ── Read ──

  /// 返回指定日期的所有 WorkEntry，按 startTime 升序。
  Future<List<WorkEntry>> findByDate(String date);

  /// 返回日期区间 [start, end]（闭区间，YYYY-MM-DD）内的所有 WorkEntry。
  Future<List<WorkEntry>> findByRange(String start, String end);

  /// 返回指定月份的所有 WorkEntry，month 格式 `YYYY-MM`。
  Future<List<WorkEntry>> findByMonth(String month);

  /// 返回全部 WorkEntry（含零工资记录），按 date DESC, startTime ASC。
  Future<List<WorkEntry>> findAllWithWage();

  /// 按 id 查单条；不存在则返回 null。
  Future<WorkEntry?> findById(int id);

  /// 返回有工作安排的日期集合（YYYY-MM-DD），按日期升序。
  Future<List<String>> workDates();

  /// 返回指定月份的预计总工资（sum of dailyWage）。
  Future<double> monthlyTotal(String month);

  /// 返回指定月份有 WorkEntry 的天数（按 entry 条数计，不是去重天数）。
  Future<int> monthlyDays(String month);

  /// 返回最近 [months] 个月的月汇总，按月份降序。
  Future<List<MonthSummary>> recentSummary({int months = 6});

  // ── Write ──

  /// 插入新条目。不变式：[entry] 的 id 必须为 null；返回新生成的 rowid。
  Future<int> add(WorkEntry entry);

  /// 更新已存在条目。不变式：[entry] 的 id 必须非 null。
  Future<void> update(WorkEntry entry);

  /// 按 id 删除。实现层负责先查 date 用于发 Removed 事件。
  Future<void> remove(int id);

  // ── Infra ──

  /// 当前持久化文件的 OS 路径，用于 WebDAV 备份 / 恢复。
  Future<String> filePath();

  /// 写操作完成后发出的变更流。
  Stream<WorkEntryChange> watch();
}

/// `recentSummary` 的结构化返回，避免 `List<Map<String, dynamic>>` 的弱类型。
class MonthSummary {
  final String month;
  final double total;
  final int workDays;
  const MonthSummary({
    required this.month,
    required this.total,
    required this.workDays,
  });
}