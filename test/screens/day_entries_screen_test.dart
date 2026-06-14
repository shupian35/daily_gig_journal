import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/providers/notes_provider.dart';
import 'package:daily_gig_journal/screens/day_entries_screen.dart';

void main() {
  testWidgets('空状态 — 无数据时显示提示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesByDateListProvider('2025-06-14').overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: DayEntriesScreen(dateStr: '2025-06-14'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('当天还没有工作安排'), findsOneWidget);
  });

  testWidgets('有数据 — 显示条目卡片', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesByDateListProvider('2025-06-14').overrideWith((ref) => [
            WorkEntry(
              date: '2025-06-14',
              title: '会展协助',
              workLocation: '会展中心',
              startTime: '09:00', endTime: '18:00',
              hourlyWage: 25, workHours: 9, dailyWage: 225,
              noteContent: '[]',
            ),
            WorkEntry(
              date: '2025-06-14',
              title: '家教',
              workLocation: '学生家',
              startTime: '14:00', endTime: '18:00',
              hourlyWage: 60, workHours: 4, dailyWage: 240,
              noteContent: '[]',
            ),
          ]),
        ],
        child: const MaterialApp(
          home: DayEntriesScreen(dateStr: '2025-06-14'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('会展协助'), findsOneWidget);
    expect(find.text('家教'), findsOneWidget);
    expect(find.text('¥225'), findsOneWidget);
    expect(find.text('¥240'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
