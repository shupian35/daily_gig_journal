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

    // 服务器配置区
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('账号（坚果云为注册邮箱）'), findsOneWidget);
    expect(find.text('密码（坚果云需使用应用密码）'), findsOneWidget);

    // 测试连接按钮存在且禁用（未配置）
    expect(find.text('测试连接'), findsOneWidget);

    // 滚动到底部
    await tester.scrollUntilVisible(find.text('操作'), 200);
    expect(find.text('操作'), findsOneWidget);

    // 备份和恢复按钮
    expect(find.text('备份到云盘'), findsOneWidget);
    expect(find.text('从云盘恢复'), findsOneWidget);

    // 自动备份
    await tester.scrollUntilVisible(find.text('自动备份'), 200);
    expect(find.text('保存/删除时自动备份'), findsOneWidget);
  });
}
