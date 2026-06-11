import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:daily_gig_journal/main.dart';

void main() {
  testWidgets('App should render home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DailyGigApp(),
      ),
    );

    // 验证默认选中「日历」标签可见
    expect(find.text('日历'), findsOneWidget);

    // 新导航栏：未选中项只显示图标，不显示文字
    // 验证导航图标存在
    expect(find.byIcon(Icons.calendar_today_rounded), findsWidgets);
    expect(find.byIcon(Icons.show_chart_rounded), findsWidgets);
    expect(find.byIcon(Icons.tune_rounded), findsWidgets);
  });
}
