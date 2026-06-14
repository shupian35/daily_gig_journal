import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:daily_gig_journal/screens/calendar_screen.dart';

void main() {
  setUpAll(() {
    initializeDateFormatting('zh_CN', null);
  });

  testWidgets('日历和摘要渲染', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CalendarScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // AppBar
    expect(find.text('日程清单'), findsOneWidget);

    // FAB
    expect(find.text('添加今日工作'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // "回到今天"按钮
    expect(find.byIcon(Icons.today_rounded), findsOneWidget);

    // 未来一周区域（有数据时显示"未来一周"，无数据时显示空状态）
    final hasWeekPlan = find.text('未来一周').evaluate().isNotEmpty;
    final hasEmptyPlan = find.text('未来一周暂无工作安排').evaluate().isNotEmpty;
    expect(hasWeekPlan || hasEmptyPlan, true);
  });
}
