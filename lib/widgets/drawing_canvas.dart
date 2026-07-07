import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui show Image, ImageByteFormat, instantiateImageCodec;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import 'drawing_data.dart';

/// 全屏手写/批注画板
/// - 无限画布（双指平移/缩放）
/// - 点阵背景
/// - 多图层：多张参考图片 + 笔迹层分离
/// - 草稿保存/恢复
/// - 裁切导出
class DrawingScreen extends StatefulWidget {
  final void Function(String imagePath, bool includeBackground)? onSave;
  final String? initialBackgroundPath;
  final CanvasDraft? initialDraft;
  const DrawingScreen({super.key, this.onSave, this.initialBackgroundPath, this.initialDraft});

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
  static const double _canvasSize = 4000;

  // ---- 笔迹 ----
  final List<StrokeData> _strokes = [];
  List<Offset>? _currentPath;
  Color _currentColor = Colors.black;
  double _currentStroke = 3.0;

  // ---- 图片图层 ----
  final List<ImageLayer> _imageLayers = [];
  String? _selectedLayerId;
  bool _isMovingSelectedLayer = false;
  final ImagePicker _picker = ImagePicker();
  bool _hideAllImages = false; // "仅插入批示"保存时临时隐藏

  // ---- 裁切 ----
  bool _isCropping = false;
  Rect? _cropRect;
  bool _cropTriggerSave = false; // 裁切确认后触发保存

  // ---- 操作历史 ----
  final List<CanvasAction> _actionHistory = [];

  // ---- 草稿 ----

  // ---- 工具面板 ----
  bool _showTools = true;

  static const List<Color> _presetColors = [
    Colors.black, Colors.red, Colors.blue, Colors.green,
    Colors.orange, Colors.purple, Colors.brown, Color(0xFFC8895A),
  ];
  static const List<double> _presetStrokes = [1.5, 3.0, 5.0, 8.0, 12.0];

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft != null) {
      _restoreFromDraft(widget.initialDraft!);
    } else if (widget.initialBackgroundPath != null) {
      final f = File(widget.initialBackgroundPath!);
      if (f.existsSync()) {
        final layer = _makeLayer(f.path);
        _imageLayers.add(layer);
        _actionHistory.add(AddImageAction(layer.id));
        _selectedLayerId = layer.id;
        Future.microtask(() => _decodeLayerImage(layer));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDraft == null) {
        final screenSize = MediaQuery.of(context).size;
        setState(() {
          _transform = Matrix4.translationValues(
            -(_canvasSize / 2 - screenSize.width / 2),
            -(_canvasSize / 2 - screenSize.height / 2),
            0,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    for (final layer in _imageLayers) {
      layer.dispose();
    }
    super.dispose();
  }

  void _restoreFromDraft(CanvasDraft draft) {
    _transform = Matrix4.fromFloat64List(
        Float64List.fromList(draft.transform));
    _strokes.addAll(draft.strokes);
    _imageLayers.addAll(draft.layers);
    _actionHistory.clear();
    String? firstVisibleId;
    for (final layer in draft.layers) {
      firstVisibleId ??= layer.id;
      if (File(layer.filePath).existsSync()) {
        _decodeLayerImage(layer);
      }
    }
    _selectedLayerId = firstVisibleId;
    setState(() {});
  }

  ImageLayer _makeLayer(String filePath) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return ImageLayer(id: id, filePath: filePath);
  }

  // ======================== 图片导入 & 解码 ========================
  Future<void> _importImage() async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 90,
      );
      if (img == null) return;

      final layer = _makeLayer(img.path);
      final viewportCenter = _viewportCenter();
      layer.position = viewportCenter;
      layer.scale = 1.0;
      setState(() {
        _imageLayers.add(layer);
        _selectedLayerId = layer.id;
        _actionHistory.add(AddImageAction(layer.id));
      });

      _decodeLayerImage(layer).then((_) {
        if (!mounted) return;
        final vpCenter = _viewportCenter();
        setState(() {
          final screenSize = MediaQuery.of(context).size;
          final vpSize = _toCanvasSize(screenSize);
          final fitW = (vpSize.width * 0.8) / (layer.cachedImage?.width ?? 1);
          final fitH = (vpSize.height * 0.8) / (layer.cachedImage?.height ?? 1);
          layer.scale = min(fitW, fitH);
          if (layer.scale > 1.0) layer.scale = 1.0;
          if (layer.scale < 0.2) layer.scale = 0.2;
          final imgW = (layer.cachedImage?.width ?? 0) * layer.scale;
          final imgH = (layer.cachedImage?.height ?? 0) * layer.scale;
          layer.position = Offset(vpCenter.dx - imgW / 2, vpCenter.dy - imgH / 2);
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.importImageFailed}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _decodeLayerImage(ImageLayer layer) async {
    final file = File(layer.filePath);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 2048);
    final frame = await codec.getNextFrame();
    layer.cachedImage?.dispose();
    layer.cachedImage = frame.image;
    if (mounted) setState(() {});
  }

  // ======================== 选择图层 ========================
  ImageLayer? get _selectedLayer {
    if (_selectedLayerId == null) return null;
    try {
      return _imageLayers.firstWhere((l) => l.id == _selectedLayerId);
    } catch (_) {
      return null;
    }
  }

  // ======================== 坐标转换 ========================
  Size _toCanvasSize(Size screenSize) {
    final topLeft = _toCanvasCoords(Offset.zero);
    final bottomRight = _toCanvasCoords(Offset(screenSize.width, screenSize.height));
    return Size((bottomRight.dx - topLeft.dx).abs(), (bottomRight.dy - topLeft.dy).abs());
  }

  Offset _viewportCenter() {
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    return _toCanvasCoords(screenCenter);
  }

  Offset _toCanvasCoords(Offset screenPos) {
    final matrix = Matrix4.inverted(_transform);
    return MatrixUtils.transformPoint(matrix, screenPos);
  }

  double _getCurrentScale() => _transform.getMaxScaleOnAxis();

  // ======================== 手势处理 ========================
  void _onScaleStart(ScaleStartDetails details) {
    _panStartMatrix = _transform.clone();
    _panStartFocal = details.focalPoint;
    if (details.pointerCount == 1) {
      _handleDrawStart(_toCanvasCoords(details.localFocalPoint));
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      _handleDrawUpdate(_toCanvasCoords(details.localFocalPoint));
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

  // ======================== 绘画处理 ========================
  void _handleDrawStart(Offset canvasPos) {
    if (_isCropping) {
      _cropRect = Rect.fromCenter(center: canvasPos, width: 0, height: 0);
      setState(() {});
      return;
    }
    if (_isMovingSelectedLayer && _selectedLayer != null) {
      _selectedLayer!.position = canvasPos;
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
    if (_isMovingSelectedLayer && _selectedLayer != null) {
      _selectedLayer!.position = canvasPos;
      setState(() {});
      return;
    }
    setState(() => _currentPath?.add(canvasPos));
  }

  void _handleDrawEnd() {
    if (_currentPath != null && _currentPath!.length > 1) {
      setState(() {
        _strokes.add(StrokeData(
          points: List.from(_currentPath!),
          color: _currentColor,
          strokeWidth: _currentStroke,
        ));
        _currentPath = null;
        _actionHistory.add(const DrawAction());
      });
    } else {
      setState(() => _currentPath = null);
    }
  }

  // ======================== 撤销 ========================
  void _undoLastPath() {
    if (_actionHistory.isEmpty) return;
    final action = _actionHistory.removeLast();
    setState(() {
      if (action is DrawAction) {
        if (_strokes.isNotEmpty) _strokes.removeLast();
      } else if (action is AddImageAction) {
        _removeLayerById(action.layerId);
      } else if (action is RemoveImageAction) {
        _imageLayers.insert(action.removedIndex, action.removedLayer);
        _decodeLayerImage(action.removedLayer);
      } else if (action is ClearAction) {
        _strokes.clear();
        for (final l in _imageLayers) { l.dispose(); }
        _imageLayers.clear();
        _strokes.addAll(action.strokes);
        for (final l in action.layers) {
          _imageLayers.add(l);
          _decodeLayerImage(l);
        }
      }
    });
  }

  void _removeLayerById(String id) {
    final idx = _imageLayers.indexWhere((l) => l.id == id);
    if (idx == -1) return;
    final removed = _imageLayers.removeAt(idx);
    removed.dispose();
    if (_selectedLayerId == id) {
      _selectedLayerId = _imageLayers.isNotEmpty ? _imageLayers.last.id : null;
    }
  }

  // ======================== 图层删除 ========================
  void _deleteSelectedLayer() {
    final layer = _selectedLayer;
    if (layer == null) return;
    final idx = _imageLayers.indexWhere((l) => l.id == layer.id);
    setState(() {
      _imageLayers.removeAt(idx);
      _actionHistory.add(RemoveImageAction(layer, idx));
      if (_selectedLayerId == layer.id) {
        _selectedLayerId = _imageLayers.isNotEmpty ? _imageLayers.last.id : null;
      }
    });
  }

  // ======================== 清空 ========================
  void _clearCanvas() {
    setState(() {
      _actionHistory.add(ClearAction(
        _strokes.toList(),
        _imageLayers.map((l) => ImageLayer(
          id: l.id, filePath: l.filePath,
          position: l.position, scale: l.scale,
          opacity: l.opacity, visible: l.visible,
        )).toList(),
      ));
      _strokes.clear();
      _currentPath = null;
      for (final l in _imageLayers) { l.dispose(); }
      _imageLayers.clear();
      _selectedLayerId = null;
      _isMovingSelectedLayer = false;
      _isCropping = false;
      _cropRect = null;
    });
  }

  void _toggleImageMove() {
    setState(() {
      _isMovingSelectedLayer = !_isMovingSelectedLayer;
      _isCropping = false;
      _cropRect = null;
    });
  }

  void _toggleCrop() {
    setState(() {
      _isCropping = !_isCropping;
      _isMovingSelectedLayer = false;
      _cropRect = null;
    });
  }

  void _applyCrop() {
    if (_cropRect == null || _cropRect!.isEmpty) return;
    _cropTriggerSave = true;
    setState(() { _isCropping = false; });
    _onSave();
  }

  // ======================== 草稿 ========================
  Future<void> _saveDraft() async {
    try {
      final draft = CanvasDraft(
        version: 1,
        transform: _transform.storage.toList(),
        strokes: _strokes.toList(),
        layers: _imageLayers.toList(),
      );
      final draftsDir = await _getDraftsDir();
      final fileName = 'draft_${Helpers.generateImageFileName().replaceAll('.png', '.json')}';
      final filePath = p.join(draftsDir.path, fileName);
      await draft.saveToFile(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.draftSaved), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.saveDraftFailed}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      final draftsDir = await _getDraftsDir();
      final result = await FilePicker.pickFiles(
        initialDirectory: draftsDir.path,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final draft = await CanvasDraft.loadFromFile(result.files.single.path!);

      // 清空当前状态
      for (final l in _imageLayers) { l.dispose(); }
      _imageLayers.clear();
      _strokes.clear();
      _actionHistory.clear();

      _restoreFromDraft(draft);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.draftLoaded), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.loadDraftFailed}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Directory> _getDraftsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'drafts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ======================== 保存 ========================
  Future<void> _onSave() async {
    if (_imageLayers.any((l) => l.cachedImage != null)) {
      _showSaveOptions();
    } else {
      await _saveAsImage(showImages: _cropTriggerSave);
    }
  }

  void _showSaveOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.saveMethod, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image, color: AppConstants.primaryColor),
                title: Text(l10n.saveWithImage),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                tileColor: AppConstants.primaryColor.withValues(alpha: 0.08),
                onTap: () { Navigator.pop(ctx); _saveAsImage(showImages: true); },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_note, color: AppConstants.primaryDark),
                title: Text(l10n.saveAnnotationOnly),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                tileColor: AppConstants.primaryDark.withValues(alpha: 0.08),
                onTap: () { Navigator.pop(ctx); _saveAsImage(showImages: false); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsImage({required bool showImages}) async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      if (!showImages && _imageLayers.isNotEmpty) {
        _hideAllImages = true; setState(() {});
        await Future.delayed(const Duration(milliseconds: 80));
      }

      ui.Image rendered;
      if (_cropTriggerSave && _cropRect != null) {
        rendered = await _captureRegion(boundary, _cropRect!);
        _cropRect = null;
        _cropTriggerSave = false;
      } else {
        rendered = await _captureVisible(boundary);
      }

      if (!showImages && _imageLayers.isNotEmpty) {
        _hideAllImages = false; setState(() {});
      }

      final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final imagesDir = await Helpers.getImagesDirectory();
      final fileName = 'draw_${Helpers.generateImageFileName()}';
      final filePath = p.join(imagesDir.path, fileName);
      await File(filePath).writeAsBytes(byteData.buffer.asUint8List());

      widget.onSave?.call(filePath, showImages);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.saveFailedCanvas}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<ui.Image> _captureVisible(RenderRepaintBoundary boundary) async {
    final screenSize = MediaQuery.of(context).size;
    final topLeft = _toCanvasCoords(Offset.zero);
    final viewportRect = Rect.fromLTWH(
      topLeft.dx, topLeft.dy,
      screenSize.width / _getCurrentScale(),
      screenSize.height / _getCurrentScale(),
    );
    final layer = (boundary as dynamic).debugLayer;
    if (layer != null) {
      return await layer.toImage(viewportRect, pixelRatio: 2.0);
    }
    return await boundary.toImage(pixelRatio: 1.0);
  }

  Future<ui.Image> _captureRegion(RenderRepaintBoundary boundary, Rect region) async {
    final layer = (boundary as dynamic).debugLayer;
    if (layer != null) {
      return await layer.toImage(region, pixelRatio: 2.0);
    }
    return await boundary.toImage(pixelRatio: 1.0);
  }

  // ======================== 图层面板 ========================
  void _showLayerPanel() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.45,
              maxChildSize: 0.8,
              minChildSize: 0.3,
              expand: false,
              builder: (ctx, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(l10n.layerPanel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _importImage();
                              Navigator.pop(ctx);
                            },
                            child: Text(l10n.addPhoto),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (_imageLayers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(l10n.noLayers, style: TextStyle(color: Colors.grey.shade400)),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollCtrl,
                            itemCount: _imageLayers.length,
                            itemBuilder: (_, i) {
                              final layer = _imageLayers[i];
                              final isSelected = layer.id == _selectedLayerId;
                              final fileName = p.basenameWithoutExtension(layer.filePath);
                              return Card(
                                elevation: isSelected ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 48, height: 48,
                                      color: Colors.grey.shade200,
                                      child: File(layer.filePath).existsSync()
                                          ? Image.file(File(layer.filePath), fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24))
                                          : const Icon(Icons.broken_image, size: 24),
                                    ),
                                  ),
                                  title: Text(fileName, style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setSheetState(() => layer.visible = !layer.visible);
                                          setState(() {});
                                        },
                                        child: Icon(
                                          layer.visible ? Icons.visibility : Icons.visibility_off,
                                          size: 20,
                                          color: layer.visible ? Colors.grey.shade600 : Colors.grey.shade300,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _deleteSelectedLayer();
                                        },
                                        child: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    setSheetState(() => _selectedLayerId = layer.id);
                                    setState(() => _selectedLayerId = layer.id);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ======================== UI ========================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppConstants.bgDark : AppConstants.bgLight,
      body: Stack(
        children: [
          // 画布
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
                          strokes: _strokes,
                          imageLayers: _imageLayers,
                          hideAllImages: _hideAllImages,
                          currentPath: _currentPath,
                          currentColor: _currentColor,
                          currentStroke: _currentStroke,
                          cropRect: _cropRect,
                          isCropping: _isCropping,
                        ),
                        size: const Size(_canvasSize, _canvasSize),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 顶部按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12,
            child: Row(
              children: [
                _floatBtn(Icons.close, () => Navigator.of(context).pop()),
                const SizedBox(width: 8),
                _floatBtn(Icons.folder_open, _loadDraft, size: 34),
                const SizedBox(width: 6),
                _floatBtn(Icons.save_outlined, _saveDraft, size: 34),
                const Spacer(),
                if (_isCropping)
                  _floatBtn(Icons.crop, _applyCrop, color: Colors.green, size: 36),
                _floatBtn(Icons.check, _onSave, color: const Color(0xFF2E8B57)),
              ],
            ),
          ),

          // 模式提示
          if (_isMovingSelectedLayer)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppConstants.primaryColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
                child: Text(l10n.moveModeHint, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          if (_isCropping)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                child: Text(l10n.cropModeHint, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),

          // 底部工具栏
          if (_showTools)
            Positioned(
              left: 16, right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: _buildFloatingToolbar(isDark),
            ),

          // 工具栏切换
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
    final l10n = AppLocalizations.of(context)!;
    final selLayer = _selectedLayer;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      color: isDark ? const Color(0xFF262630) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: isDark ? Colors.black54 : const Color(0x1A8D7E76),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
            width: 0.5,
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
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
                _toolBtn(Icons.undo, _undoLastPath, l10n.undo),
                const SizedBox(width: 4),
                _toolBtn(Icons.add_photo_alternate, _importImage, l10n.imageTool),
                const SizedBox(width: 4),
                if (_imageLayers.isNotEmpty) ...[
                  _toolBtn(Icons.layers, _showLayerPanel, l10n.layerTool, _imageLayers.length > 1 ? AppConstants.primaryDark : null),
                  const SizedBox(width: 4),
                ],
                if (selLayer != null) ...[
                  _toolBtn(Icons.open_with, _toggleImageMove, l10n.moveTool, _isMovingSelectedLayer ? Colors.orange : null),
                  const SizedBox(width: 4),
                ],
                _toolBtn(Icons.crop, _toggleCrop, l10n.cropTool, _isCropping ? Colors.green : null),
                const SizedBox(width: 4),
                _toolBtn(Icons.delete_outline, _clearCanvas, l10n.clearTool, Colors.red),
              ],
            ),
            // 选中图层的透明度 & 缩放滑块
            if (selLayer != null && !_isMovingSelectedLayer) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.opacity, size: 16, color: Colors.grey),
                Expanded(child: Slider(value: selLayer.opacity, min: 0.1, max: 1.0,
                    onChanged: (v) => setState(() => selLayer.opacity = v))),
                Text('${(selLayer.opacity * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                const Icon(Icons.zoom_in, size: 14, color: Colors.grey),
                Expanded(child: Slider(value: selLayer.scale, min: 0.2, max: 3.0,
                    onChanged: (v) => setState(() => selLayer.scale = v))),
                Text('${(selLayer.scale * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
              ]),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _floatBtn(IconData icon, VoidCallback onTap, {Color? color, double size = 40}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: (color ?? (isDark ? const Color(0xFF3A3A44) : const Color(0xFF4A4440)))
          .withValues(alpha: 0.9),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: size * 0.55),
        ),
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

// ======================== 画笔 ========================
class _DrawingPainter extends CustomPainter {
  final List<StrokeData> strokes;
  final List<ImageLayer> imageLayers;
  final bool hideAllImages;
  final List<Offset>? currentPath;
  final Color currentColor;
  final double currentStroke;
  final Rect? cropRect;
  final bool isCropping;

  _DrawingPainter({
    required this.strokes,
    required this.imageLayers,
    required this.hideAllImages,
    required this.currentPath,
    required this.currentColor,
    required this.currentStroke,
    this.cropRect,
    this.isCropping = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 点阵背景
    _drawDotGrid(canvas, size);

    // 2. 图片图层（按添加顺序，底部先渲染）
    if (!hideAllImages) {
      for (final layer in imageLayers) {
        if (!layer.visible) continue;
        final img = layer.cachedImage;
        if (img == null) continue;
        final srcW = img.width.toDouble();
        final srcH = img.height.toDouble();
        final dstRect = Rect.fromLTWH(
          layer.position.dx, layer.position.dy,
          srcW * layer.scale, srcH * layer.scale,
        );
        canvas.saveLayer(dstRect,
            Paint()..color = Colors.white.withValues(alpha: layer.opacity));
        canvas.drawImageRect(
            img, Rect.fromLTWH(0, 0, srcW, srcH), dstRect, Paint());
        canvas.restore();
      }
    }

    // 3. 已完成的笔迹
    for (final s in strokes) {
      _drawSmoothPath(canvas, s.points, s.color, s.strokeWidth);
    }

    // 4. 当前进行中的笔迹
    if (currentPath != null && currentPath!.isNotEmpty) {
      _drawSmoothPath(canvas, currentPath!, currentColor, currentStroke);
    }

    // 5. 裁切框
    if (isCropping && cropRect != null) {
      final p = Paint()
        ..color = Colors.green.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(cropRect!, p);
      final bp = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(cropRect!, bp);
    }
  }

  void _drawDotGrid(Canvas canvas, Size size) {
    const spacing = 24.0;
    final paint = Paint()
      ..color = const Color(0x30BDBDBD)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  void _drawSmoothPath(Canvas canvas, List<Offset> points, Color color, double stroke) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) => true;
}
