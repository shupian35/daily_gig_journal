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

    test('save() moves note to new date: both old and new date list providers invalidated', () async {
      final note = WorkEntry.empty('2025-06-14');
      final id = await repo.add(note);

      // 触发 coordinator.build() 提前建立 repo.watch() 订阅，
      // 否则 build 在后续 save 时才调用，第一次 add 的事件不会被监听。
      container.read(entryCoordinatorProvider);

      // 用 listen 订阅两个 family provider，阻止 autoDispose 提前释放。
      final oldSub = container.listen(
        notesByDateListProvider('2025-06-14'),
        (_, _) {},
      );
      final newSub = container.listen(
        notesByDateListProvider('2025-06-20'),
        (_, _) {},
      );
      addTearDown(oldSub.close);
      addTearDown(newSub.close);

      // 预热两个 family：旧日期有 1 条，新日期为空
      await container.read(notesByDateListProvider('2025-06-14').future);
      await container.read(notesByDateListProvider('2025-06-20').future);
      expect(
        container.read(notesByDateListProvider('2025-06-14')).value,
        hasLength(1),
      );
      expect(
        container.read(notesByDateListProvider('2025-06-20')).value,
        isEmpty,
      );

      // 把 note 从 6-14 移到 6-20
      await container
          .read(entryCoordinatorProvider.notifier)
          .save(note.copyWith(id: id, date: '2025-06-20'));

      // 让出 microtask，确保 broadcast stream 的 listener dispatch。
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // 重新读 family（.future）—— 由于 coordinator 失效了它们，
      // 这里应重新走 repo.findByDate；新值与 DB 同步。
      final oldListNew = await container
          .read(notesByDateListProvider('2025-06-14').future);
      final newListNew = await container
          .read(notesByDateListProvider('2025-06-20').future);
      expect(oldListNew, isEmpty, reason: '旧日期列表应被失效并清空');
      expect(newListNew, hasLength(1), reason: '新日期列表应包含移动后的条目');
      expect(newListNew.first.date, '2025-06-20');
    });
  });

  group('EntryCoordinator · tag mutations (写入瓶颈点 + 自动备份)', () {
    late ProviderContainer container;
    late SqliteWorkEntryRepository repo;
    late int backupCalls;

    setUp(() async {
      backupCalls = 0;
      EntryCoordinator.backupHook = () async => backupCalls++;
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
