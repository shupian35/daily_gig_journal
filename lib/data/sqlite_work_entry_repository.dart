import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/work_entry.dart';
import 'work_entry_change.dart';
import 'work_entry_repository.dart';

/// WorkEntryRepository 的 SQLite 实现。
///
/// 所有 SQL 与表名收拢在此文件，是项目内唯一能见到 `work_notes` 表名的地方。
/// 写方法完成后通过 [StreamController.broadcast] 发出 [WorkEntryChange] 事件。
class SqliteWorkEntryRepository implements WorkEntryRepository {
  // ── Schema 常量（以前散在 DatabaseHelper） ──
  static const String _tableName = 'work_notes';
  static const int _dbVersion = 6;

  static const String _colId = 'id';
  static const String _colDate = 'date';
  static const String _colTitle = 'title';
  static const String _colWorkLocation = 'work_location';
  static const String _colContact = 'contact';
  static const String _colStartTime = 'start_time';
  static const String _colEndTime = 'end_time';
  static const String _colHourlyWage = 'hourly_wage';
  static const String _colWorkHours = 'work_hours';
  static const String _colDailyWage = 'daily_wage';
  static const String _colNoteContent = 'note_content';
  static const String _colTags = 'tags';
  static const String _colCreatedAt = 'created_at';
  static const String _colUpdatedAt = 'updated_at';

  static const String _createTableSQL = """
    CREATE TABLE $_tableName (
      $_colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $_colDate TEXT NOT NULL,
      $_colTitle TEXT DEFAULT '',
      $_colWorkLocation TEXT DEFAULT '',
      $_colContact TEXT DEFAULT '',
      $_colStartTime TEXT DEFAULT '09:00',
      $_colEndTime TEXT DEFAULT '18:00',
      $_colHourlyWage REAL DEFAULT 0.0,
      $_colWorkHours REAL DEFAULT 0.0,
      $_colDailyWage REAL DEFAULT 0.0,
      $_colNoteContent TEXT DEFAULT '[]',
      $_colTags TEXT DEFAULT '',
      $_colCreatedAt TEXT,
      $_colUpdatedAt TEXT
    )
  """;

  // v2 → v3：移除 date UNIQUE 约束需重建表。
  static const String _v3CreateNewTableSQL = """
    CREATE TABLE ${_tableName}_new (
      $_colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $_colDate TEXT NOT NULL,
      $_colTitle TEXT DEFAULT '',
      $_colWorkLocation TEXT DEFAULT '',
      $_colContact TEXT DEFAULT '',
      $_colStartTime TEXT DEFAULT '09:00',
      $_colEndTime TEXT DEFAULT '18:00',
      $_colHourlyWage REAL DEFAULT 0.0,
      $_colWorkHours REAL DEFAULT 0.0,
      $_colDailyWage REAL DEFAULT 0.0,
      $_colNoteContent TEXT DEFAULT '[]',
      $_colTags TEXT DEFAULT '',
      $_colCreatedAt TEXT,
      $_colUpdatedAt TEXT
    )
  """;

  static const String _v3CopySQL =
      'INSERT INTO ${_tableName}_new SELECT * FROM $_tableName';
  static const String _v3DropSQL = 'DROP TABLE $_tableName';
  static const String _v3RenameSQL =
      'ALTER TABLE ${_tableName}_new RENAME TO $_tableName';
  static const String _v3IndexSQL =
      'CREATE INDEX idx_$_colDate ON $_tableName ($_colDate)';

  // ── 单例与初始化 ──
  Database? _db;
  final StreamController<WorkEntryChange> _changes =
      StreamController<WorkEntryChange>.broadcast();

  /// 测试路径覆盖（由测试 setUpAll 注入）。
  static String? _testDbPath;

  static void setTestDbPath(String path) => _testDbPath = path;

  /// 懒加载数据库实例。
  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await filePath();
    final restorePath = '$dbPath.restore';

    // 云端恢复逻辑：从 .restore 文件覆盖当前数据库。
    final restoreFile = File(restorePath);
    if (await restoreFile.exists()) {
      try {
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.copy('$dbPath.bak');
        }
        await restoreFile.copy(dbPath);
        await restoreFile.delete();
      } catch (_) {
        // 恢复失败忽略，用户可手动重试。
      }
    }

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, _) async {
        await db.execute(_createTableSQL);
        await db.execute(_v3IndexSQL);
      },
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE $_tableName ADD COLUMN $_colWorkLocation TEXT DEFAULT ''",
      );
    }
    if (oldVersion < 3) {
      await db.execute(_v3CreateNewTableSQL);
      await db.execute(_v3CopySQL);
      await db.execute(_v3DropSQL);
      await db.execute(_v3RenameSQL);
      await db.execute(_v3IndexSQL);
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE $_tableName ADD COLUMN $_colContact TEXT DEFAULT ''",
      );
    }
    if (oldVersion < 5) {
      // tags：逗号分隔字符串列；老行 tags='' → 反序列化为空列表，零侵入。
      await db.execute(
        "ALTER TABLE $_tableName ADD COLUMN $_colTags TEXT DEFAULT ''",
      );
    }
    if (oldVersion < 6) {
      // ADR-0009：把 note_content 里 image 字段的绝对路径改写为相对名
      // images/<basename>。仅 basename 匹配 generateImageFileName 规则才重写，
      // 第三方手动修改的 JSON 保留原值显示坏图（不强行迁移）。
      await _migrateNoteContentPaths(db);
    }
  }

  /// v5 → v6 一次性迁移：note_content 中 image 字段绝对路径 → 相对名
  /// 仅 basename 匹配 /^img_\d{4}-\d{2}-\d{2}_\d{6}\.png$/ 才重写
  Future<void> _migrateNoteContentPaths(Database db) async {
    final rows = await db.query(_tableName, columns: [_colId, _colNoteContent]);
    for (final row in rows) {
      final id = row[_colId] as int;
      final content = (row[_colNoteContent] as String?) ?? '[]';
      final migrated = _rewriteImagePathsInDelta(content);
      if (migrated != content) {
        await db.update(
          _tableName,
          {_colNoteContent: migrated},
          where: '$_colId = ?',
          whereArgs: [id],
        );
      }
    }
  }

  /// 把 Quill Delta JSON 中 image 字段的绝对路径重写为相对名 `images/<basename>`
  /// 仅 basename 匹配 generateImageFileName 规则才重写，
  /// 第三方手动修改的 JSON 保留原值显示坏图（不强行迁移）。
  /// 返回修改后的 JSON；无变化返回原文
  static String _rewriteImagePathsInDelta(String deltaJson) {
    try {
      final List<dynamic> ops = jsonDecode(deltaJson);
      bool changed = false;
      final whiteList = RegExp(r'^img_\d{4}-\d{2}-\d{2}_\d{6}\.png$');
      for (final op in ops) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is! Map) continue;
        if (!insert.containsKey('image')) continue;
        final v = insert['image'];
        if (v is! String) continue;
        // 已经是相对名 → 跳过
        if (v.startsWith('images/')) continue;
        // 判定为绝对路径
        final isAbsolute = v.contains('/data/') ||
            v.contains('/storage/') ||
            v.contains('/private/var/') ||
            v.contains('/var/mobile/') ||
            v.contains(r'\'); // Windows 绝对路径
        if (!isAbsolute) continue;
        final base = p.basename(v);
        if (!whiteList.hasMatch(base)) continue;
        insert['image'] = 'images/$base';
        changed = true;
      }
      return changed ? jsonEncode(ops) : deltaJson;
    } catch (_) {
      return deltaJson;
    }
  }

  // ── Read ──

  @override
  Future<List<WorkEntry>> findByDate(String date) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: '$_colDate = ?',
      whereArgs: [date],
      orderBy: '$_colStartTime ASC',
    );
    return rows.map(WorkEntry.fromMap).toList();
  }

  @override
  Future<List<WorkEntry>> findByRange(String start, String end) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: '$_colDate >= ? AND $_colDate <= ?',
      whereArgs: [start, end],
      orderBy: '$_colDate ASC, $_colStartTime ASC',
    );
    return rows.map(WorkEntry.fromMap).toList();
  }

  @override
  Future<List<WorkEntry>> findByMonth(String month) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: '$_colDate LIKE ?',
      whereArgs: ['$month%'],
      orderBy: '$_colDate ASC, $_colStartTime ASC',
    );
    return rows.map(WorkEntry.fromMap).toList();
  }

  @override
  Future<List<WorkEntry>> findAllWithWage() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      orderBy: '$_colDate DESC, $_colStartTime ASC',
    );
    return rows.map(WorkEntry.fromMap).toList();
  }

  @override
  Future<WorkEntry?> findById(int id) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: '$_colId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkEntry.fromMap(rows.first);
  }

  @override
  Future<List<String>> workDates() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT $_colDate FROM $_tableName ORDER BY $_colDate ASC',
    );
    return rows.map((row) => row[_colDate] as String).toList();
  }

  @override
  Future<double> monthlyTotal(String month) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT SUM($_colDailyWage) as total FROM $_tableName WHERE $_colDate LIKE ?',
      ['$month%'],
    );
    if (rows.isEmpty || rows.first['total'] == null) return 0.0;
    return (rows.first['total'] as num).toDouble();
  }

  @override
  Future<int> monthlyDays(String month) async {
    final notes = await findByMonth(month);
    return notes.length;
  }

  @override
  Future<List<MonthSummary>> recentSummary({int months = 6}) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT SUBSTR($_colDate, 1, 7) as month,
             SUM($_colDailyWage) as total,
             COUNT(*) as work_days
      FROM $_tableName
      GROUP BY month
      ORDER BY month DESC
      LIMIT ?
    ''', [months]);
    return rows
        .map((r) => MonthSummary(
              month: r['month'] as String,
              total: (r['total'] as num).toDouble(),
              workDays: (r['work_days'] as num).toInt(),
            ))
        .toList();
  }

  // ── Tags ──

  @override
  Future<List<String>> allTags() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      columns: [_colTags],
      where: '$_colTags != ?',
      whereArgs: [''],
    );
    final set = <String>{};
    for (final row in rows) {
      final raw = (row[_colTags] as String?) ?? '';
      if (raw.isEmpty) continue;
      for (final tag in raw.split(',')) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) set.add(trimmed);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Future<List<WorkEntry>> findByTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return const [];
    final db = await _database;
    // 用 `,tag,` 包裹前后逗号避免子串误匹配（"会" 命中 "会展"）。
    // 4 个分支分别覆盖：单 tag / 头 / 尾 / 中。
    final rows = await db.query(
      _tableName,
      where: '$_colTags = ? OR $_colTags LIKE ? OR $_colTags LIKE ? OR $_colTags LIKE ?',
      whereArgs: [
        trimmed,
        '$trimmed,%',
        '%,$trimmed',
        '%,$trimmed,%',
      ],
      orderBy: '$_colDate DESC, $_colStartTime ASC',
    );
    // 二次过滤，确保是独立 tag token 而不是 substring。
    return rows
        .map(WorkEntry.fromMap)
        .where((e) => e.tags.contains(trimmed))
        .toList();
  }

  @override
  Future<int> renameTag({required String from, required String to}) async {
    final fromTrim = from.trim();
    final toTrim = to.trim();
    if (fromTrim.isEmpty || toTrim.isEmpty) return 0;
    if (fromTrim == toTrim) return 0;

    final db = await _database;
    final affected = <WorkEntry>[];
    final replacements = <int, String>{};

    // 1) 找出所有含 from 的 row
    final rows = await db.query(
      _tableName,
      where: '$_colTags = ? OR $_colTags LIKE ? OR $_colTags LIKE ? OR $_colTags LIKE ?',
      whereArgs: [
        fromTrim,
        '$fromTrim,%',
        '%,$fromTrim',
        '%,$fromTrim,%',
      ],
    );

    for (final row in rows) {
      final id = row[_colId] as int?;
      if (id == null) continue;
      final raw = (row[_colTags] as String?) ?? '';
      final list = WorkEntry.parseTags(raw);
      if (!list.contains(fromTrim)) continue;
      final newList = List<String>.from(list);
      final idx = newList.indexOf(fromTrim);
      newList[idx] = toTrim;
      // 去重
      final deduped = <String>[];
      for (final t in newList) {
        if (!deduped.contains(t)) deduped.add(t);
      }
      replacements[id] = deduped.join(',');
      affected.add(WorkEntry.fromMap(row));
    }

    if (replacements.isEmpty) return 0;

    // 2) 单事务写回，失败回滚
    await db.transaction((txn) async {
      for (final entry in replacements.entries) {
        await txn.update(
          _tableName,
          {'tags': entry.value},
          where: '$_colId = ?',
          whereArgs: [entry.key],
        );
      }
    });

    // 3) 触发 Removed/Edited 事件让 watch 链路失效
    for (final e in affected) {
      _changes.add(Edited(e.id!, e.date));
    }

    return replacements.length;
  }

  @override
  Future<int> deleteTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return 0;

    final db = await _database;
    final affected = <WorkEntry>[];
    final replacements = <int, String>{};

    final rows = await db.query(
      _tableName,
      where: '$_colTags = ? OR $_colTags LIKE ? OR $_colTags LIKE ? OR $_colTags LIKE ?',
      whereArgs: [
        trimmed,
        '$trimmed,%',
        '%,$trimmed',
        '%,$trimmed,%',
      ],
    );

    for (final row in rows) {
      final id = row[_colId] as int?;
      if (id == null) continue;
      final raw = (row[_colTags] as String?) ?? '';
      final list = WorkEntry.parseTags(raw);
      if (!list.contains(trimmed)) continue;
      final newList = list.where((t) => t != trimmed).toList();
      replacements[id] = newList.join(',');
      affected.add(WorkEntry.fromMap(row));
    }

    if (replacements.isEmpty) return 0;

    await db.transaction((txn) async {
      for (final entry in replacements.entries) {
        await txn.update(
          _tableName,
          {'tags': entry.value},
          where: '$_colId = ?',
          whereArgs: [entry.key],
        );
      }
    });

    for (final e in affected) {
      _changes.add(Edited(e.id!, e.date));
    }
    return replacements.length;
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

    // 全部为空 → 等同 findAllWithWage，避免无谓 SQL 拼接。
    if (kw.isEmpty && from.isEmpty && to.isEmpty && tagTrim.isEmpty) {
      return findAllWithWage();
    }

    final db = await _database;
    final where = <String>[];
    final args = <Object?>[];

    if (kw.isNotEmpty) {
      // 结构化字段 + noteContent 用 LIKE 在 SQL 层匹配子串；
      // 实现层再二次校验 noteContent 反序列化结果命中，避免 JSON 操作符/嵌入图片误命中。
      where.add(
        '($_colTitle LIKE ? OR $_colWorkLocation LIKE ? OR $_colContact LIKE ? OR $_colNoteContent LIKE ?)',
      );
      final like = '%${_escapeLike(kw)}%';
      args.addAll([like, like, like, like]);
    }
    if (from.isNotEmpty) {
      where.add('$_colDate >= ?');
      args.add(from);
    }
    if (to.isNotEmpty) {
      where.add('$_colDate <= ?');
      args.add(to);
    }
    if (tagTrim.isNotEmpty) {
      // 与 findByTag 一致：包裹逗号做 token 边界匹配。
      where.add(
        '($_colTags = ? OR $_colTags LIKE ? OR $_colTags LIKE ? OR $_colTags LIKE ?)',
      );
      args.addAll([
        tagTrim,
        '$tagTrim,%',
        '%,$tagTrim',
        '%,$tagTrim,%',
      ]);
    }

    final rows = await db.query(
      _tableName,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: '$_colDate DESC, $_colStartTime ASC',
    );

    Iterable<WorkEntry> results = rows.map(WorkEntry.fromMap);

    // keyword：二次过滤 noteContent 的纯文本片段，确保非误命中。
    if (kw.isNotEmpty) {
      final kwLower = kw.toLowerCase();
      results = results.where((e) {
        if (_matchesStruct(e, kwLower)) return true;
        final plain = _deltaToPlainText(e.noteContent).toLowerCase();
        return plain.contains(kwLower);
      });
    }
    // tag：二次过滤独立 token。
    if (tagTrim.isNotEmpty) {
      results = results.where((e) => e.tags.contains(tagTrim));
    }

    return results.toList();
  }

  /// LIKE 子串里需要转义 %, _, \ 三个特殊字符。
  static String _escapeLike(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// 结构化字段命中（[kwLower] 已小写化）。
  static bool _matchesStruct(WorkEntry e, String kwLower) {
    return e.title.toLowerCase().contains(kwLower) ||
        e.workLocation.toLowerCase().contains(kwLower) ||
        e.contact.toLowerCase().contains(kwLower);
  }

  /// Quill Delta JSON → 可读纯文本片段。
  ///
  /// 与 ExportHelper._deltaToPlainText 同款实现；这里独立 copy 是为了
  /// 避免 SearchScreen 依赖 utils/export_helper 的 I/O 路径。
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
        'add() requires entry.id == null; got ${entry.id}. '
        'Use update() for existing entries.',
      );
    }
    final db = await _database;
    final map = entry.toMap();
    final id = await db.insert(_tableName, map);
    _changes.add(Added(id, entry.date));
    return id;
  }

  @override
  Future<void> update(WorkEntry entry) async {
    if (entry.id == null) {
      throw ArgumentError(
        'update() requires entry.id != null; got null. '
        'Use add() for new entries.',
      );
    }
    final db = await _database;
    final map = entry.toMap(forUpdate: true);
    await db.update(
      _tableName,
      map,
      where: '$_colId = ?',
      whereArgs: [entry.id],
    );
    _changes.add(Edited(entry.id!, entry.date));
  }

  @override
  Future<void> remove(int id) async {
    final existing = await findById(id);
    final date = existing?.date;
    final db = await _database;
    await db.delete(_tableName, where: '$_colId = ?', whereArgs: [id]);
    if (date != null) {
      _changes.add(Removed(id, date));
    }
  }

  // ── Infra ──

  @override
  Future<String> filePath() async {
    if (_testDbPath != null) return _testDbPath!;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'daily_gig_journal.db');
  }

  @override
  Stream<WorkEntryChange> watch() => _changes.stream;

  /// 释放底层资源。仅测试使用。
  Future<void> close() async {
    await _changes.close();
    await _db?.close();
    _db = null;
  }

  /// 仅供测试使用：把 Quill Delta JSON 中 image 字段的绝对路径重写为相对名
  /// `images/<basename>`。详见 [_rewriteImagePathsInDelta]。
  @visibleForTesting
  static String debugRewriteImagePathsForTest(String deltaJson) =>
      _rewriteImagePathsInDelta(deltaJson);
}