import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import '../utils/helpers.dart';

/// 手写/画画画板组件
/// 使用 CustomPaint + GestureDetector 实现手指绘制
/// 支持选择颜色、笔刷粗细，并可保存为图片
class DrawingCanvas extends StatefulWidget {
  /// 绘制完成后的回调，返回保存的图片文件路径
  final Function(String imagePath)? onSave;

  const DrawingCanvas({super.key, this.onSave});

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  /// 全局键，用于将画板渲染为图片
  final GlobalKey _repaintKey = GlobalKey();

  /// 所有绘制路径
  final List<List<Offset>> _paths = <List<Offset>>[];
  /// 每条路径对应的颜色
  final List<Color> _pathColors = <Color>[];
  /// 每条路径对应的笔刷粗细
  final List<double> _pathStrokes = <double>[];

  /// 当前正在绘制的路径点
  List<Offset>? _currentPath;
  /// 当前选中的颜色
  Color _currentColor = Colors.black;
  /// 当前笔刷粗细
  double _currentStroke = 3.0;

  // 预设颜色列表
  static const List<Color> _presetColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Color(0xFFF4A261), // 品牌橙
  ];

  // 预设笔刷粗细
  static const List<double> _presetStrokes = [1.5, 3.0, 5.0, 8.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 工具栏：颜色选择 & 笔刷粗细
        _buildToolbar(),
        const SizedBox(height: 8),
        // 画板区域
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            height: 280,
            width: double.infinity,
            child: RepaintBoundary(
              key: _repaintKey,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: _DrawingPainter(
                    paths: _paths,
                    pathColors: _pathColors,
                    pathStrokes: _pathStrokes,
                    currentPath: _currentPath,
                    currentColor: _currentColor,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 底部操作按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.undo,
              label: '撤销',
              onTap: _undoLastPath,
            ),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: '清空',
              onTap: _clearCanvas,
              color: Colors.red,
            ),
            _buildActionButton(
              icon: Icons.save_alt,
              label: '插入笔记',
              onTap: _saveAsImage,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ],
    );
  }

  /// 构建颜色和笔刷选择工具栏
  Widget _buildToolbar() {
    return Row(
      children: [
        // 颜色选择
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('颜色', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: _presetColors.map((color) {
                  final isSelected = _currentColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _currentColor = color),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey.shade400,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // 笔刷粗细选择
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('粗细', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: _presetStrokes.map((stroke) {
                  final isSelected = _currentStroke == stroke;
                  return GestureDetector(
                    onTap: () => setState(() => _currentStroke = stroke),
                    child: Container(
                      width: 32,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.grey.shade200 : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey.shade400,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Container(
                        width: 20,
                        height: stroke,
                        color: _currentColor,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.grey.shade700, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 手指按下：开始新路径
  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }

  /// 手指移动：添加路径点
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPath?.add(details.localPosition);
    });
  }

  /// 手指抬起：保存当前路径
  void _onPanEnd(DragEndDetails details) {
    if (_currentPath != null && _currentPath!.length > 1) {
      setState(() {
        _paths.add(List.from(_currentPath!));
        _pathColors.add(_currentColor);
        _pathStrokes.add(_currentStroke);
        _currentPath = null;
      });
    } else {
      setState(() {
        _currentPath = null;
      });
    }
  }

  /// 撤销上一条路径
  void _undoLastPath() {
    if (_paths.isNotEmpty) {
      setState(() {
        _paths.removeLast();
        _pathColors.removeLast();
        _pathStrokes.removeLast();
      });
    }
  }

  /// 清空画布
  void _clearCanvas() {
    setState(() {
      _paths.clear();
      _pathColors.clear();
      _pathStrokes.clear();
      _currentPath = null;
    });
  }

  /// 将画布内容保存为图片
  Future<void> _saveAsImage() async {
    try {
      // 获取 RenderRepaintBoundary
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // 渲染为图片
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // 保存到本地文件
      final imagesDir = await Helpers.getImagesDirectory();
      final fileName = 'draw_${Helpers.generateImageFileName()}';
      final filePath = p.join(imagesDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // 回调通知
      widget.onSave?.call(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('手写内容已保存为图片'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存图片失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// 自定义画笔绘制器
class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Color> pathColors;
  final List<double> pathStrokes;
  final List<Offset>? currentPath;
  final Color currentColor;
  final double currentStroke;

  _DrawingPainter({
    required this.paths,
    required this.pathColors,
    required this.pathStrokes,
    required this.currentPath,
    required this.currentColor,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制已保存的路径
    for (int i = 0; i < paths.length; i++) {
      _drawPath(canvas, paths[i], pathColors[i], pathStrokes[i]);
    }
    // 绘制当前正在画的路径
    if (currentPath != null && currentPath!.isNotEmpty) {
      _drawPath(canvas, currentPath!, currentColor, currentStroke);
    }
  }

  void _drawPath(Canvas canvas, List<Offset> points, Color color, double stroke) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
