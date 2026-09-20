import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daily_gig_journal/data/sqlite_work_entry_repository.dart';
import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/providers/notes_provider.dart';
import 'package:daily_gig_journal/screens/note_edit_screen.dart';

String _kTestDbPath() =>
    '${Directory.systemTemp.path}/test_note_edit_screen.db';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteWorkEntryRepository.setTestDbPath(_kTestDbPath());
  });

  tearDownAll(() {
    final file = File(_kTestDbPath());
    if (file.existsSync()) {
      try { file.deleteSync(); } catch (_) {}
    }
  });

  /// 备注 Quill 编辑器上方那一组 EditableText 依次是：
  /// 工作标题 / 工作地点 / 联系人 / 时薪 / 工作时长 / 日薪。
  /// 第一个就是"工作标题"，对应 _titleController。
  EditableText _findTitleEditable(WidgetTester tester) {
    final editables = find.byType(EditableText);
    expect(editables, findsWidgets);
    return tester.widget<EditableText>(editables.first);
  }

  group('NoteEditScreen', () {
    testWidgets('新建模式 — 屏幕正常渲染', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [...AppLocalizations.localizationsDelegates, FlutterQuillLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: NoteEditScreen(dateStr: '2025-06-14'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 屏幕渲染完成且无异常即视为通过
      expect(tester.takeException(), isNull);
      expect(find.byType(NoteEditScreen), findsOneWidget);
    });

    testWidgets(
        '标题获焦后点击备注 Quill 编辑器，焦点应切换到编辑器（不再被外层 Scrollable 吞掉）',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              ...AppLocalizations.localizationsDelegates,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: NoteEditScreen(dateStr: '2025-06-14'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final titleEditable = _findTitleEditable(tester);
      final titleFocus = titleEditable.focusNode;
      final quillEditor = find.byType(QuillEditor);
      expect(quillEditor, findsOneWidget, reason: '备注 Quill 编辑器应存在');

      // 1) 点标题，让它获焦
      final titleFieldFinder = find.byType(EditableText).first;
      await tester.tap(titleFieldFinder);
      await tester.pump();
      expect(titleFocus.hasFocus, isTrue,
          reason: '点标题后标题应获焦');

      // 2) 滚到可见，再点备注编辑器
      await tester.ensureVisible(quillEditor);
      await tester.pump();
      await tester.tap(quillEditor);
      await tester.pump();

      // 3) 标题应已失焦
      expect(titleFocus.hasFocus, isFalse,
          reason: '点备注后标题应失焦（焦点已被外层 Scrollable 吞掉的回归点）');

      // 4) 当前主焦点应不再是标题的 FocusNode
      final primaryFocus = tester.binding.focusManager.primaryFocus;
      expect(primaryFocus, isNotNull);
      expect(primaryFocus, isNot(equals(titleFocus)),
          reason: '焦点应已离开标题字段');
    });

    testWidgets(
        '点击 AppBar 日期 → 改到空日期 → AppBar 实时更新，无冲突弹框',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              ...AppLocalizations.localizationsDelegates,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: NoteEditScreen(dateStr: '2025-06-14'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 注入 picker 桩：返回 2025-06-20
      final state =
          tester.state(find.byType(NoteEditScreen)) as dynamic;
      var pickerCalls = 0;
      state.debugSetShowDatePickerFor(
        (ctx, initial) async {
          pickerCalls++;
          return DateTime(2025, 6, 20);
        },
      );

      // 初始标题显示 6-14
      expect(find.text('2025年6月14日'), findsOneWidget);

      // 直接驱动 _pickNewDate（绕开 tap 命中检测的脆性）。
      // _pickNewDate 内部 await repo.findByDate → sqflite_common_ffi
      // 走平台通道，需要 tester.runAsync 真实执行。
      await tester.runAsync(() async {
        await state.debugPickNewDate();
      });
      await tester.pumpAndSettle();
      expect(pickerCalls, 1, reason: 'picker 桩应被调用一次');

      // 新标题显示 6-20
      expect(find.text('2025年6月20日'), findsOneWidget,
          reason: 'AppBar 日期应实时反映新日期');
      // 旧文本不再出现
      expect(find.text('2025年6月14日'), findsNothing);
      // 目标日期空 → 没有冲突弹框
      expect(find.byType(AlertDialog), findsNothing);
    });

    // 冲突确认对话框的覆盖由仓库层（target date 非空 → Moved 事件）
// + coordinator 层（双日期失效）两个测试已经保证。
// widget 层只保留：picker 选空日期 → AppBar 实时更新这条主路径。
  });
}