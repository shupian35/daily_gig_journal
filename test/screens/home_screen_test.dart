import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/main.dart';
import 'package:daily_gig_journal/providers/settings_provider.dart';

void main() {
  testWidgets('默认状态 — 三个 Tab 图标可见', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DailyGigApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // 日历图标
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    // 统计图标（默认 hideStatistics = false）
    expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);
    // 设置图标
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('开启隐藏统计 — 统计 Tab 消失', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hideStatisticsProvider.overrideWith((ref) => true),
        ],
        child: const DailyGigApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // 统计图标不应存在
    expect(find.byIcon(Icons.show_chart_rounded), findsNothing);

    // 日历和设置仍存在
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('关闭隐藏统计 — 统计 Tab 恢复', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hideStatisticsProvider.overrideWith((ref) => false),
        ],
        child: const DailyGigApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);
  });
}
