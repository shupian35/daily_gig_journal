import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_gig_journal/database/database_helper.dart';
import 'package:daily_gig_journal/screens/note_edit_screen.dart';

Widget _buildTestApp(Widget home) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tmpDir = Directory.systemTemp;
    DatabaseHelper.setTestDbPath('${tmpDir.path}/test_daily_gig_edit.db');
  });

  testWidgets('新建模式 — 表单字段和默认值', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(const NoteEditScreen(dateStr: '2025-06-14', noteId: null)),
    );
    await tester.pumpAndSettle();

    // 标题 AppBar
    expect(find.text('2025年6月14日'), findsOneWidget);

    // 表单分区标题
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('工作时间'), findsOneWidget);
    expect(find.text('收入详情'), findsOneWidget);

    // 默认时间（开始和结束都可能有 09:00/18:00）
    expect(find.text('09:00'), findsAtLeast(1));
    expect(find.text('18:00'), findsAtLeast(1));

    // "备注"标题
    expect(find.text('备注'), findsOneWidget);

    // 插入按钮
    expect(find.text('相册图片'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('画板'), findsOneWidget);

    // 保存按钮
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('新建模式最终显示完整表单', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(const NoteEditScreen(dateStr: '2025-06-14', noteId: null)),
    );
    // 等待异步加载完成
    await tester.pump(const Duration(seconds: 3));
    // 加载完成后应显示表单
    expect(find.text('基本信息'), findsOneWidget);
  });
}
