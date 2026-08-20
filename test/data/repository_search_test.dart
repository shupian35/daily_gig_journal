import 'package:flutter_test/flutter_test.dart';

import 'package:daily_gig_journal/data/in_memory_work_entry_repository.dart';
import 'package:daily_gig_journal/models/work_entry.dart';

/// 测试 `InMemoryWorkEntryRepository` 上的 tags / search 接口。
///
/// 对应的 SQLite adapter 走 `sqlite_work_entry_repository_test.dart` 同等覆盖；
/// 双 adapter 用相同的边界条件确保语义对齐。
void main() {
  group('InMemoryWorkEntryRepository · tags', () {
    late InMemoryWorkEntryRepository repo;

    setUp(() async {
      repo = InMemoryWorkEntryRepository();
    });

    Future<void> seed() async {
      await repo.add(WorkEntry.empty('2025-06-14')
          .copyWith(title: '会展协助', tags: ['会展', 'A馆']));
      await repo.add(WorkEntry.empty('2025-06-15')
          .copyWith(title: '家教', tags: ['家教']));
      await repo.add(WorkEntry.empty('2025-06-16')
          .copyWith(title: '发传单', tags: ['会展']));
      await repo.add(WorkEntry.empty('2025-06-17')
          .copyWith(title: '搬货', tags: const []));
    }

    test('allTags 去重 + 排序', () async {
      await seed();
      final tags = await repo.allTags();
      // Unicode codepoint 升序: 会(U+4F1A) < 家(U+5BB6) < A(U+0041, ASCII 比中文小)
      expect(tags, ['A馆', '会展', '家教']);
    });

    test('allTags 空数据库返回空列表', () async {
      expect(await repo.allTags(), isEmpty);
    });

    test('findByTag 命中独立 token,不含 substring', () async {
      await seed();
      // "会展" 应命中 6-14、6-16 两条
      final hits = await repo.findByTag('会展');
      expect(hits.length, 2);
      expect(hits.map((e) => e.date).toSet(), {'2025-06-14', '2025-06-16'});
    });

    test('findByTag 子串"会" 不命中 "会展"', () async {
      await seed();
      final hits = await repo.findByTag('会');
      expect(hits, isEmpty);
    });

    test('findByTag 空字符串返回空列表', () async {
      await seed();
      expect(await repo.findByTag(''), isEmpty);
      expect(await repo.findByTag('   '), isEmpty);
    });

    test('renameTag 替换 token,去重,保留其他 tag', () async {
      await seed();
      final changed = await repo.renameTag(from: '会展', to: '展览');
      expect(changed, 2);
      // 6-14 应当是 [展览, A馆]
      final updated = await repo.findByTag('展览');
      expect(updated.length, 2);
      final day1 = updated.firstWhere((e) => e.date == '2025-06-14');
      expect(day1.tags, ['展览', 'A馆']);
      // 字典刷新
      expect(await repo.allTags(), contains('展览'));
      expect(await repo.allTags(), isNot(contains('会展')));
    });

    test('renameTag 同名→同名 返回 0', () async {
      await seed();
      expect(await repo.renameTag(from: '会展', to: '会展'), 0);
    });

    test('deleteTag 从所有记录移除', () async {
      await seed();
      final changed = await repo.deleteTag('会展');
      expect(changed, 2);
      expect(await repo.findByTag('会展'), isEmpty);
      expect(await repo.allTags(), isNot(contains('会展')));
    });

    test('mergeTag 等价于 renameTag', () async {
      await seed();
      expect(await repo.mergeTag(from: '家教', to: 'teacher'), 1);
      expect(await repo.findByTag('teacher'), hasLength(1));
    });
  });

  group('InMemoryWorkEntryRepository · search', () {
    late InMemoryWorkEntryRepository repo;

    setUp(() async {
      repo = InMemoryWorkEntryRepository();
    });

    Future<void> seed() async {
      await repo.add(WorkEntry(
        date: '2025-06-14',
        title: 'Exhibition Center Setup',
        workLocation: 'Exhibition Center',
        contact: 'Zhang San',
        startTime: '08:00',
        endTime: '17:00',
        hourlyWage: 25,
        workHours: 9,
        dailyWage: 225,
        noteContent: '[]',
        tags: ['会展'],
      ));
      await repo.add(WorkEntry(
        date: '2025-06-15',
        title: 'Tutoring',
        workLocation: 'Student Home',
        contact: 'Li Si',
        startTime: '14:00',
        endTime: '18:00',
        hourlyWage: 60,
        workHours: 4,
        dailyWage: 240,
        noteContent: '[]',
        tags: ['家教'],
      ));
      await repo.add(WorkEntry(
        date: '2025-06-16',
        title: '发传单',
        workLocation: '步行街',
        contact: '王五',
        startTime: '10:00',
        endTime: '16:00',
        hourlyWage: 20,
        workHours: 6,
        dailyWage: 120,
        noteContent: '[]',
        tags: const [],
      ));
      // noteContent 含富文本纯文本片段,用于验证 noteContent 搜索
      await repo.add(WorkEntry(
        date: '2025-06-17',
        title: '搬货',
        workLocation: '仓库',
        contact: '',
        startTime: '09:00',
        endTime: '15:00',
        hourlyWage: 30,
        workHours: 6,
        dailyWage: 180,
        noteContent: '[{"insert":"Carried 30 boxes of drinks today, exhausting.\\n"}]',
        tags: const [],
      ));
    }

    test('全部参数为空 → 等同 findAllWithWage', () async {
      await seed();
      final list = await repo.search();
      expect(list.length, 4);
    });

    test('keyword 命中 title', () async {
      await seed();
      final list = await repo.search(keyword: 'Exhibition');
      expect(list.length, 1);
      expect(list.first.title, contains('Exhibition'));
    });

    test('keyword 命中 workLocation', () async {
      await seed();
      final list = await repo.search(keyword: 'Exhibition Center');
      expect(list.length, 1);
    });

    test('keyword 命中 contact', () async {
      await seed();
      final list = await repo.search(keyword: 'Li Si');
      expect(list.length, 1);
    });

    test('keyword 命中 noteContent 纯文本', () async {
      await seed();
      final list = await repo.search(keyword: 'Drinks');
      expect(list.length, 1);
      expect(list.first.title, '搬货');
    });

    test('keyword 大小写不敏感', () async {
      await seed();
      // 大写 keyword 命中 'Exhibition Center' (标题/地点字段)
      expect((await repo.search(keyword: 'CENTER')).length, 1);
      // 小写也命中
      expect((await repo.search(keyword: 'center')).length, 1);
    });

    test('dateFrom/dateTo 闭区间过滤', () async {
      await seed();
      final list = await repo.search(
        dateFrom: '2025-06-15',
        dateTo: '2025-06-16',
      );
      expect(list.length, 2);
      expect(list.map((e) => e.date).toSet(), {'2025-06-15', '2025-06-16'});
    });

    test('dateFrom 单端', () async {
      await seed();
      final list = await repo.search(dateFrom: '2025-06-17');
      expect(list.length, 1);
    });

    test('tag 过滤', () async {
      await seed();
      final list = await repo.search(tag: '家教');
      expect(list.length, 1);
      expect(list.first.title, 'Tutoring');
    });

    test('keyword + tag + date 组合 AND', () async {
      await seed();
      final list = await repo.search(
        keyword: '搬货',
        dateFrom: '2025-06-15',
        dateTo: '2025-06-20',
      );
      expect(list.length, 1);
    });

    test('排序:date DESC, startTime ASC', () async {
      await seed();
      final list = await repo.search();
      expect(list.first.date, '2025-06-17');
      expect(list.last.date, '2025-06-14');
    });

    test('无效 tag 不抛', () async {
      await seed();
      expect(await repo.search(tag: '不存在的标签'), isEmpty);
    });
  });
}