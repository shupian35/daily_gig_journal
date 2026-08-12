import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daily_gig_journal/data/sqlite_work_entry_repository.dart';
import 'package:daily_gig_journal/l10n/app_localizations.dart';
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
  });
}