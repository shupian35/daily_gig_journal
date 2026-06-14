import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/screens/webdav_backup_screen.dart';

void main() {
  testWidgets('配置表单渲染', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WebDavBackupScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // AppBar
    expect(find.text('云备份'), findsOneWidget);

    // 服务器配置区（首屏可见）
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('测试连接'), findsOneWidget);

    // 操作区
    expect(find.text('操作'), findsOneWidget);

    // 自动备份
    expect(find.text('保存/删除时自动备份'), findsOneWidget);
  });
}
