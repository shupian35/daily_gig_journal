import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daily_gig_journal/database/database_helper.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/providers/entry_coordinator.dart';


void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.setTestDbPath('${Directory.systemTemp.path}/test_entry_coord.db');
  });

  group('EntryCoordinator', () {
    late ProviderContainer container;
    late DatabaseHelper db;

    setUp(() async {
      db = DatabaseHelper();
      await db.deleteAll();
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('初始 state 是 AsyncData<void>(null)', () {
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('save() 插入新笔记：DB 有该行 + state 维持 AsyncData', () async {
      await container
          .read(entryCoordinatorProvider.notifier)
          .save(WorkEntry.empty('2025-06-14'));

      final fetched = await db.getNotesByDateList('2025-06-14');
      expect(fetched.length, 1);
      expect(fetched.first.date, '2025-06-14');
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('save() 更新已存在笔记：DB 内容更新 + state 维持 AsyncData', () async {
      final note = WorkEntry.empty('2025-06-14');
      final id = await db.insertNote(note);
      final updated = note.copyWith(id: id, title: 'updated');

      await container.read(entryCoordinatorProvider.notifier).save(updated);

      final fetched = await db.getNoteById(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'updated');
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('delete() 移除笔记：DB 无该行 + state 维持 AsyncData', () async {
      final note = WorkEntry.empty('2025-06-14');
      final id = await db.insertNote(note);

      await container
          .read(entryCoordinatorProvider.notifier)
          .delete(id: id, date: '2025-06-14');

      expect(await db.getNoteById(id), isNull);
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });
  });
}