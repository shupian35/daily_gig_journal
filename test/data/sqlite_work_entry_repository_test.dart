import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_gig_journal/data/sqlite_work_entry_repository.dart';
import 'package:daily_gig_journal/models/work_entry.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteWorkEntryRepository.setTestDbPath(
        '${Directory.systemTemp.path}/test_sqlite_repo.db');
  });

  group('SqliteWorkEntryRepository', () {
    late SqliteWorkEntryRepository repo;

    setUp(() async {
      repo = SqliteWorkEntryRepository();
      final db = await repo.filePath();
      final file = File(db);
      if (await file.exists()) await file.delete();
      repo = SqliteWorkEntryRepository();
    });

    test('add returns new id and fires Added event', () async {
      final events = <dynamic>[];
      final sub = repo.watch().listen(events.add);
      final id = await repo.add(WorkEntry.empty('2025-06-14'));
      await Future<void>.delayed(Duration.zero);
      expect(id, greaterThan(0));
      expect(events, hasLength(1));
      expect(events.first.runtimeType.toString(), contains('Added'));
      await sub.cancel();
      await repo.close();
    });

    test('update fires Edited event', () async {
      final note = WorkEntry.empty('2025-06-14');
      final id = await repo.add(note);
      final events = <dynamic>[];
      final sub = repo.watch().listen(events.add);
      await repo.update(note.copyWith(id: id, title: 'updated'));
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      final fetched = await repo.findById(id);
      expect(fetched?.title, 'updated');
      await sub.cancel();
      await repo.close();
    });

    test('remove fires Removed event', () async {
      final note = WorkEntry.empty('2025-06-14');
      final id = await repo.add(note);
      final events = <dynamic>[];
      final sub = repo.watch().listen(events.add);
      await repo.remove(id);
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(await repo.findById(id), isNull);
      await sub.cancel();
      await repo.close();
    });

    test('add rejects id != null', () async {
      expect(
        () => repo.add(WorkEntry.empty('2025-06-14').copyWith(id: 99)),
        throwsA(isA<ArgumentError>()),
      );
      await repo.close();
    });

    test('update rejects id == null', () async {
      expect(
        () => repo.update(WorkEntry.empty('2025-06-14')),
        throwsA(isA<ArgumentError>()),
      );
      await repo.close();
    });

    test('findByDate sorted by startTime', () async {
      await repo.add(WorkEntry(date: '2025-06-14', title: 'PM', workLocation: '', contact: '', startTime: '14:00', endTime: '18:00', hourlyWage: 0, workHours: 0, dailyWage: 0, noteContent: '[]'));
      await repo.add(WorkEntry(date: '2025-06-14', title: 'AM', workLocation: '', contact: '', startTime: '08:00', endTime: '12:00', hourlyWage: 0, workHours: 0, dailyWage: 0, noteContent: '[]'));
      final list = await repo.findByDate('2025-06-14');
      expect(list.first.title, 'AM');
      await repo.close();
    });

    test('multi-entry per day no UNIQUE constraint', () async {
      await repo.add(WorkEntry.empty('2025-06-14'));
      await repo.add(WorkEntry.empty('2025-06-14'));
      await repo.add(WorkEntry.empty('2025-06-14'));
      expect((await repo.findByDate('2025-06-14')).length, 3);
      await repo.close();
    });

    test('monthlyTotal sums dailyWage', () async {
      await repo.add(WorkEntry(date: '2025-06-14', title: '', workLocation: '', contact: '', startTime: '09:00', endTime: '18:00', hourlyWage: 0, workHours: 0, dailyWage: 200, noteContent: '[]'));
      await repo.add(WorkEntry(date: '2025-06-15', title: '', workLocation: '', contact: '', startTime: '09:00', endTime: '18:00', hourlyWage: 0, workHours: 0, dailyWage: 300, noteContent: '[]'));
      expect(await repo.monthlyTotal('2025-06'), 500.0);
      await repo.close();
    });
  });

  group('ADR-0009 v5→v6 路径迁移 debugRewriteImagePathsForTest', () {
    String buildDelta(List<Map<String, dynamic>> ops) =>
        const JsonEncoder().convert(ops);

    Map<String, dynamic> parseDelta(String json) =>
        (jsonDecode(json) as List).cast<Map<String, dynamic>>().first;

    test('迁移绝对路径为 images/<basename>（白名单命中）', () {
      final input = buildDelta([
        {
          'insert': {
            'image': '/data/user/0/com.example/files/img_2025-06-14_000001.png',
          },
        },
      ]);
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      final op = parseDelta(out);
      final insert = op['insert'] as Map;
      expect(insert['image'], 'images/img_2025-06-14_000001.png');
    });

    test('迁移 Windows 路径反斜杠也命中', () {
      final input = buildDelta([
        {
          'insert': {
            'image': r'C:\Users\me\AppData\images\img_2025-06-14_000001.png',
          },
        },
      ]);
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      final insert = parseDelta(out)['insert'] as Map;
      expect(insert['image'], 'images/img_2025-06-14_000001.png');
    });

    test('非白名单绝对路径保留原值', () {
      final input = buildDelta([
        {
          'insert': {
            'image': '/data/user/0/com.example/files/photo_2025-06-14.jpg',
          },
        },
      ]);
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      final insert = parseDelta(out)['insert'] as Map;
      expect(insert['image'], '/data/user/0/com.example/files/photo_2025-06-14.jpg');
    });

    test('已经是相对名的 image 字段不动', () {
      final input = buildDelta([
        {
          'insert': {
            'image': 'images/img_2025-06-14_000001.png',
          },
        },
      ]);
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      final insert = parseDelta(out)['insert'] as Map;
      expect(insert['image'], 'images/img_2025-06-14_000001.png');
    });

    test('不包含 image 字段的 Delta 不变', () {
      final input = buildDelta([
        {'insert': '今天做了会展协助'},
      ]);
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      expect(out, input);
    });

    test('空 noteContent 正常处理', () {
      const input = '[]';
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      expect(out, '[]');
    });

    test('破损 JSON 不抛异常，原样保留', () {
      const input = '{invalid json';
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      expect(out, input);
    });

    test('混合：图片 + 文本 ops 同时存在只动 image', () {
      final input = buildDelta([
        {'insert': '今天做了'},
        {
          'insert': {
            'image': '/data/user/0/x/img_2025-06-14_000001.png',
          },
        },
        {'insert': '工作'},
      ]);
      final out = SqliteWorkEntryRepository.debugRewriteImagePathsForTest(input);
      final ops = jsonDecode(out) as List;
      expect((ops[0]['insert'] as String), '今天做了');
      expect(((ops[1]['insert'] as Map)['image']), 'images/img_2025-06-14_000001.png');
      expect((ops[2]['insert'] as String), '工作');
    });
  });
}
