import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/screens/settings_screen.dart';

void main() {
  testWidgets('设置项渲染', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar
    expect(find.text('设置'), findsOneWidget);

    // 语言选项（顶部区域，不需要滚动）
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('跟随系统'), findsWidgets);
    expect(find.text('中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);

    // 滚动到可见并检查其余部分
    await tester.scrollUntilVisible(
      find.text('外观'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('隐私'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('隐私'), findsOneWidget);
    expect(find.text('隐私设置'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('数据'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.text('云备份 (WebDAV)'), findsOneWidget);
  });
}
