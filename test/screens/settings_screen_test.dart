import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/screens/settings_screen.dart';

void main() {
  testWidgets('设置项渲染', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar
    expect(find.text('设置'), findsOneWidget);

    // 分区标签
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('隐私'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);

    // 主题选项
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);

    // 导航入口
    expect(find.text('隐私设置'), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.text('云备份 (WebDAV)'), findsOneWidget);
  });
}
