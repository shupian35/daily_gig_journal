import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'image_gallery_viewer.dart';

/// Quill 图片嵌入渲染器
/// 在富文本编辑器中显示图片缩略图，点击可进入全屏画廊
/// ADR-0009：Delta JSON 中 image 字段存相对名 `images/<basename>`，
/// build 时通过 [Helpers.imageAbsPath] 还原为绝对路径用于 [Image.file]。
class ImageFileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final relPath = embedContext.node.value.data as String;
    final allRels = <String>[];
    final currentIndex = collectImages(embedContext, allRels, relPath);
    return _ResolvedImageEmbed(
      relPath: relPath,
      galleryRels: allRels,
      galleryInitialIndex: currentIndex,
    );
  }

  /// 从 Quill Delta JSON 中收集所有图片相对名（ADR-0009 后约定）
  /// 返回当前图片在列表中的索引
  static int collectImages(
    quill.EmbedContext ctx,
    List<String> out,
    String currentRelPath,
  ) {
    int idx = 0;
    int foundIdx = -1;
    try {
      final deltaJson = ctx.controller.document.toDelta().toJson();
      for (final op in deltaJson) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          final rel = insert['image'] as String;
          out.add(rel);
          if (rel == currentRelPath) foundIdx = idx;
          idx++;
        }
      }
    } catch (_) {}
    return foundIdx >= 0 ? foundIdx : 0;
  }
}

/// 图片嵌入渲染子 widget
/// initState 时把 relPath + galleryRels 转绝对路径（async），build 时显示图片
class _ResolvedImageEmbed extends StatefulWidget {
  final String relPath;
  final List<String> galleryRels;
  final int galleryInitialIndex;

  const _ResolvedImageEmbed({
    required this.relPath,
    required this.galleryRels,
    required this.galleryInitialIndex,
  });

  @override
  State<_ResolvedImageEmbed> createState() => _ResolvedImageEmbedState();
}

class _ResolvedImageEmbedState extends State<_ResolvedImageEmbed> {
  String? _absPath;
  List<String>? _galleryAbsPaths;

  @override
  void initState() {
    super.initState();
    _resolvePaths();
  }

  Future<void> _resolvePaths() async {
    final abs = <String>[];
    for (final rel in widget.galleryRels) {
      abs.add(await Helpers.imageAbsPath(rel));
    }
    if (!mounted) return;
    setState(() {
      _galleryAbsPaths = abs;
      _absPath = abs[widget.galleryInitialIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final absPath = _absPath;
    final gallery = _galleryAbsPaths;
    return GestureDetector(
      onTap: () {
        if (gallery != null && gallery.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImageGalleryViewer(
                images: gallery,
                initialIndex: widget.galleryInitialIndex,
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFE5DFD8),
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (absPath != null)
                  Image.file(
                    File(absPath),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(AppConstants.radiusXs),
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
