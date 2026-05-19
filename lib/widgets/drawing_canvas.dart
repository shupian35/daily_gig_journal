import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui show Image, ImageByteFormat, instantiateImageCodec;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../utils/helpers.dart';
import '../utils/constants.dart';

/// 全屏手写/批注画板
/// - 无限画布（双指平移/缩放）
/// - 点阵背景
/// - 导入图片支持拖动/缩放
/// - 裁切功能
class DrawingScreen extends StatefulWidget {
  final void Function(String imagePath, bool includeBackground)? onSave;
  final String? initialBackgroundPath;
  const DrawingScreen({super.key, this.onSave, this.initialBackgroundPath});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  // ---- 画布变换 ----
  Matrix4 _transform = Matrix4.identity();
  Matrix4 _panStartMatrix = Matrix4.identity();
  Offset _panStartFocal = Offset.zero;
  bool _isPanning = false;
  static const double _canvasSize = 4000; // 虚拟画布尺寸

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
  Offset _imagePos = Offset.zero; // 图片在画布上的位置（左上角）
  double _imageScale = 1.0;
  bool _isMovingImage = false; // 是否在移动图片模式
  final ImagePicker _picker = ImagePicker();
  bool _skipBgRender = false;

  // ---- 裁切模式 ----
  bool _isCropping = false;
  Rect? _cropRect;

  // ---- 操作历史（撤销按操作顺序倒序回退）----
  final List<_ActionType> _actionHistory = [];

  // ---- 工具面板 ----
  bool _showTools = true;

  static const List<Color> _presetColors = [
    Colors.black, Colors.red, Colors.blue, Colors.green,
    Colors.orange, Colors.purple, Colors.brown, Color(0xFFF4A261),
  ];
  static const List<double> _presetStrokes = [1.5, 3.0, 5.0, 8.0, 12.0];

  @override
  void initState() {
    super.initState();
    if (widget.initialBackgroundPath != null) {
      final f = File(widget.initialBackgroundPath!);
      if (f.existsSync()) {
        _backgroundImage = f;
        Future.microtask(() => _decodeBackground());
      }
    }
    // 居中画布
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      setState(() {
        _transform = Matrix4.translationValues(
          -(_canvasSize / 2 - screenSize.width / 2),
          -(_canvasSize / 2 - screenSize.height / 2),
          0,
        );
      });
    });
  }

  @override
  void dispose() {
    _cachedImage?.dispose();
    super.dispose();
  }

  // ---------- 背景图 ----------
  Future<void> _importBackground() async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 90,
      );
      if (img != null) {
        _cachedImage?.dispose();
        _cachedImage = null;
        _imageScale = 1.0;
        final viewportCenter = _viewportCenter();
        _imagePos = viewportCenter;
        setState(() {
          _backgroundImage = File(img.path);
          _actionHistory.add(_ActionType.importImage);
        });
        _decodeBackground().then((_) {
          if (_cachedImage != null && mounted) {
            setState(() {
              // 计算适配视口的缩放比例（占视口 80%）
              final screenSize = MediaQuery.of(context).size;
              final viewportSize = _toCanvasSize(screenSize);
              final fitScale = (viewportSize.width * 0.8) / _cachedImage!.width;
              final fitScaleH = (viewportSize.height * 0.8) / _cachedImage!.height;
              _imageScale = fitScale < fitScaleH ? fitScale : fitScaleH;
              if (_imageScale > 1.0) _imageScale = 1.0; // 小图不放大
              if (_imageScale < 0.2) _imageScale = 0.2; // 不小于 Slider 下限
              // 居中放置
              _imagePos = Offset(
                viewportCenter.dx - (_cachedImage!.width * _imageScale) / 2,
                viewportCenter.dy - (_cachedImage!.height * _imageScale) / 2,
              );
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入图片失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 获取当前视口大小（画布坐标系）
  Size _toCanvasSize(Size screenSize) {
    final topLeft = _toCanvasCoords(Offset.zero);
    final bottomRight = _toCanvasCoords(Offset(screenSize.width, screenSize.height));
    return Size((bottomRight.dx - topLeft.dx).abs(), (bottomRight.dy - topLeft.dy).abs());
  }

  /// 获取当前视口中心在画布坐标系中的位置
  Offset _viewportCenter() {
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    return _toCanvasCoords(screenCenter);
  }

  Future<void> _decodeBackground() async {
    if (_backgroundImage == null) return;
    final bytes = await _backgroundImage!.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 2048);
    final frame = await codec.getNextFrame();
    _cachedImage = frame.image;
    if (mounted) setState(() {});
  }

  // ---------- 坐标转换 ----------
  Offset _toCanvasCoords(Offset screenPos) {
    final matrix = Matrix4.inverted(_transform);
    return MatrixUtils.transformPoint(matrix, screenPos);
  }

  // ---------- 手势处理（单指绘画，双指平移/缩放）----------
  void _onScaleStart(ScaleStartDetails details) {
    _panStartMatrix = _transform.clone();
    _panStartFocal = details.focalPoint;

    if (details.pointerCount == 1) {
      _handleDrawStart(details.localFocalPoint);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      _handleDrawUpdate(details.localFocalPoint);
    } else {
      _isPanning = true;
      setState(() {
        _transform = Matrix4.translationValues(
          details.focalPoint.dx - _panStartFocal.dx,
          details.focalPoint.dy - _panStartFocal.dy,
          0,
        )..multiply(_panStartMatrix);
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_isPanning) {
      _handleDrawEnd();
    }
    _isPanning = false;
  }

  // ---------- 绘制 ----------
  void _handleDrawStart(Offset canvasPos) {
    if (_isCropping) {
      _cropRect = Rect.fromCenter(center: canvasPos, width: 0, height: 0);
      setState(() {});
      return;
    }
    if (_isMovingImage) {
      _imagePos = canvasPos;
      setState(() {});
      return;
    }
    setState(() => _currentPath = [canvasPos]);
  }

  void _handleDrawUpdate(Offset canvasPos) {
    if (_isCropping && _cropRect != null) {
      _cropRect = Rect.fromPoints(_cropRect!.topLeft, canvasPos);
      setState(() {});
      return;
    }
    if (_isMovingImage) {
      _imagePos = canvasPos;
      setState(() {});
      return;
    }
    setState(() => _currentPath?.add(canvasPos));
  }

  void _handleDrawEnd() {
    if (_currentPath != null && _currentPath!.length > 1) {
      setState(() {
        _paths.add(List.from(_currentPath!));
        _pathColors.add(_currentColor);
        _pathStrokes.add(_currentStroke);
        _currentPath = null;
        _actionHistory.add(_ActionType.draw);
      });
    } else {
      setState(() => _currentPath = null);
    }
  }

  void _undoLastPath() {
    if (_actionHistory.isEmpty) return;
    final lastAction = _actionHistory.removeLast();
    setState(() {
      switch (lastAction) {
        case _ActionType.draw:
          if (_paths.isNotEmpty) {
            _paths.removeLast();
            _pathColors.removeLast();
            _pathStrokes.removeLast();
          }
        case _ActionType.importImage:
          _removeBackgroundImage();
      }
    });
  }

  void _removeBackgroundImage() {
    setState(() {
      _cachedImage?.dispose();
      _cachedImage = null;
      _backgroundImage = null;
      _imagePos = Offset.zero;
      _imageScale = 1.0;
      _imageOpacity = 0.6;
      _isMovingImage = false;
    });
  }

  void _clearCanvas() {
    setState(() {
      _actionHistory.clear();
      _paths.clear(); _pathColors.clear(); _pathStrokes.clear();
      _currentPath = null;
      _backgroundImage = null; _cachedImage?.dispose(); _cachedImage = null;
      _imageOpacity = 0.6; _imagePos = Offset.zero; _imageScale = 1.0;
      _isMovingImage = false; _isCropping = false; _cropRect = null;
    });
  }

  void _toggleImageMove() {
    setState(() { _isMovingImage = !_isMovingImage; _isCropping = false; _cropRect = null; });
  }

  void _toggleCrop() {
    setState(() { _isCropping = !_isCropping; _isMovingImage = false; _cropRect = null; });
  }

  void _applyCrop() {
    if (_cropRect == null || _cropRect!.isEmpty) return;
    setState(() { _isCropping = false; _cropRect = null; });
  }

  /// 捕获当前视口可见区域的图像（避免渲染全量 4000×4000 画布导致 OOM）
  Future<ui.Image> _captureVisible(RenderRepaintBoundary boundary) async {
    final screenSize = MediaQuery.of(context).size;
    final topLeft = _toCanvasCoords(Offset.zero);
    final viewportRect = Rect.fromLTWH(
      topLeft.dx, topLeft.dy,
      screenSize.width / _getCurrentScale(),
      screenSize.height / _getCurrentScale(),
    );
    // 通过 compositing layer 直接指定捕获区域，避免全画布渲染
    final layer = (boundary as dynamic).debugLayer;
    if (layer != null) {
      return await layer.toImage(viewportRect, pixelRatio: 2.0);
    }
    // 兜底：全画布捕获（低分辨率避免 OOM）
    return await boundary.toImage(pixelRatio: 1.0);
  }

  double _getCurrentScale() {
    return _transform.getMaxScaleOnAxis();
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
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFFF4A261)),
                title: const Text('包含图片和批示'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: const Color(0xFFF4A261).withValues(alpha: 0.08),
                onTap: () { Navigator.pop(ctx); _saveAsImage(includeBackground: true); },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Color(0xFFE07B3E)),
                title: const Text('仅插入批示'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: const Color(0xFFE07B3E).withValues(alpha: 0.08),
                onTap: () { Navigator.pop(ctx); _saveAsImage(includeBackground: false); },
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
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image rendered;
      if (!includeBackground && _backgroundImage != null) {
        _skipBgRender = true; setState(() {});
        await Future.delayed(const Duration(milliseconds: 80));
        rendered = await _captureVisible(boundary);
        _skipBgRender = false; setState(() {});
      } else {
        rendered = await _captureVisible(boundary);
      }

      final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final imagesDir = await Helpers.getImagesDirectory();
      final fileName = 'draw_${Helpers.generateImageFileName()}';
      final filePath = p.join(imagesDir.path, fileName);
      await File(filePath).writeAsBytes(byteData.buffer.asUint8List());

      widget.onSave?.call(filePath, includeBackground);
      if (mounted) Navigator.of(context).pop();
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
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // 无限画布：单指绘画，双指平移/缩放
          Positioned.fill(
            child: ClipRect(
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: _canvasSize,
                  maxWidth: _canvasSize,
                  minHeight: _canvasSize,
                  maxHeight: _canvasSize,
                  child: Transform(
                    transform: _transform,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: CustomPaint(
                        painter: _DrawingPainter(
                          paths: _paths, pathColors: _pathColors, pathStrokes: _pathStrokes,
                          currentPath: _currentPath, currentColor: _currentColor, currentStroke: _currentStroke,
                          backgroundImage: _cachedImage, imageOpacity: _imageOpacity,
                          imagePos: _imagePos, imageScale: _imageScale,
                          skipBg: _skipBgRender, cropRect: _cropRect, isCropping: _isCropping,
                        ),
                        size: const Size(_canvasSize, _canvasSize),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 顶部浮动按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12,
            child: Row(
              children: [
                _floatBtn(Icons.close, () => Navigator.of(context).pop()),
                const Spacer(),
                if (_isCropping)
                  _floatBtn(Icons.crop, _applyCrop, color: Colors.green, size: 36),
                _floatBtn(Icons.check, _onSave, color: const Color(0xFF2E8B57)),
              ],
            ),
          ),

          // 模式提示
          if (_isMovingImage)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                child: const Text('拖动图片到目标位置，再次点击"移动"确认', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          if (_isCropping)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                child: const Text('拖拽选择裁切区域，点击✓确认', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),

          // 底部浮动工具面板
          if (_showTools)
            Positioned(
              left: 16, right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: _buildFloatingToolbar(isDark),
            ),

          // 切换工具栏
          Positioned(
            right: 16,
            bottom: _showTools ? 210 : MediaQuery.of(context).padding.bottom + 16,
            child: _floatBtn(
              _showTools ? Icons.keyboard_arrow_down : Icons.brush,
              () => setState(() => _showTools = !_showTools),
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar(bool isDark) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: isDark ? const Color(0xFF2D2D44) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 颜色
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _presetColors.map((c) => GestureDetector(
                onTap: _isCropping ? null : () => setState(() => _currentColor = c),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentColor == c ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: _currentColor == c ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 4)] : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 10),
            // 笔刷 + 操作
            Row(
              children: [
                ..._presetStrokes.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _currentStroke = s),
                    child: Container(
                      width: 28, height: 28, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentStroke == s ? AppConstants.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                        border: Border.all(color: _currentStroke == s ? AppConstants.primaryColor : Colors.grey.shade300),
                      ),
                      child: Container(width: s * 3, height: s * 3,
                          decoration: BoxDecoration(color: _currentColor, shape: BoxShape.circle)),
                    ),
                  ),
                )),
                const Spacer(),
                _toolBtn(Icons.undo, _undoLastPath, '撤销'),
                const SizedBox(width: 4),
                _toolBtn(Icons.add_photo_alternate, _importBackground, '图片'),
                const SizedBox(width: 4),
                if (_backgroundImage != null) ...[
                  _toolBtn(Icons.open_with, _toggleImageMove, '移动', _isMovingImage ? Colors.orange : null),
                  const SizedBox(width: 4),
                ],
                _toolBtn(Icons.crop, _toggleCrop, '裁切', _isCropping ? Colors.green : null),
                const SizedBox(width: 4),
                _toolBtn(Icons.delete_outline, _clearCanvas, '清空', Colors.red),
              ],
            ),
            if (_backgroundImage != null && !_isMovingImage) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.opacity, size: 16, color: Colors.grey),
                Expanded(child: Slider(value: _imageOpacity, min: 0.1, max: 1.0,
                    onChanged: (v) => setState(() => _imageOpacity = v))),
                Text('${(_imageOpacity * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                // 图片缩放
                const Icon(Icons.zoom_in, size: 14, color: Colors.grey),
                Expanded(child: Slider(value: _imageScale, min: 0.2, max: 3.0,
                    onChanged: (v) => setState(() => _imageScale = v))),
                Text('${(_imageScale * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _floatBtn(IconData icon, VoidCallback onTap, {Color? color, double size = 40}) {
    return Material(
      elevation: 4, shape: const CircleBorder(),
      color: (color ?? Colors.grey.shade800).withValues(alpha: 0.85),
      child: InkWell(
        customBorder: const CircleBorder(), onTap: onTap,
        child: Container(width: size, height: size, alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: size * 0.55)),
      ),
    );
  }

  Widget _toolBtn(IconData icon, VoidCallback onTap, String label, [Color? color]) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color ?? Colors.grey.shade600, size: 20),
        Text(label, style: TextStyle(fontSize: 9, color: color ?? Colors.grey.shade600)),
      ]),
    );
  }
}

// ======================== 操作历史类型 ========================
enum _ActionType { draw, importImage }

// ======================== 画笔 ========================
class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Color> pathColors;
  final List<double> pathStrokes;
  final List<Offset>? currentPath;
  final Color currentColor;
  final double currentStroke;
  final ui.Image? backgroundImage;
  final double imageOpacity;
  final Offset imagePos;
  final double imageScale;
  final bool skipBg;
  final Rect? cropRect;
  final bool isCropping;

  _DrawingPainter({
    required this.paths, required this.pathColors, required this.pathStrokes,
    required this.currentPath, required this.currentColor, required this.currentStroke,
    this.backgroundImage, this.imageOpacity = 0.6,
    this.imagePos = Offset.zero, this.imageScale = 1.0,
    this.skipBg = false, this.cropRect, this.isCropping = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 点阵背景
    _drawDotGrid(canvas, size);

    // 2. 背景图（在指定位置、缩放、透明度）
    if (!skipBg && backgroundImage != null) {
      final srcW = backgroundImage!.width.toDouble();
      final srcH = backgroundImage!.height.toDouble();
      final dstRect = Rect.fromLTWH(
        imagePos.dx, imagePos.dy,
        srcW * imageScale, srcH * imageScale,
      );
      canvas.saveLayer(dstRect, Paint()..color = Colors.white.withValues(alpha: imageOpacity));
      canvas.drawImageRect(backgroundImage!, Rect.fromLTWH(0, 0, srcW, srcH), dstRect, Paint());
      canvas.restore();
    }

    // 3. 路径
    final count = min(paths.length, pathColors.length);
    for (int i = 0; i < count; i++) {
      final stroke = i < pathStrokes.length ? pathStrokes[i] : 3.0;
      _drawSmoothPath(canvas, paths[i], pathColors[i], stroke);
    }
    if (currentPath != null && currentPath!.isNotEmpty) {
      _drawSmoothPath(canvas, currentPath!, currentColor, currentStroke);
    }

    // 4. 裁切框
    if (isCropping && cropRect != null) {
      final p = Paint()
        ..color = Colors.green.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(cropRect!, p);
      final bp = Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawRect(cropRect!, bp);
    }
  }

  /// 点阵背景
  void _drawDotGrid(Canvas canvas, Size size) {
    const spacing = 24.0;
    final paint = Paint()..color = const Color(0x30BDBDBD)..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  void _drawSmoothPath(Canvas canvas, List<Offset> points, Color color, double stroke) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color..strokeWidth = stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset((points[i].dx + points[i + 1].dx) / 2, (points[i].dy + points[i + 1].dy) / 2);
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) => true;
}
