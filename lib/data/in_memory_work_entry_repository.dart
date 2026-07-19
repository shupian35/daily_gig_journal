import 'dart:async';

import '../models/work_entry.dart';
import 'work_entry_change.dart';
import 'work_entry_repository.dart';

/// WorkEntryRepository 的内存实现，仅供测试使用。
///
/// 不依赖 sqflite / sqflite_common_ffi，可直接构造；测试无需 setUpAll 仪式。
/// [filePath] 返回 sentinel `':memory:'`，不可用于实际文件操作。
class InMemoryWorkEntryRepository implements WorkEntryRepository {
  final Map<int, WorkEntry> _entries = {};
  int _nextId = 1;
  final StreamController<WorkEntryChange> _changes =
      StreamController<WorkEntryChange>.broadcast();

  // ── Read ──

  @override
  Future<List<WorkEntry>> findByDate(String date) async {
    final list = _entries.values.where((e) => e.date == date).toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  @override
  Future<List<WorkEntry>> findByRange(String start, String end) async {
    final list = _entries.values
        .where((e) => e.date.compareTo(start) >= 0 && e.date.compareTo(end) <= 0)
        .toList();
    list.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  @override
  Future<List<WorkEntry>> findByMonth(String month) async {
    final list = _entries.values.where((e) => e.date.startsWith(month)).toList();
    list.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  @override
  Future<List<WorkEntry>> findAllWithWage() async {
    final list = _entries.values.toList();
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  @override
  Future<WorkEntry?> findById(int id) async => _entries[id];

  @override
  Future<List<String>> workDates() async {
    final dates = _entries.values.map((e) => e.date).toSet().toList();
    dates.sort();
    return dates;
  }

  @override
  Future<double> monthlyTotal(String month) async {
    var sum = 0.0;
    for (final e in _entries.values) {
      if (e.date.startsWith(month)) sum += e.dailyWage;
    }
    return sum;
  }

  @override
  Future<int> monthlyDays(String month) async {
    var count = 0;
    for (final e in _entries.values) {
      if (e.date.startsWith(month)) count++;
    }
    return count;
  }

  @override
  Future<List<MonthSummary>> recentSummary({int months = 6}) async {
    final byMonth = <String, List<WorkEntry>>{};
    for (final e in _entries.values) {
      final key = e.date.substring(0, 7);
      byMonth.putIfAbsent(key, () => []).add(e);
    }
    final list = byMonth.entries
        .map((kv) => MonthSummary(
              month: kv.key,
              total: kv.value.fold(0.0, (acc, e) => acc + e.dailyWage),
              workDays: kv.value.length,
            ))
        .toList();
    list.sort((a, b) => b.month.compareTo(a.month));
    return list.take(months).toList();
  }

  // ── Write ──

  @override
  Future<int> add(WorkEntry entry) async {
    if (entry.id != null) {
      throw ArgumentError(
        'add() requires entry.id == null; got ${entry.id}.',
      );
    }
    final id = _nextId++;
    final saved = entry.copyWith(id: id, updatedAt: DateTime.now().toIso8601String());
    _entries[id] = saved;
    _changes.add(Added(id, saved.date));
    return id;
  }

  @override
  Future<void> update(WorkEntry entry) async {
    if (entry.id == null) {
      throw ArgumentError('update() requires entry.id != null; got null.');
    }
    _entries[entry.id!] =
        entry.copyWith(updatedAt: DateTime.now().toIso8601String());
    _changes.add(Edited(entry.id!, entry.date));
  }

  @override
  Future<void> remove(int id) async {
    final existing = _entries.remove(id);
    if (existing != null) {
      _changes.add(Removed(id, existing.date));
    }
  }

  // ── Infra ──

  @override
  Future<String> filePath() async => ':memory:';

  @override
  Stream<WorkEntryChange> watch() => _changes.stream;

  /// 释放 stream 资源。
  Future<void> close() async {
    await _changes.close();
  }
}