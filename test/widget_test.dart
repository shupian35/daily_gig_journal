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
    await tester.pump(const Duration(seconds: 2));

    // 验证导航图标存在（日历 Tab 始终可见）
    expect(find.byIcon(Icons.calendar_today_rounded), findsWidgets);
    expect(find.byIcon(Icons.show_chart_rounded), findsWidgets);
    expect(find.byIcon(Icons.tune_rounded), findsWidgets);
  });
}
