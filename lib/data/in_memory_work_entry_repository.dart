import 'dart:async';
import 'dart:convert';

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

  // ── Tags ──

  @override
  Future<List<String>> allTags() async {
    final set = <String>{};
    for (final e in _entries.values) {
      for (final t in e.tags) {
        set.add(t);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Future<List<WorkEntry>> findByTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return const [];
    final list = _entries.values
        .where((e) => e.tags.contains(trimmed))
        .toList();
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  @override
  Future<int> renameTag({required String from, required String to}) async {
    final fromTrim = from.trim();
    final toTrim = to.trim();
    if (fromTrim.isEmpty || toTrim.isEmpty || fromTrim == toTrim) return 0;
    var changed = 0;
    final updates = <int, WorkEntry>{};
    for (final entry in _entries.values) {
      if (!entry.tags.contains(fromTrim)) continue;
      final newTags = List<String>.from(entry.tags);
      final idx = newTags.indexOf(fromTrim);
      newTags[idx] = toTrim;
      // 去重
      final deduped = <String>[];
      for (final t in newTags) {
        if (!deduped.contains(t)) deduped.add(t);
      }
      updates[entry.id!] =
          entry.copyWith(tags: deduped, updatedAt: DateTime.now().toIso8601String());
      changed++;
    }
    if (updates.isEmpty) return 0;
    _entries.addAll(updates);
    for (final entry in updates.values) {
      _changes.add(Edited(entry.id!, entry.date));
    }
    return changed;
  }

  @override
  Future<int> deleteTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return 0;
    var changed = 0;
    final updates = <int, WorkEntry>{};
    for (final entry in _entries.values) {
      if (!entry.tags.contains(trimmed)) continue;
      final newTags = entry.tags.where((t) => t != trimmed).toList();
      updates[entry.id!] =
          entry.copyWith(tags: newTags, updatedAt: DateTime.now().toIso8601String());
      changed++;
    }
    if (updates.isEmpty) return 0;
    _entries.addAll(updates);
    for (final entry in updates.values) {
      _changes.add(Edited(entry.id!, entry.date));
    }
    return changed;
  }

  @override
  Future<int> mergeTag({required String from, required String to}) =>
      renameTag(from: from, to: to);

  // ── Search ──

  @override
  Future<List<WorkEntry>> search({
    String? keyword,
    String? dateFrom,
    String? dateTo,
    String? tag,
  }) async {
    final kw = (keyword ?? '').trim();
    final from = (dateFrom ?? '').trim();
    final to = (dateTo ?? '').trim();
    final tagTrim = (tag ?? '').trim();

    if (kw.isEmpty && from.isEmpty && to.isEmpty && tagTrim.isEmpty) {
      return findAllWithWage();
    }

    final kwLower = kw.toLowerCase();
    final list = _entries.values.where((e) {
      if (from.isNotEmpty && e.date.compareTo(from) < 0) return false;
      if (to.isNotEmpty && e.date.compareTo(to) > 0) return false;
      if (tagTrim.isNotEmpty && !e.tags.contains(tagTrim)) return false;
      if (kwLower.isNotEmpty) {
        final structHit = e.title.toLowerCase().contains(kwLower) ||
            e.workLocation.toLowerCase().contains(kwLower) ||
            e.contact.toLowerCase().contains(kwLower);
        final plainHit =
            _deltaToPlainText(e.noteContent).toLowerCase().contains(kwLower);
        if (!structHit && !plainHit) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  /// 与 SqliteWorkEntryRepository._deltaToPlainText 同款实现；两份代码靠测试对齐。
  static String _deltaToPlainText(String deltaJson) {
    if (deltaJson.isEmpty) return '';
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is! List) return '';
      final buf = StringBuffer();
      for (final op in decoded) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is String) {
          buf.write(insert);
        } else if (insert is Map) {
          // 嵌入对象（图片等）跳过。
        }
      }
      return buf.toString();
    } catch (_) {
      return '';
    }
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