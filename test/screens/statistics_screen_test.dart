import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/providers/notes_provider.dart';
import 'package:daily_gig_journal/screens/statistics_screen.dart';

void main() {
  testWidgets('无数据 — 显示空状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wageNotesProvider.overrideWith((ref) => []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const StatisticsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('还没有工资记录'), findsOneWidget);
  });

  testWidgets('有数据 — 显示图表和列表', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wageNotesProvider.overrideWith((ref) => [
            WorkEntry(
              date: '2025-06-14',
              title: '测试工作',
              workLocation: '', contact: '',
              startTime: '09:00', endTime: '18:00',
              hourlyWage: 30, workHours: 9, dailyWage: 270,
              noteContent: '[]',
            ),
          ]),
          monthlySummaryProvider(6).overrideWith((ref) => [
            {'month': '2025-06', 'total': 270.0, 'work_days': 1},
          ]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const StatisticsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('近6个月收入趋势'), findsOneWidget);
    expect(find.text('2025年6月'), findsOneWidget);
  });
}
