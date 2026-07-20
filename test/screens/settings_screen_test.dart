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
    expect(find.text('\u8bed\u8a00'), findsWidgets);
    expect(find.text('跟随系统'), findsWidgets);
    // Language is now a nav tile (subpage)


    // 滚动到可见并检查其余部分
    await tester.scrollUntilVisible(
      find.text('外观').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('\u5916\u89c2'), findsWidgets);
    // Theme is now a nav tile (subpage), not a dropdown


    await tester.scrollUntilVisible(
      find.text('隐私').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('隐私').first, findsOneWidget);
    expect(find.text('隐私设置'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('数据').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('数据').first, findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.text('云备份 (WebDAV)'), findsOneWidget);
  });
}
