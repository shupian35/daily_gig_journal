import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/work_note.dart';

/// 数据库帮助类 —— 单例模式
/// 负责 SQLite 数据库的初始化、增删改查操作
class DatabaseHelper {
  // 单例实例
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // 数据库实例（懒加载）
  static Database? _database;

  // 数据库名称与版本
  static const String _dbName = 'daily_gig_journal.db';
  static const int _dbVersion = 3;

  // 表名与字段常量
  static const String tableName = 'work_notes';
  static const String colId = 'id';
  static const String colDate = 'date';
  static const String colTitle = 'title';
  static const String colWorkLocation = 'work_location';
  static const String colStartTime = 'start_time';
  static const String colEndTime = 'end_time';
  static const String colHourlyWage = 'hourly_wage';
  static const String colWorkHours = 'work_hours';
  static const String colDailyWage = 'daily_wage';
  static const String colNoteContent = 'note_content';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  /// 获取数据库实例（懒加载，首次访问时初始化）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 获取数据库文件路径（用于备份恢复）
  static Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbName);
  }

  /// 初始化数据库：创建文件路径并建表
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasePath();

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 建表 SQL（date 不设 UNIQUE，允许一天多条记录）
  String get _createTableSQL => '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colDate TEXT NOT NULL,
      $colTitle TEXT DEFAULT '',
      $colWorkLocation TEXT DEFAULT '',
      $colStartTime TEXT DEFAULT '09:00',
      $colEndTime TEXT DEFAULT '18:00',
      $colHourlyWage REAL DEFAULT 0.0,
      $colWorkHours REAL DEFAULT 0.0,
      $colDailyWage REAL DEFAULT 0.0,
      $colNoteContent TEXT DEFAULT '[]',
      $colCreatedAt TEXT,
      $colUpdatedAt TEXT
    )
  ''';

  /// 首次创建数据库时建表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createTableSQL);
    // 为日期字段创建索引，加快按日期查询速度
    await db.execute(
      'CREATE INDEX idx_$colDate ON $tableName ($colDate)',
    );
  }

  /// 数据库升级回调
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2: 添加 work_location 字段
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $colWorkLocation TEXT DEFAULT \'\'',
      );
    }
    if (oldVersion < 3) {
      // v2 -> v3: 移除 date 的 UNIQUE 约束（SQLite 需要重建表）
      await db.execute('''
        CREATE TABLE ${tableName}_new (
          $colId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colDate TEXT NOT NULL,
          $colTitle TEXT DEFAULT '',
          $colWorkLocation TEXT DEFAULT '',
          $colStartTime TEXT DEFAULT '09:00',
          $colEndTime TEXT DEFAULT '18:00',
          $colHourlyWage REAL DEFAULT 0.0,
          $colWorkHours REAL DEFAULT 0.0,
          $colDailyWage REAL DEFAULT 0.0,
          $colNoteContent TEXT DEFAULT '[]',
          $colCreatedAt TEXT,
          $colUpdatedAt TEXT
        )
      ''');
      await db.execute(
        'INSERT INTO ${tableName}_new SELECT * FROM $tableName',
      );
      await db.execute('DROP TABLE $tableName');
      await db.execute('ALTER TABLE ${tableName}_new RENAME TO $tableName');
      await db.execute(
        'CREATE INDEX idx_$colDate ON $tableName ($colDate)',
      );
    }
  }

  // ===================== CRUD 操作 =====================

  /// 插入一条新笔记
  /// 返回插入行的 id
  Future<int> insertNote(WorkNote note) async {
    try {
      final db = await database;
      final id = await db.insert(
        tableName,
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return id;
    } catch (e) {
      throw Exception('插入笔记失败: $e');
    }
  }

  /// 根据 id 更新笔记
  /// 返回受影响的行数
  Future<int> updateNote(WorkNote note) async {
    try {
      final db = await database;
      final rows = await db.update(
        tableName,
        note.toMap(forUpdate: true),
        where: '$colId = ?',
        whereArgs: [note.id],
      );
      return rows;
    } catch (e) {
      throw Exception('更新笔记失败: $e');
    }
  }

  /// 删除笔记
  /// 返回受影响的行数
  Future<int> deleteNote(int id) async {
    try {
      final db = await database;
      final rows = await db.delete(
        tableName,
        where: '$colId = ?',
        whereArgs: [id],
      );
      return rows;
    } catch (e) {
      throw Exception('删除笔记失败: $e');
    }
  }

  /// 根据日期获取该天所有笔记列表
  Future<List<WorkNote>> getNotesByDateList(String date) async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        where: '$colDate = ?',
        whereArgs: [date],
        orderBy: '$colStartTime ASC',
      );
      return results.map((map) => WorkNote.fromMap(map)).toList();
    } catch (e) {
      throw Exception('查询笔记列表失败: $e');
    }
  }

  /// 根据 id 获取笔记
  Future<WorkNote?> getNoteById(int id) async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        where: '$colId = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return WorkNote.fromMap(results.first);
    } catch (e) {
      throw Exception('查询笔记失败: $e');
    }
  }

  /// 获取所有笔记，按日期降序排列
  Future<List<WorkNote>> getAllNotes() async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        orderBy: '$colDate DESC, $colStartTime ASC',
      );
      return results.map((map) => WorkNote.fromMap(map)).toList();
    } catch (e) {
      throw Exception('查询所有笔记失败: $e');
    }
  }

  /// 获取指定月份的所有笔记
  /// month 格式为 YYYY-MM（如 "2025-03"）
  Future<List<WorkNote>> getNotesByMonth(String month) async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        where: '$colDate LIKE ?',
        whereArgs: ['$month%'],
        orderBy: '$colDate ASC, $colStartTime ASC',
      );
      return results.map((map) => WorkNote.fromMap(map)).toList();
    } catch (e) {
      throw Exception('查询月度笔记失败: $e');
    }
  }

  /// 获取有工作安排的日期列表（用于日历标记，去重）
  /// 返回日期字符串列表
  Future<List<String>> getWorkDates() async {
    try {
      final db = await database;
      final results = await db.rawQuery(
        'SELECT DISTINCT $colDate FROM $tableName ORDER BY $colDate ASC',
      );
      return results.map((row) => row[colDate] as String).toList();
    } catch (e) {
      throw Exception('查询工作日期失败: $e');
    }
  }

  /// 获取日期范围内的所有笔记
  Future<List<WorkNote>> getNotesByDateRange(String startDate, String endDate) async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        where: '$colDate >= ? AND $colDate <= ?',
        whereArgs: [startDate, endDate],
        orderBy: '$colDate ASC, $colStartTime ASC',
      );
      return results.map((map) => WorkNote.fromMap(map)).toList();
    } catch (e) {
      throw Exception('查询日期范围笔记失败: $e');
    }
  }

  /// 获取有日工资记录的笔记（用于统计页）
  /// 即 daily_wage > 0 的记录
  Future<List<WorkNote>> getNotesWithWage() async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        where: '$colDailyWage > 0',
        orderBy: '$colDate DESC, $colStartTime ASC',
      );
      return results.map((map) => WorkNote.fromMap(map)).toList();
    } catch (e) {
      throw Exception('查询有薪笔记失败: $e');
    }
  }

  /// 计算指定月份的预计总收入
  Future<double> getMonthlyTotalWage(String month) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT SUM($colDailyWage) as total FROM $tableName WHERE $colDate LIKE ?',
        ['$month%'],
      );
      if (result.isEmpty || result.first['total'] == null) return 0.0;
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      throw Exception('计算月度总收入失败: $e');
    }
  }

  /// 获取最近 N 个月的月收入汇总
  /// 返回 List<Map>，每项包含 'month' 和 'total'
  Future<List<Map<String, dynamic>>> getRecentMonthlySummary({int months = 6}) async {
    try {
      final db = await database;
      // 按月份分组统计日工资总和
      final results = await db.rawQuery('''
        SELECT SUBSTR($colDate, 1, 7) as month, 
               SUM($colDailyWage) as total,
               COUNT(*) as work_days
        FROM $tableName 
        WHERE $colDailyWage > 0
        GROUP BY month 
        ORDER BY month DESC 
        LIMIT ?
      ''', [months]);
      return results;
    } catch (e) {
      throw Exception('查询月度汇总失败: $e');
    }
  }

  /// 清空所有数据（用于测试或重置）
  Future<void> deleteAll() async {
    final db = await database;
    await db.delete(tableName);
  }
}
