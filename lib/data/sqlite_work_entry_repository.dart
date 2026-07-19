import 'dart:async';
import 'dart:io';

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
  static const int _dbVersion = 4;

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
}