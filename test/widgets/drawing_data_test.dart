import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/widgets/drawing_data.dart';

void main() {
  group('ImageLayer 序列化', () {
    test('toJson → fromJson 往返一致', () async {
      // 用临时图片文件做往返测试
      final tmpDir = Directory.systemTemp;
      final imgPath = '${tmpDir.path}/test_draw_img.png';
      final imgFile = File(imgPath);
      // 写入最小的 1x1 PNG
      const pngBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
        0x54, 0x08, 0xD7, 0x63, 0x68, 0x00, 0x00, 0x00,
        0x82, 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00, // IEND chunk
        0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ];
      await imgFile.writeAsBytes(pngBytes);

      final original = ImageLayer(
        id: 'test-123',
        filePath: imgPath,
        position: const Offset(100, 200),
        scale: 1.5,
        opacity: 0.8,
        visible: true,
      );

      final json = original.toJson();

      // 验证图片 Base64 嵌入
      expect(json['imageBase64'], isNotEmpty);

      // 删除原文件，模拟文件丢失场景
      imgFile.deleteSync();

      final restored = ImageLayer.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.position, original.position);
      expect(restored.scale, original.scale);
      expect(restored.opacity, original.opacity);
      expect(restored.visible, original.visible);
      expect(restored.filePath, original.filePath);

      // 文件应该从 Base64 恢复
      expect(File(imgPath).existsSync(), true);

      // 清理
      File(imgPath).deleteSync();
    });

    test('fromJson 处理缺失字段用默认值', () {
      final json = {
        'id': 'minimal',
        'filePath': '/fake/path.png',
        'position': {'dx': 0.0, 'dy': 0.0},
        'scale': 1.0,
        'opacity': 0.6,
        'visible': true,
      };
      final layer = ImageLayer.fromJson(json);
      expect(layer.scale, 1.0);
      expect(layer.opacity, 0.6);
      expect(layer.visible, true);
    });

    test('toJson 文件不存在时不嵌入 Base64', () {
      final layer = ImageLayer(
        id: 'no-file',
        filePath: '/nonexistent/path.png',
      );
      final json = layer.toJson();
      // 文件不存在，不应该有 imageBase64
      expect(json['imageBase64'], isNull);
    });
  });

  group('StrokeData 序列化', () {
    test('toJson → fromJson 往返一致', () {
      final original = const StrokeData(
        points: [Offset(10, 20), Offset(30, 40), Offset(50, 60)],
        color: Colors.blue,
        strokeWidth: 3.5,
      );

      final json = original.toJson();
      final restored = StrokeData.fromJson(json);

      expect(restored.points.length, 3);
      expect(restored.points.first, const Offset(10, 20));
      expect(restored.points.last, const Offset(50, 60));
      expect(restored.color.value, Colors.blue.value);
      expect(restored.strokeWidth, 3.5);
    });

    test('单点笔迹往返', () {
      final original = const StrokeData(
        points: [Offset(5, 5)],
        color: Colors.red,
        strokeWidth: 1.0,
      );
      final json = original.toJson();
      final restored = StrokeData.fromJson(json);

      expect(restored.points.length, 1);
      expect(restored.color.value, Colors.red.value);
    });
  });

  group('CanvasDraft 完整草稿', () {
    test('saveToFile → loadFromFile 往返一致', () async {
      // 准备图片
      final tmpDir = Directory.systemTemp;
      final imgPath = '${tmpDir.path}/test_draft_img.png';
      await File(imgPath).writeAsBytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xD7, 0x63, 0x68, 0x00, 0x00, 0x00,
        0x82, 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final draft = CanvasDraft(
        version: 1,
        transform: [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 100.0, 200.0, 0.0, 1.0],
        strokes: [
          const StrokeData(points: [Offset(0, 0), Offset(50, 50)], color: Colors.black, strokeWidth: 3.0),
          const StrokeData(points: [Offset(10, 10), Offset(20, 20)], color: Colors.red, strokeWidth: 1.5),
        ],
        layers: [
          ImageLayer(id: 'layer-1', filePath: imgPath, position: const Offset(100, 100), scale: 1.0),
        ],
      );

      final draftPath = '${tmpDir.path}/test_draft.json';
      await draft.saveToFile(draftPath);

      final loaded = await CanvasDraft.loadFromFile(draftPath);

      expect(loaded.version, 1);
      expect(loaded.strokes.length, 2);
      expect(loaded.layers.length, 1);
      expect(loaded.transform[12], 100.0); // tx
      expect(loaded.transform[13], 200.0); // ty

      // 清理
      File(draftPath).deleteSync();
      File(imgPath).deleteSync();
    });
  });
}
