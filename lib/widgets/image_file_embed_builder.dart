import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../utils/constants.dart';
import 'image_gallery_viewer.dart';

/// Quill 图片嵌入渲染器
/// 在富文本编辑器中显示图片缩略图，点击可进入全屏画廊
class ImageFileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final path = embedContext.node.value.data as String;
    final allImages = <String>[];
    final currentIndex = collectImages(embedContext, allImages, path);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (allImages.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImageGalleryViewer(
                images: allImages,
                initialIndex: currentIndex,
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
                Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_rounded, size: 48),
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

  /// 从 Quill Delta JSON 中收集所有图片路径
  /// 返回当前图片在列表中的索引
  static int collectImages(
    quill.EmbedContext ctx,
    List<String> out,
    String currentPath,
  ) {
    int idx = 0;
    int foundIdx = -1;
    try {
      final deltaJson = ctx.controller.document.toDelta().toJson();
      for (final op in deltaJson) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          final p = insert['image'] as String;
          out.add(p);
          if (p == currentPath) foundIdx = idx;
          idx++;
        }
      }
    } catch (_) {}
    return foundIdx >= 0 ? foundIdx : 0;
  }
}
