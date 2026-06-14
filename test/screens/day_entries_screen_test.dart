import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_gig_journal/database/database_helper.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/screens/day_entries_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.resetForTesting();
    final tmpDir = Directory.systemTemp;
    DatabaseHelper.setTestDbPath('${tmpDir.path}/test_daily_gig_entries.db');
  });

  tearDown(() async {
    final db = DatabaseHelper();
    await db.deleteAll();
  });

  testWidgets('空状态 — 无数据时显示提示', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DayEntriesScreen(dateStr: '2025-06-14'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('当天还没有工作安排'), findsOneWidget);
    expect(find.text('点击下方按钮添加工作'), findsOneWidget);
  });

  testWidgets('有数据 — 显示条目卡片', (tester) async {
    final db = DatabaseHelper();
    await db.insertNote(WorkEntry(
      date: '2025-06-14',
      title: '会展协助',
      workLocation: '会展中心',
      startTime: '09:00',
      endTime: '18:00',
      hourlyWage: 25,
      workHours: 9,
      dailyWage: 225,
      noteContent: '[]',
    ));
    await db.insertNote(WorkEntry(
      date: '2025-06-14',
      title: '家教',
      workLocation: '学生家',
      startTime: '14:00',
      endTime: '18:00',
      hourlyWage: 60,
      workHours: 4,
      dailyWage: 240,
      noteContent: '[]',
    ));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DayEntriesScreen(dateStr: '2025-06-14'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // 两张卡片
    expect(find.text('会展协助'), findsOneWidget);
    expect(find.text('家教'), findsOneWidget);
    expect(find.text('¥225'), findsOneWidget);
    expect(find.text('¥240'), findsOneWidget);

    // FAB
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('不同日期互不干扰', (tester) async {
    final db = DatabaseHelper();
    await db.insertNote(WorkEntry.empty('2025-06-14'));
    await db.insertNote(WorkEntry.empty('2025-06-15'));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DayEntriesScreen(dateStr: '2025-06-14'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // 只显示 14 号的 1 条
    expect(find.byType(Card), findsOneWidget);
  });
}
