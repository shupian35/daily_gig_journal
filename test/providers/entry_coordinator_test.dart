import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daily_gig_journal/data/in_memory_work_entry_repository.dart';
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

  group('EntryCoordinator · tag mutations (写入瓶颈点 + 自动备份)', () {
    late ProviderContainer container;
    late SqliteWorkEntryRepository repo;
    late int backupCalls;

    setUp(() async {
      backupCalls = 0;
      EntryCoordinator.backupHook = (_) async => backupCalls++;
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

    tearDown(() {
      EntryCoordinator.backupHook = null;
    });

    Future<void> seed() async {
      await repo.add(WorkEntry.empty('2025-06-14')
          .copyWith(title: '会展协助', tags: ['会展', 'A馆']));
      await repo.add(WorkEntry.empty('2025-06-15')
          .copyWith(title: '家教', tags: ['家教']));
      await repo.add(WorkEntry.empty('2025-06-16')
          .copyWith(title: '发传单', tags: ['会展']));
    }

    test('renameTag() renames in DB + triggers auto backup', () async {
      await seed();
      await container.read(entryCoordinatorProvider.notifier)
          .renameTag(from: '会展', to: '展览');
      expect((await repo.findByTag('展览')).length, 2);
      expect(await repo.findByTag('会展'), isEmpty);
      expect(await repo.allTags(), containsAll(['展览', 'A馆', '家教']));
      expect(backupCalls, 1);
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('deleteTag() removes tag from DB + triggers auto backup', () async {
      await seed();
      await container.read(entryCoordinatorProvider.notifier).deleteTag('会展');
      expect(await repo.findByTag('会展'), isEmpty);
      expect(await repo.allTags(), isNot(contains('会展')));
      // 其他 tag 不受影响
      expect((await repo.findByTag('A馆')).length, 1);
      expect(backupCalls, 1);
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('mergeTag() merges into target tag + triggers auto backup', () async {
      await seed();
      await container.read(entryCoordinatorProvider.notifier)
          .mergeTag(from: '家教', to: '会展');
      expect((await repo.findByTag('会展')).length, 3);
      expect(await repo.findByTag('家教'), isEmpty);
      expect(backupCalls, 1);
      expect(container.read(entryCoordinatorProvider), isA<AsyncData<void>>());
    });

    test('renameTag()/deleteTag()/mergeTag() on failure: state AsyncError, '
        'no backup triggered, returns -1', () async {
      await seed();
      final failingRepo = _ThrowingTagRepo();
      await failingRepo.add(
          WorkEntry.empty('2025-06-14').copyWith(tags: ['会展']));
      final failContainer = ProviderContainer(
        overrides: [
          workEntryRepositoryProvider.overrideWithValue(failingRepo),
        ],
      );
      addTearDown(failContainer.dispose);
      addTearDown(failingRepo.close);

      final notifier = failContainer.read(entryCoordinatorProvider.notifier);
      expect(await notifier.renameTag(from: '会展', to: '展览'), -1);
      expect(failContainer.read(entryCoordinatorProvider),
          isA<AsyncError<void>>());
      expect(await notifier.deleteTag('会展'), -1);
      expect(failContainer.read(entryCoordinatorProvider),
          isA<AsyncError<void>>());
      expect(await notifier.mergeTag(from: '会展', to: '展览'), -1);
      expect(failContainer.read(entryCoordinatorProvider),
          isA<AsyncError<void>>());
      expect(backupCalls, 0);
    });
  });
}

/// renameTag/deleteTag/mergeTag 永远抛错的假 repo，用于错误路径测试。
class _ThrowingTagRepo extends InMemoryWorkEntryRepository {
  @override
  Future<int> renameTag({required String from, required String to}) async =>
      throw Exception('renameTag failed');

  @override
  Future<int> deleteTag(String tag) async => throw Exception('deleteTag failed');
}
