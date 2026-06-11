import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui show Image;
import 'package:flutter/material.dart';

// ======================== 图片图层 ========================
class ImageLayer {
  final String id;
  String filePath;
  Offset position;
  double scale;
  double opacity;
  bool visible;

  /// 运行时解码缓存（不参与序列化）
  ui.Image? cachedImage;

  ImageLayer({
    required this.id,
    required this.filePath,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.opacity = 0.6,
    this.visible = true,
    this.cachedImage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'position': {'dx': position.dx, 'dy': position.dy},
        'scale': scale,
        'opacity': opacity,
        'visible': visible,
      };

  factory ImageLayer.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    return ImageLayer(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      position: Offset(
        (pos?['dx'] as num?)?.toDouble() ?? 0.0,
        (pos?['dy'] as num?)?.toDouble() ?? 0.0,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.6,
      visible: json['visible'] as bool? ?? true,
    );
  }

  void dispose() {
    cachedImage?.dispose();
    cachedImage = null;
  }
}

// ======================== 笔迹数据 ========================
class StrokeData {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const StrokeData({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toJson() => {
        'points':
            points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
      };

  factory StrokeData.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List)
        .map((p) => Offset(
              (p['dx'] as num).toDouble(),
              (p['dy'] as num).toDouble(),
            ))
        .toList();
    return StrokeData(
      points: pts,
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
    );
  }
}

// ======================== 操作历史（Dart 3 sealed class）======================
sealed class CanvasAction {
  const CanvasAction();
}

class DrawAction extends CanvasAction {
  const DrawAction();
}

class AddImageAction extends CanvasAction {
  final String layerId;
  const AddImageAction(this.layerId);
}

class RemoveImageAction extends CanvasAction {
  final ImageLayer removedLayer;
  final int removedIndex;
  const RemoveImageAction(this.removedLayer, this.removedIndex);
}

class ClearAction extends CanvasAction {
  final List<StrokeData> strokes;
  final List<ImageLayer> layers;
  const ClearAction(this.strokes, this.layers);
}

// ======================== 草稿序列化 ========================
class CanvasDraft {
  final int version;
  final List<double> transform;
  final List<StrokeData> strokes;
  final List<ImageLayer> layers;

  const CanvasDraft({
    required this.version,
    required this.transform,
    required this.strokes,
    required this.layers,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'transform': transform,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'layers': layers.map((l) => l.toJson()).toList(),
      };

  factory CanvasDraft.fromJson(Map<String, dynamic> json) {
    return CanvasDraft(
      version: json['version'] as int,
      transform: (json['transform'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      strokes: (json['strokes'] as List)
          .map((e) => StrokeData.fromJson(e as Map<String, dynamic>))
          .toList(),
      layers: (json['layers'] as List)
          .map((e) => ImageLayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> saveToFile(String filePath) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(toJson());
    await File(filePath).writeAsString(jsonStr);
  }

  static Future<CanvasDraft> loadFromFile(String filePath) async {
    final content = await File(filePath).readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return CanvasDraft.fromJson(json);
  }
}
