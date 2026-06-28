import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/screens/webdav_backup_screen.dart';

void main() {
  testWidgets('配置表单渲染', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const WebDavBackupScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // AppBar
    expect(find.text('云备份'), findsOneWidget);

    // 首屏表单（保证在 viewport 内）
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('测试连接'), findsOneWidget);
  });
}
