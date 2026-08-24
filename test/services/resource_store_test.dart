import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_gig_journal/services/backup_service.dart';
import 'package:daily_gig_journal/services/resource_store.dart';
import 'package:daily_gig_journal/widgets/drawing_data.dart';

void main() {
  group('ResourceStore（资源写入接缝 · 候选 A）', () {
    late Directory tempDir;
    late ProviderContainer container;
    late ResourceStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('resource_store_test');
      container = ProviderContainer();
      addTearDown(container.dispose);
      store = ResourceStore(
        container: container,
        rootResolver: () async => tempDir.path,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('saveImage', () {
      test('落盘到 images/ + change set 增加对应 upload 条目', () async {
        final source = File('${tempDir.path}/src.png');
        await source.writeAsBytes(utf8.encode('fake-png-bytes'));

        final rel = await store.saveImage(source);

        expect(rel, startsWith('images/img_'));
        expect(rel, endsWith('.png'));
        final dest = File('${tempDir.path}/$rel');
        expect(await dest.exists(), isTrue);
        expect(await dest.readAsBytes(), utf8.encode('fake-png-bytes'));

        final cs = container.read(backupChangeSetProvider);
        expect(cs.imagesToUpload, contains(rel));
        expect(cs.imagesToTrash, isEmpty);
      });

      test('文件名遵循 img_YYYY-MM-DD_NNNNNN.png 规则（ADR-0009 basename）', () async {
        final source = File('${tempDir.path}/a.png');
        await source.writeAsBytes([1]);

        final rel = await store.saveImage(source);

        expect(
          RegExp(r'^images/img_\d{4}-\d{2}-\d{2}_\d{6}\.png$').hasMatch(rel),
          isTrue,
          reason: '实际 rel=$rel',
        );
      });
    });

    group('removeImage', () {
      test('删除本地文件 + change set 增加对应 trash 条目', () async {
        await File('${tempDir.path}/images/old.png')
            .create(recursive: true)
            .then((f) => f.writeAsBytes([1]));

        await store.removeImage('images/old.png');

        expect(
            File('${tempDir.path}/images/old.png').existsSync(), isFalse);
        final cs = container.read(backupChangeSetProvider);
        expect(cs.imagesToTrash, contains('images/old.png'));
        expect(cs.imagesToUpload, isEmpty);
      });

      test('文件本就不存在时仍上报 trash（云端可能有副本需软删）', () async {
        await store.removeImage('images/ghost.png');

        expect(container.read(backupChangeSetProvider).imagesToTrash,
            contains('images/ghost.png'));
      });
    });

    group('saveDraft', () {
      test('落盘 JSON 到 drafts/ + change set 增加对应 upload 条目', () async {
        final draft = CanvasDraft(
          version: 1,
          transform: [1, 0, 0, 1, 0, 0],
          strokes: const [],
          layers: const [],
        );

        final rel = await store.saveDraft(draft);

        expect(rel, startsWith('drafts/draft_'));
        expect(rel, endsWith('.json'));
        final file = File('${tempDir.path}/$rel');
        expect(await file.exists(), isTrue);
        final json = jsonDecode(await file.readAsString());
        expect(json['version'], 1);

        final cs = container.read(backupChangeSetProvider);
        expect(cs.draftsToUpload, contains(rel));
        expect(cs.draftsToTrash, isEmpty);
      });
    });

    group('removeDraft', () {
      test('删除草稿文件 + change set 增加对应 trash 条目（堵死旧零调用点缺口）',
          () async {
        await File('${tempDir.path}/drafts/draft_x.json')
            .create(recursive: true)
            .then((f) => f.writeAsString('{}'));

        await store.removeDraft('drafts/draft_x.json');

        expect(
            File('${tempDir.path}/drafts/draft_x.json').existsSync(), isFalse);
        final cs = container.read(backupChangeSetProvider);
        expect(cs.draftsToTrash, contains('drafts/draft_x.json'));
        expect(cs.draftsToUpload, isEmpty);
      });
    });
  });

  group('BackupChangeSetNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    group('mergeForFullSync（merge 语义 · 锁死不覆盖 pending trash）', () {
      test('pending trash 存在时全量同步不清除 trash 条目', () {
        final n = container.read(backupChangeSetProvider.notifier);
        n.markImageTrash('images/deleted.png');
        n.markDraftTrash('drafts/deleted.json');

        n.mergeForFullSync(
          imagesToUpload: {'images/a.png'},
          draftsToUpload: {'drafts/b.json'},
        );

        final cs = container.read(backupChangeSetProvider);
        // trash 条目原样保留——软删除不得静默丢失
        expect(cs.imagesToTrash, {'images/deleted.png'});
        expect(cs.draftsToTrash, {'drafts/deleted.json'});
        expect(cs.imagesToUpload, {'images/a.png'});
        expect(cs.draftsToUpload, {'drafts/b.json'});
      });

      test('已有 pending upload 与扫描结果取并集，不去重丢失', () {
        final n = container.read(backupChangeSetProvider.notifier);
        n.markImageUpload('images/pending.png');

        n.mergeForFullSync(
          imagesToUpload: {'images/scanned.png'},
          draftsToUpload: {},
        );

        final cs = container.read(backupChangeSetProvider);
        expect(
          cs.imagesToUpload,
          containsAll(['images/pending.png', 'images/scanned.png']),
        );
      });
    });

    group('markXxx 类型化写入口', () {
      test('四个动词各自只影响对应集合且幂等（Set 语义）', () {
        final n = container.read(backupChangeSetProvider.notifier);
        n.markImageUpload('images/i.png');
        n.markImageUpload('images/i.png');
        n.markDraftUpload('drafts/d.json');
        n.markImageTrash('images/t.png');
        n.markDraftTrash('drafts/t.json');
        n.markDraftTrash('drafts/t.json');

        final cs = container.read(backupChangeSetProvider);
        expect(cs.imagesToUpload, {'images/i.png'});
        expect(cs.draftsToUpload, {'drafts/d.json'});
        expect(cs.imagesToTrash, {'images/t.png'});
        expect(cs.draftsToTrash, {'drafts/t.json'});
        expect(cs.isEmpty, isFalse);
      });

      test('reset 清空全部条目（autoBackup 取走变更集后）', () {
        final n = container.read(backupChangeSetProvider.notifier);
        n.markImageUpload('images/i.png');
        n.markDraftTrash('drafts/t.json');

        n.reset();

        expect(container.read(backupChangeSetProvider).isEmpty, isTrue);
      });
    });
  });
}
