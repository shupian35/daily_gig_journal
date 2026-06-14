import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_gig_journal/database/database_helper.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/screens/statistics_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tmpDir = Directory.systemTemp;
    DatabaseHelper.setTestDbPath('${tmpDir.path}/test_daily_gig_stats.db');
  });

  tearDown(() async {
    final db = DatabaseHelper();
    await db.deleteAll();
  });

  testWidgets('无数据 — 显示空状态', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StatisticsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('还没有工资记录'), findsOneWidget);
  });

  testWidgets('有数据 — 显示图表和列表', (tester) async {
    final db = DatabaseHelper();
    await db.insertNote(WorkEntry(
      date: '2025-06-14',
      title: '测试工作',
      workLocation: '',
      startTime: '09:00', endTime: '18:00',
      hourlyWage: 30, workHours: 9, dailyWage: 270,
      noteContent: '[]',
    ));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StatisticsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // 图表标题
    expect(find.text('近6个月收入趋势'), findsOneWidget);
    // 月度详情
    expect(find.text('2025年6月'), findsOneWidget);
  });
}
