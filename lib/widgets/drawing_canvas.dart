import 'dart:io';
import 'dart:ui' as ui show Image, ImageByteFormat, instantiateImageCodec;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../utils/helpers.dart';

/// 全屏手写/批注画板页面
///
/// 功能：
/// - 支持手指与手写笔绘制
/// - 导入背景图片并调整透明度
/// - 在图片上做批示和标注
/// - 保存时可选择「含图片插入」或「仅插入批示」
class DrawingScreen extends StatefulWidget {
  final void Function(String imagePath, bool includeBackground)? onSave;

  const DrawingScreen({super.key, this.onSave});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  // ---- 绘制路径 ----
  final List<List<Offset>> _paths = [];
  final List<Color> _pathColors = [];
  final List<double> _pathStrokes = [];
  List<Offset>? _currentPath;
  Color _currentColor = Colors.black;
  double _currentStroke = 3.0;

  // ---- 背景图片 ----
  File? _backgroundImage;
  double _imageOpacity = 0.6;
  ui.Image? _cachedImage;
  final ImagePicker _picker = ImagePicker();

  bool _skipBgRender = false;

  static const List<Color> _presetColors = [
    Colors.black, Colors.red, Colors.blue, Colors.green,
    Colors.orange, Colors.purple, Colors.brown, Color(0xFFF4A261),
  ];

  static const List<double> _presetStrokes = [1.5, 3.0, 5.0, 8.0, 12.0];

  @override
  void dispose() {
    _cachedImage?.dispose();
    super.dispose();
  }

  // ---------- 导入背景图 ----------
  Future<void> _importBackground() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048, maxHeight: 2048, imageQuality: 90,
    );
    if (img != null) {
      _cachedImage?.dispose();
      _cachedImage = null;
      setState(() => _backgroundImage = File(img.path));
      _decodeBackground();
    }
  }

  Future<void> _decodeBackground() async {
    if (_backgroundImage == null) return;
    final bytes = await _backgroundImage!.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 2048);
    final frame = await codec.getNextFrame();
    _cachedImage = frame.image;
    if (mounted) setState(() {});
  }

  // ---------- 绘制事件 ----------
  void _onPanStart(DragStartDetails d) {
    setState(() => _currentPath = [d.localPosition]);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentPath?.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentPath != null && _currentPath!.length > 1) {
      setState(() {
        _paths.add(List.from(_currentPath!));
        _pathColors.add(_currentColor);
        _pathStrokes.add(_currentStroke);
        _currentPath = null;
      });
    } else {
      setState(() => _currentPath = null);
    }
  }

  void _undoLastPath() {
    if (_paths.isNotEmpty) {
      setState(() {
        _paths.removeLast();
        _pathColors.removeLast();
        _pathStrokes.removeLast();
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      _paths.clear();
      _pathColors.clear();
      _pathStrokes.clear();
      _currentPath = null;
      _backgroundImage = null;
      _cachedImage?.dispose();
      _cachedImage = null;
      _imageOpacity = 0.6;
    });
  }

  // ---------- 保存 ----------
  Future<void> _onSave() async {
    if (_backgroundImage != null) {
      _showSaveOptions();
    } else {
      await _saveAsImage(includeBackground: false);
    }
  }

  void _showSaveOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('保存方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('图片上已做批示，请选择保存内容',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFFF4A261)),
                title: const Text('包含图片和批示'),
                subtitle: const Text('将原图与批示合并保存'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: const Color(0xFFF4A261).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveAsImage(includeBackground: true);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Color(0xFFE07B3E)),
                title: const Text('仅插入批示'),
                subtitle: const Text('只保留手写批注，背景透明'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: const Color(0xFFE07B3E).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveAsImage(includeBackground: false);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsImage({required bool includeBackground}) async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image rendered;
      if (!includeBackground && _backgroundImage != null) {
        _skipBgRender = true;
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 80));
        rendered = await boundary.toImage(pixelRatio: 2.0);
        _skipBgRender = false;
        setState(() {});
      } else {
        rendered = await boundary.toImage(pixelRatio: 2.0);
      }

      final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final imagesDir = await Helpers.getImagesDirectory();
      final fileName = 'draw_${Helpers.generateImageFileName()}';
      final filePath = p.join(imagesDir.path, fileName);
      await File(filePath).writeAsBytes(byteData.buffer.asUint8List());

      // 先通知回调，再关闭页面
      widget.onSave?.call(filePath, includeBackground);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('手写/批注'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF2E8B57)),
            tooltip: '完成插入',
            onPressed: _onSave,
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- 背景图操作栏 ----
          _buildImageToolbar(isDark),
          const Divider(height: 1),
          // ---- 画笔工具栏 ----
          _buildPenToolbar(isDark),
          const Divider(height: 1),
          // ---- 画板（占据剩余全部空间） ----
          Expanded(
            child: ClipRRect(
              child: Container(
                color: isDark ? const Color(0xFF2D2D44) : Colors.white,
                width: double.infinity,
                height: double.infinity,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) {
                      _onPanStart(DragStartDetails(
                        globalPosition: e.position,
                        localPosition: e.localPosition,
                      ));
                    },
                    onPointerMove: (e) {
                      _onPanUpdate(DragUpdateDetails(
                        globalPosition: e.position,
                        localPosition: e.localPosition,
                      ));
                    },
                    onPointerUp: (e) {
                      _onPanEnd(DragEndDetails(primaryVelocity: 0));
                    },
                    child: CustomPaint(
                      painter: _DrawingPainter(
                        paths: _paths,
                        pathColors: _pathColors,
                        pathStrokes: _pathStrokes,
                        currentPath: _currentPath,
                        currentColor: _currentColor,
                        currentStroke: _currentStroke,
                        backgroundImage: _cachedImage,
                        imageOpacity: _imageOpacity,
                        skipBg: _skipBgRender,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // ---- 底部操作按钮 ----
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBtn(Icons.undo, '撤销', _undoLastPath),
                _buildBtn(Icons.delete_outline, '清空', _clearCanvas, color: Colors.red),
                _buildBtn(Icons.add_photo_alternate, '导入图片', _importBackground),
                _buildBtn(Icons.save_alt, '插入笔记', _onSave,
                    color: const Color(0xFFF4A261)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageToolbar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.opacity, size: 18, color: Colors.grey),
          const SizedBox(width: 4),
          Text('透明度', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Expanded(
            child: Slider(
              value: _imageOpacity,
              min: 0.1,
              max: 1.0,
              onChanged: _backgroundImage != null
                  ? (v) => setState(() => _imageOpacity = v)
                  : null,
            ),
          ),
          Text('${(_imageOpacity * 100).toInt()}%',
              style: TextStyle(fontSize: 11, color: _backgroundImage != null ? null : Colors.grey)),
          if (_backgroundImage != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: '移除背景',
              onPressed: () {
                _cachedImage?.dispose();
                _cachedImage = null;
                setState(() => _backgroundImage = null);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPenToolbar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('颜色  ', style: TextStyle(fontSize: 12)),
              ..._presetColors.map((c) => GestureDetector(
                    onTap: () => setState(() => _currentColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _currentColor == c ? Colors.black : Colors.grey.shade400,
                          width: _currentColor == c ? 2.5 : 1,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('粗细  ', style: TextStyle(fontSize: 12)),
              ..._presetStrokes.map((s) => GestureDetector(
                    onTap: () => setState(() => _currentStroke = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 32, height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _currentStroke == s ? Colors.grey.shade200 : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _currentStroke == s ? Colors.black : Colors.grey.shade400,
                          width: _currentStroke == s ? 2 : 1,
                        ),
                      ),
                      child: Container(width: 20, height: s, color: _currentColor),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.grey.shade700, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: color ?? Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

// ======================== 自定义画笔（修复版） ========================
class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Color> pathColors;
  final List<double> pathStrokes;
  final List<Offset>? currentPath;
  final Color currentColor;
  final double currentStroke;
  final ui.Image? backgroundImage;
  final double imageOpacity;
  final bool skipBg;

  _DrawingPainter({
    required this.paths,
    required this.pathColors,
    required this.pathStrokes,
    required this.currentPath,
    required this.currentColor,
    required this.currentStroke,
    this.backgroundImage,
    this.imageOpacity = 0.6,
    this.skipBg = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景图（带正确透明度）
    if (!skipBg && backgroundImage != null) {
      final srcRect = Rect.fromLTWH(
        0, 0,
        backgroundImage!.width.toDouble(),
        backgroundImage!.height.toDouble(),
      );
      final fitted = _fit(Size(srcRect.width, srcRect.height), size);
      // 使用 saveLayer 实现真正的图片透明度
      final layerPaint = Paint()..color = Colors.white.withValues(alpha: imageOpacity);
      canvas.saveLayer(fitted, layerPaint);
      canvas.drawImageRect(backgroundImage!, srcRect, fitted, Paint());
      canvas.restore();
    }

    // 2. 绘制已保存路径
    for (int i = 0; i < paths.length; i++) {
      _drawPath(canvas, paths[i], pathColors[i], pathStrokes[i]);
    }
    // 3. 绘制当前路径
    if (currentPath != null && currentPath!.isNotEmpty) {
      _drawPath(canvas, currentPath!, currentColor, currentStroke);
    }
  }

  Rect _fit(Size src, Size dst) {
    final srcAspect = src.width / src.height;
    final dstAspect = dst.width / dst.height;
    double w, h;
    if (srcAspect > dstAspect) {
      w = dst.width;
      h = w / srcAspect;
    } else {
      h = dst.height;
      w = h * srcAspect;
    }
    return Rect.fromCenter(center: dst.center(Offset.zero), width: w, height: h);
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
  bool shouldRepaint(covariant _DrawingPainter old) => true;
}
