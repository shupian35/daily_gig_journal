import 'dart:convert';
import 'dart:io';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/services/note_document_service.dart';

void main() {
  const fakeRoot = '/tmp/fake-docs-root';

  group('NoteDocumentService', () {
    late NoteDocumentService service;

    setUp(() {
      service = NoteDocumentService(docsRootResolver: () async => fakeRoot);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('load(null) 重置为空白文档；toPersistedJson 可往返', () {
      service.load(null);
      final json = service.toPersistedJson();
      final ops = jsonDecode(json) as List;
      expect(ops, isNotEmpty);
      // 空白文档重新 load 不抛异常
      service.load(null);
    });

    test('load(entry) 解析 noteContent 为可编辑文档', () {
      final entry = WorkEntry.empty('2025-06-14').copyWith(
        noteContent: jsonEncode([
          {'insert': '今天做了会展协助\n'},
        ]),
      );
      service.load(entry);
      expect(service.controller.document.toPlainText(), contains('会展协助'));
    });

    test('load 破损 JSON 兜底为空白文档不抛异常', () {
      final entry = WorkEntry.empty('2025-06-14')
          .copyWith(noteContent: '{broken json');
      service.load(entry);
      expect(service.toPersistedJson(), isNotEmpty);
    });

    test('insertImageFile 经 persist 回调落盘并写入光标处', () async {
      service.load(null);
      final persisted = <String>[];
      final rel = await service.insertImageFile(
        File('ignored.png'),
        persist: (f) async {
          persisted.add(f.path);
          return 'images/img_2025-06-14_000001.png';
        },
      );
      expect(rel, 'images/img_2025-06-14_000001.png');
      expect(persisted, ['ignored.png']);
      expect(service.imageRels(), [rel]);
    });

    test('imageRels 缓存式收集：Delta 未变时不重扫，变更后失效', () async {
      service.load(null);
      final rel1 = await service.insertImageFile(
        File('a.png'),
        persist: (_) async => 'images/img_2025-06-14_000001.png',
      );
      final rel2 = await service.insertImageFile(
        File('b.png'),
        persist: (_) async => 'images/img_2025-06-14_000002.png',
      );
      final first = service.imageRels();
      // 光标未移动时两次插入都落在同一 offset，顺序为后插在前（与旧屏行为一致）
      expect(first.length, 2);
      expect(first, containsAll([rel1, rel2]));
      // 同一文档状态再次访问返回同一缓存实例
      expect(identical(first, service.imageRels()), isTrue);
      // 删除触发控制器变更 → 缓存失效 → 收集结果更新
      expect(service.removeImage(rel1), isTrue);
      expect(service.imageRels(), [rel2]);
    });

    test('removeImage 删除长度计算消掉魔法数 2（embed + 换行）', () {
      const deltaJson = '''
[{"insert":"文字开头\\n"},{"insert":{"image":"images/img_2025-06-14_000001.png"}},{"insert":"\\n"},{"insert":{"image":"images/img_2025-06-14_000002.png"}},{"insert":"\\n"}]''';
      final ops = jsonDecode(deltaJson) as List;
      // 第一个图片：offset = len("文字开头\n") = 5，删 embed(1)+换行(1)=2
      expect(NoteDocumentService.locateImageRemoval(ops,
          'images/img_2025-06-14_000001.png'), (5, 2));
      // 第二个图片在末尾同样带换行
      expect(NoteDocumentService.locateImageRemoval(ops,
          'images/img_2025-06-14_000002.png'), (7, 2));
      // 未找到返回 null
      expect(
        NoteDocumentService.locateImageRemoval(ops, 'images/not_exist.png'),
        isNull,
      );
    });

    test('resolveAbsPaths 单次 root 解析批量映射（O(N²) 消除核心）', () async {
      var rootCalls = 0;
      final svc = NoteDocumentService(docsRootResolver: () async {
        rootCalls++;
        return fakeRoot;
      });
      addTearDown(svc.dispose);
      svc.load(null);
      await svc.insertImageFile(
        File('a.png'),
        persist: (_) async => 'images/img_2025-06-14_000001.png',
      );
      await svc.insertImageFile(
        File('b.png'),
        persist: (_) async => 'images/img_2025-06-14_000002.png',
      );
      rootCalls = 0;
      final map =
          await svc.resolveAbsPaths(['images/img_a.png', 'images/img_b.png']);
      expect(rootCalls, 1); // N 张图只解析一次 docs-root
      expect(map['images/img_a.png'], '$fakeRoot/images/img_a.png');
      expect(map['images/img_b.png'], '$fakeRoot/images/img_b.png');
    });

    test('controller 在 load 前访问抛 StateError', () {
      expect(() => service.controller, throwsStateError);
    });

    test('quill BlockEmbed 插入后 imageRels 与 locate 一致性冒烟', () async {
      service.load(null);
      final c = service.controller;
      c.replaceText(0, 0, quill.BlockEmbed.image('images/img_2025-06-14_000009.png'), null);
      final loc = NoteDocumentService.locateImageRemoval(
        c.document.toDelta().toJson(),
        'images/img_2025-06-14_000009.png',
      );
      expect(loc, isNotNull);
      expect(loc!.$2, greaterThanOrEqualTo(1));
    });
  });
}
