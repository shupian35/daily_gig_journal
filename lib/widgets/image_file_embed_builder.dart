import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path_provider/path_provider.dart';

import '../utils/constants.dart';
import '../utils/note_delta_images.dart';
import 'image_gallery_viewer.dart';

/// rel→abs 路径解析结果下发（架构审查候选 C，O(N²) 消除）。
///
/// 编辑屏对整个文档只做一次批量解析（单次 docs-root 平台通道调用 + N 次
/// join），把有序相对名与映射经此 InheritedWidget 下发给全部图片 embed；
/// 子组件同步取用，不再各自 resolve 整个画廊。
class ResolvedImagePaths extends InheritedWidget {
  /// 当前文档中全部图片相对名（按文档顺序，用于画廊顺序）。
  final List<String> relPathsInOrder;

  /// rel → abs 映射（尚未解析完成的 rel 不在映射内，子组件显示加载态）。
  final Map<String, String> absByRel;

  const ResolvedImagePaths({
    super.key,
    required this.relPathsInOrder,
    required this.absByRel,
    required super.child,
  });

  static ResolvedImagePaths? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ResolvedImagePaths>();

  @override
  bool updateShouldNotify(ResolvedImagePaths oldWidget) =>
      !mapEquals(absByRel, oldWidget.absByRel) ||
      !listEquals(relPathsInOrder, oldWidget.relPathsInOrder);
}

/// Quill 图片嵌入渲染器
/// 在富文本编辑器中显示图片缩略图，点击可进入全屏画廊
/// ADR-0009：Delta JSON 中 image 字段存相对名 `images/<basename>`，
/// 展示时还原为绝对路径用于 [Image.file]。
/// 上层有 [ResolvedImagePaths] 时直接同步取映射；否则兜底自行异步解析。
class ImageFileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final relPath = embedContext.node.value.data as String;
    final scope = ResolvedImagePaths.maybeOf(context);
    if (scope != null) {
      return _ScopedImageEmbed(
        relPath: relPath,
        galleryRels: scope.relPathsInOrder,
        absByRel: scope.absByRel,
      );
    }
    // 兜底：无 scope 的独立使用场景，按旧行为每个 embed 自行收集+解析
    final allRels = NoteDeltaImages.collectRelPathsFromOps(
      embedContext.controller.document.toDelta().toJson(),
    );
    var idx = allRels.indexOf(relPath);
    if (idx < 0) idx = 0;
    return _LegacyImageEmbed(
      relPath: relPath,
      galleryRels: allRels,
      galleryInitialIndex: idx,
    );
  }
}

/// scoped 模式：路径已由上层批量解析，本 widget 纯同步渲染
class _ScopedImageEmbed extends StatelessWidget {
  final String relPath;
  final List<String> galleryRels;
  final Map<String, String> absByRel;

  const _ScopedImageEmbed({
    required this.relPath,
    required this.galleryRels,
    required this.absByRel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final absPath = absByRel[relPath];
    final present = [
      for (final rel in galleryRels)
        if (absByRel.containsKey(rel)) rel,
    ];
    final gallery = [for (final rel in present) absByRel[rel]!];
    var initialIndex = present.indexOf(relPath);
    if (initialIndex < 0) initialIndex = 0;
    return _ImageEmbedCard(
      isDark: isDark,
      absPath: absPath,
      onTap: gallery.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImageGalleryViewer(
                    images: gallery,
                    initialIndex: initialIndex,
                  ),
                ),
              ),
    );
  }
}

/// 兜底模式：独立使用（无 scope）时保持旧的每 embed 异步解析行为
class _LegacyImageEmbed extends StatefulWidget {
  final String relPath;
  final List<String> galleryRels;
  final int galleryInitialIndex;

  const _LegacyImageEmbed({
    required this.relPath,
    required this.galleryRels,
    required this.galleryInitialIndex,
  });

  @override
  State<_LegacyImageEmbed> createState() => _LegacyImageEmbedState();
}

class _LegacyImageEmbedState extends State<_LegacyImageEmbed> {
  String? _absPath;
  List<String>? _galleryAbsPaths;

  @override
  void initState() {
    super.initState();
    _resolvePaths();
  }

  Future<void> _resolvePaths() async {
    final appDir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    setState(() {
      // 单次取 docs-root 后批量 join（核心已是同步纯函数）
      _absPath =
          NoteDeltaImages.imageAbsPathCore(widget.relPath, appDir.path);
      _galleryAbsPaths = [
        for (final rel in widget.galleryRels)
          NoteDeltaImages.imageAbsPathCore(rel, appDir.path),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ImageEmbedCard(
      isDark: isDark,
      absPath: _absPath,
      onTap: (_galleryAbsPaths == null || _galleryAbsPaths!.isEmpty)
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImageGalleryViewer(
                    images: _galleryAbsPaths!,
                    initialIndex: widget.galleryInitialIndex,
                  ),
                ),
              ),
    );
  }
}

/// 图片嵌入卡片公共渲染：边框容器 + 图片/加载态 + 「点击放大」角标
class _ImageEmbedCard extends StatelessWidget {
  final bool isDark;
  final String? absPath;
  final VoidCallback? onTap;

  const _ImageEmbedCard({
    required this.isDark,
    required this.absPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    isDark ? const Color(0xFF3A3A44) : const Color(0xFFE5DFD8),
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (absPath != null)
                  Image.file(
                    File(absPath!),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_rounded, size: 48),
                  )
                else
                  const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXs),
                    ),
                    child: const Text(
                      '点击放大',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
