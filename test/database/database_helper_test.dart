import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_gig_journal/database/database_helper.dart';
import 'package:daily_gig_journal/models/work_entry.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 使用临时文件作为测试数据库
    final tmpDir = Directory.systemTemp;
    DatabaseHelper.setTestDbPath('${tmpDir.path}/test_daily_gig.db');
  });

  tearDownAll(() {
    // 数据库文件可能仍被锁定，忽略清理失败
    try {
      final dbFile = File('${Directory.systemTemp.path}/test_daily_gig.db');
      if (dbFile.existsSync()) dbFile.deleteSync();
    } catch (_) {}
  });

  group('DatabaseHelper CRUD', () {
    late DatabaseHelper db;

    setUp(() async {
      db = DatabaseHelper();
      await db.deleteAll(); // 清空测试数据
    });

    test('insertNote 插入并返回 id', () async {
      final entry = WorkEntry(
        date: '2025-06-14',
        title: '测试工作',
        workLocation: '测试地点',
        startTime: '09:00',
        endTime: '18:00',
        hourlyWage: 30.0,
        workHours: 9.0,
        dailyWage: 270.0,
        noteContent: '[]',
      );

      final id = await db.insertNote(entry);
      expect(id, greaterThan(0));
    });

    test('getNoteById 查询单条', () async {
      final entry = WorkEntry.empty('2025-06-14');
      final id = await db.insertNote(entry);
      final fetched = await db.getNoteById(id);

      expect(fetched, isNotNull);
      expect(fetched!.id, id);
      expect(fetched.date, '2025-06-14');
    });

    test('updateNote 更新记录', () async {
      final entry = WorkEntry(
        date: '2025-06-14',
        title: '旧标题',
        workLocation: '',
        startTime: '09:00',
        endTime: '18:00',
        hourlyWage: 0,
        workHours: 0,
        dailyWage: 0,
        noteContent: '[]',
      );
      final id = await db.insertNote(entry);
      final updated = entry.copyWith(id: id, title: '新标题');
      await db.updateNote(updated);

      final fetched = await db.getNoteById(id);
      expect(fetched!.title, '新标题');
    });

    test('deleteNote 删除记录', () async {
      final entry = WorkEntry.empty('2025-06-14');
      final id = await db.insertNote(entry);
      await db.deleteNote(id);

      final fetched = await db.getNoteById(id);
      expect(fetched, isNull);
    });

    test('getNotesByDateList 按日期查询并按开始时间排序', () async {
      await db.insertNote(WorkEntry(
        date: '2025-06-14',
        title: '下午班',
        workLocation: '',
        startTime: '14:00', endTime: '18:00',
        hourlyWage: 0, workHours: 0, dailyWage: 0, noteContent: '[]',
      ));
      await db.insertNote(WorkEntry(
        date: '2025-06-14',
        title: '上午班',
        workLocation: '',
        startTime: '08:00', endTime: '12:00',
        hourlyWage: 0, workHours: 0, dailyWage: 0, noteContent: '[]',
      ));

      final list = await db.getNotesByDateList('2025-06-14');
      expect(list.length, 2);
      expect(list.first.title, '上午班'); // 先开始的在前面
    });

    test('一天可有多条记录', () async {
      await db.insertNote(WorkEntry.empty('2025-06-14'));
      await db.insertNote(WorkEntry.empty('2025-06-14'));
      await db.insertNote(WorkEntry.empty('2025-06-14'));

      final list = await db.getNotesByDateList('2025-06-14');
      expect(list.length, 3);
    });

    test('getWorkDates 返回去重日期列表', () async {
      await db.insertNote(WorkEntry.empty('2025-06-14'));
      await db.insertNote(WorkEntry.empty('2025-06-14'));
      await db.insertNote(WorkEntry.empty('2025-06-15'));

      final dates = await db.getWorkDates();
      expect(dates.length, 2);
      expect(dates, contains('2025-06-14'));
      expect(dates, contains('2025-06-15'));
    });

    test('getMonthlyTotalWage 计算月收入', () async {
      await db.insertNote(WorkEntry(
        date: '2025-06-14',
        title: '', workLocation: '',
        startTime: '09:00', endTime: '18:00',
        hourlyWage: 0, workHours: 0, dailyWage: 200.0, noteContent: '[]',
      ));
      await db.insertNote(WorkEntry(
        date: '2025-06-15',
        title: '', workLocation: '',
        startTime: '09:00', endTime: '18:00',
        hourlyWage: 0, workHours: 0, dailyWage: 300.0, noteContent: '[]',
      ));

      final total = await db.getMonthlyTotalWage('2025-06');
      expect(total, 500.0);
    });

    test('getRecentMonthlySummary 按月分组', () async {
      await db.insertNote(WorkEntry(
        date: '2025-06-14',
        title: '', workLocation: '',
        startTime: '09:00', endTime: '18:00',
        hourlyWage: 0, workHours: 0, dailyWage: 100.0, noteContent: '[]',
      ));
      await db.insertNote(WorkEntry(
        date: '2025-06-15',
        title: '', workLocation: '',
        startTime: '09:00', endTime: '18:00',
        hourlyWage: 0, workHours: 0, dailyWage: 200.0, noteContent: '[]',
      ));

      final summary = await db.getRecentMonthlySummary(months: 6);
      final june = summary.firstWhere((s) => s['month'] == '2025-06');
      expect(june['total'], 300.0);
    });

    test('getNotesByDateRange 日期范围查询', () async {
      await db.insertNote(WorkEntry.empty('2025-06-10'));
      await db.insertNote(WorkEntry.empty('2025-06-14'));
      await db.insertNote(WorkEntry.empty('2025-06-20'));

      final range = await db.getNotesByDateRange('2025-06-12', '2025-06-18');
      expect(range.length, 1);
      expect(range.first.date, '2025-06-14');
    });

    test('getNotesWithWage 只返回有日工资的记录', () async {
      await db.insertNote(WorkEntry(
        date: '2025-06-14',
        title: '', workLocation: '',
        startTime: '09:00', endTime: '18:00',
        hourlyWage: 0, workHours: 0, dailyWage: 0.0, noteContent: '[]',
      ));
      await db.insertNote(WorkEntry(
        date: '2025-06-15',
        title: '', workLocation: '',
        startTime: '09:00', endTime: '18:00',
        hourlyWage: 0, workHours: 0, dailyWage: 300.0, noteContent: '[]',
      ));

      final withWage = await db.getNotesWithWage();
      expect(withWage.length, 1);
      expect(withWage.first.dailyWage, 300.0);
    });
  });
}
