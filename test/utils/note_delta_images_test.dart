import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/utils/note_delta_images.dart';

void main() {
  String buildDelta(List<Map<String, dynamic>> ops) =>
      const JsonEncoder().convert(ops);

  group('NoteDeltaImages.collectRelPaths', () {
    test('按文档顺序收集图片相对名', () {
      final delta = buildDelta([
        {'insert': '今天做了'},
        {'insert': {'image': 'images/img_2025-06-14_000001.png'}},
        {'insert': '工作'},
        {'insert': {'image': 'images/img_2025-06-15_000002.png'}},
      ]);
      expect(
        NoteDeltaImages.collectRelPaths(delta),
        [
          'images/img_2025-06-14_000001.png',
          'images/img_2025-06-15_000002.png',
        ],
      );
    });

    test('无图片返回空列表', () {
      final delta = buildDelta([
        {'insert': '纯文本\n'},
      ]);
      expect(NoteDeltaImages.collectRelPaths(delta), isEmpty);
    });

    test('破损 JSON 返回空列表不抛异常', () {
      expect(NoteDeltaImages.collectRelPaths('{invalid json'), isEmpty);
      expect(NoteDeltaImages.collectRelPaths(''), isEmpty);
    });

    test('非列表 JSON 返回空列表', () {
      expect(NoteDeltaImages.collectRelPaths('"just a string"'), isEmpty);
    });
  });

  group('NoteDeltaImages.rewriteToRelativePaths（v6 迁移核心）', () {
    test('Android 绝对路径改写为 images/<basename>', () {
      final input = buildDelta([
        {'insert': {'image': '/data/user/0/com.example/files/img_2025-06-14_000001.png'}},
      ]);
      final out = NoteDeltaImages.rewriteToRelativePaths(input);
      final op = (jsonDecode(out) as List).first as Map;
      expect(op['insert']['image'], 'images/img_2025-06-14_000001.png');
    });

    test('Windows 反斜杠绝对路径也命中', () {
      for (final path in [
        r'C:\Users\me\AppData\images\img_2025-06-14_000001.png',
        r'\\nas\share\img_2025-06-14_000001.png',
      ]) {
        final input = buildDelta([
          {'insert': {'image': path}},
        ]);
        final out = NoteDeltaImages.rewriteToRelativePaths(input);
        final op = (jsonDecode(out) as List).first as Map;
        expect(op['insert']['image'], 'images/img_2025-06-14_000001.png');
      }
    });

    test('白名单外 basename 的绝对路径保留原值', () {
      const original = '/data/user/0/com.example/files/photo_2025-06-14.jpg';
      final input = buildDelta([
        {'insert': {'image': original}},
      ]);
      final out = NoteDeltaImages.rewriteToRelativePaths(input);
      final op = (jsonDecode(out) as List).first as Map;
      expect(op['insert']['image'], original);
    });

    test('已是相对名幂等：再次调用不变', () {
      const rel = 'images/img_2025-06-14_000001.png';
      final once = NoteDeltaImages.rewriteToRelativePaths(
        buildDelta([
          {'insert': {'image': rel}},
        ]),
      );
      final twice = NoteDeltaImages.rewriteToRelativePaths(once);
      expect(once, twice);
    });

    test('无路径分隔符的裸文件名不改写（非绝对路径）', () {
      final input = buildDelta([
        {'insert': {'image': 'img_2025-06-14_000001.png'}},
      ]);
      final out = NoteDeltaImages.rewriteToRelativePaths(input);
      final op = (jsonDecode(out) as List).first as Map;
      expect(op['insert']['image'], 'img_2025-06-14_000001.png');
    });

    test('不含 image 字段的 Delta 原样返回（引用相等语义）', () {
      const input = '[{"insert":"今天做了会展协助\\n"}]';
      expect(NoteDeltaImages.rewriteToRelativePaths(input), input);
    });

    test('空 noteContent 正常处理', () {
      expect(NoteDeltaImages.rewriteToRelativePaths('[]'), '[]');
    });

    test('破损 JSON 不抛异常，原样保留', () {
      const input = '{invalid json';
      expect(NoteDeltaImages.rewriteToRelativePaths(input), input);
    });

    test('混合 ops 只动 image 字段', () {
      final input = buildDelta([
        {'insert': '今天做了'},
        {'insert': {'image': '/data/user/0/x/img_2025-06-14_000001.png'}},
        {'insert': '工作\n'},
      ]);
      final out = NoteDeltaImages.rewriteToRelativePaths(input);
      final ops = jsonDecode(out) as List;
      expect(ops[0]['insert'], '今天做了');
      expect(ops[1]['insert']['image'], 'images/img_2025-06-14_000001.png');
      expect(ops[2]['insert'], '工作\n');
    });
  });

  group('NoteDeltaImages 受管 basename 规范（生成器与白名单共享常量）', () {
    test('标准样例命中白名单', () {
      expect(
        NoteDeltaImages.isManagedImageBasename('img_2025-06-14_000001.png'),
        isTrue,
      );
      expect(
        NoteDeltaImages.isManagedImageBasename('img_2025-12-31_999999.png'),
        isTrue,
      );
    });

    test('格式偏差不命中', () {
      expect(
        NoteDeltaImages.isManagedImageBasename('img_2025-6-14_00001.png'),
        isFalse,
      ); // 月/日未补零、随机数 5 位
      expect(
        NoteDeltaImages.isManagedImageBasename('photo_2025-06-14_000001.png'),
        isFalse,
      );
      expect(
        NoteDeltaImages.isManagedImageBasename('img_2025-06-14_000001.jpg'),
        isFalse,
      );
    });

    test('imageDateRandBody 补零到 6 位且拼出的名字命中白名单', () {
      final body = NoteDeltaImages.imageDateRandBody('2025-06-14', 42);
      expect(body, '2025-06-14_000042');
      expect(
        NoteDeltaImages.isManagedImageBasename(
          '${NoteDeltaImages.managedImagePrefix}$body${NoteDeltaImages.managedImageExtension}',
        ),
        isTrue,
      );
    });
  });

  group('NoteDeltaImages.deltaToPlainText（搜索/导出单一实现）', () {
    const delta = '[{"insert":"今天做了会展协助"},'
        '{"insert":{"image":"images/img_2025-06-14_000001.png"}},'
        '{"insert":{"other":"x"}},'
        '{"insert":"工作\\n"}]';

    test('搜索语义：嵌入跳过、拼接文本、空/破损输入返回空串', () {
      expect(NoteDeltaImages.deltaToPlainText(delta), '今天做了会展协助工作\n');
      expect(NoteDeltaImages.deltaToPlainText(''), '');
      expect(NoteDeltaImages.deltaToPlainText('{broken'), '');
      expect(NoteDeltaImages.deltaToPlainText('"not a list"'), '');
      expect(NoteDeltaImages.deltaToPlainText('[]'), '');
    });

    test('导出语义：占位符 + 裁剪 + 解析失败返回原文', () {
      String exportPlain(String j) => NoteDeltaImages.deltaToPlainText(
            j,
            embedPlaceholder: (ins) =>
                ins.containsKey('image') ? '[图片]' : '[附件]',
            trimResult: true,
            fallback: j,
          );
      expect(exportPlain(delta), '今天做了会展协助[图片][附件]工作');
      // 破损 JSON 返回原文
      expect(exportPlain('{broken'), '{broken');
      expect(exportPlain(''), '');
    });
  });

  group('NoteDeltaImages.imageAbsPathCore（ADR-0009 关键不变量，首次直测）', () {
    const docsRoot = '/tmp/fake-docs-root';

    test('相对名 join docsRoot', () {
      expect(
        NoteDeltaImages.imageAbsPathCore('images/img_2025-06-14_000001.png', docsRoot),
        '$docsRoot/images/img_2025-06-14_000001.png',
      );
      expect(
        NoteDeltaImages.imageAbsPathCore('drafts/draft_x.json', docsRoot),
        '$docsRoot/drafts/draft_x.json',
      );
    });

    test('已是绝对路径（Unix 风格 / 开头）原样返回', () {
      expect(
        NoteDeltaImages.imageAbsPathCore('/data/user/0/x/img.png', docsRoot),
        '/data/user/0/x/img.png',
      );
    });

    test('Windows 盘符反斜杠绝对路径原样返回（跨平台恢复场景）', () {
      expect(
        NoteDeltaImages.imageAbsPathCore(r'C:\Users\me\img.png', docsRoot),
        r'C:\Users\me\img.png',
      );
    });

    test('docsRoot 变化后同一 rel 映射到新 root（跨设备重装不变量）', () {
      const rel = 'images/img_2025-06-14_000001.png';
      expect(
        NoteDeltaImages.imageAbsPathCore(rel, '/old/device/path'),
        '/old/device/path/$rel',
      );
      expect(
        NoteDeltaImages.imageAbsPathCore(rel, '/new/device/path'),
        '/new/device/path/$rel',
      );
    });
  });
}
