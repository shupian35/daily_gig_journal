import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daily_gig_journal/data/sqlite_work_entry_repository.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/providers/entry_coordinator.dart';
import 'package:daily_gig_journal/providers/notes_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteWorkEntryRepository.setTestDbPath(
        '${Directory.systemTemp.path}/test_entry_coord.db');
  });

  group('EntryCoordinator', () {
    late ProviderContainer container;
    late SqliteWorkEntryRepository repo;

    setUp(() async {
      repo = SqliteWorkEntryRepository();
      final dbPath = await repo.filePath();
      final file = File(dbPath);
      if (await file.exists()) await file.delete();
      repo = SqliteWorkEntryRepository();
      container = ProviderContainer(
        overrides: [
          workEntryRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() async { await repo.close(); });
    });

    test('initial state is AsyncData<void>(null)', () {
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('save() inserts new entry: DB has row + state stays AsyncData', () async {
      await container.read(entryCoordinatorProvider.notifier).save(WorkEntry.empty('2025-06-14'));
      final fetched = await repo.findByDate('2025-06-14');
      expect(fetched.length, 1);
      expect(fetched.first.date, '2025-06-14');
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('save() updates existing entry: DB content updates + state stays AsyncData', () async {
      final note = WorkEntry.empty('2025-06-14');
      final id = await repo.add(note);
      final updated = note.copyWith(id: id, title: 'updated');
      await container.read(entryCoordinatorProvider.notifier).save(updated);
      final fetched = await repo.findById(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'updated');
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('delete() removes entry: DB has no row + state stays AsyncData', () async {
      final note = WorkEntry.empty('2025-06-14');
      final id = await repo.add(note);
      await container.read(entryCoordinatorProvider.notifier).delete(id: id);
      expect(await repo.findById(id), isNull);
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });
  });
}
