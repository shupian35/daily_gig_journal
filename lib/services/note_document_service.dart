import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path_provider/path_provider.dart';

import '../models/work_entry.dart';
import '../utils/note_delta_images.dart';

/// 笔记 Delta 文档服务（架构审查候选 C）。
///
/// 把 Delta 编解码、图片落盘接缝对接、embed op 删除计算、相对名→绝对路径
/// 批量解析从编辑屏（浅模块）收拢到这一个实例对象。docs-root 解析器可注入，
/// 使路径变换在测试中同步可测；生产构造走默认平台通道。
///
/// 图片落盘不在此自建 copy 逻辑——[insertImageFile] 经 [persist] 回调委托
/// 给资源写入接缝（ResourceStore，ADR-0010 唯一接缝）。
class NoteDocumentService {
  NoteDocumentService({Future<String> Function()? docsRootResolver})
      : _resolveDocsRoot = docsRootResolver ??
            (() async => (await getApplicationDocumentsDirectory()).path);

  final Future<String> Function() _resolveDocsRoot;

  quill.QuillController? _controller;
  List<String>? _relsCache;

  /// 当前绑定的控制器（[load] 之后有效）。
  quill.QuillController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError('NoteDocumentService.load() must be called first');
    }
    return c;
  }

  /// 载入笔记内容（entry 为 null 时重置为空白文档）。
  /// 内部完成旧控制器释放与新控制器装配，并清空缓存。
  void load(WorkEntry? entry) {
    _controller?.dispose();
    final c = _buildController(entry?.noteContent);
    c.addListener(_invalidate);
    _controller = c;
    _relsCache = null;
  }

  quill.QuillController _buildController(String? noteContent) {
    if (noteContent != null && noteContent.isNotEmpty) {
      try {
        return quill.QuillController(
          document: quill.Document.fromJson(jsonDecode(noteContent)),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        // 破损 JSON → 空白文档（与旧编辑屏行为一致）
      }
    }
    return quill.QuillController.basic();
  }

  /// 序列化为持久化用 Delta JSON 字符串。
  String toPersistedJson() => jsonEncode(controller.document.toDelta().toJson());

  /// 当前文档中全部图片相对名（按文档顺序）。缓存式收集：
  /// 仅在控制器变更事件后首次访问时重扫 Delta。
  List<String> imageRels() {
    final cached = _relsCache;
    if (cached != null) return cached;
    final rels =
        NoteDeltaImages.collectRelPathsFromOps(controller.document.toDelta().toJson());
    return _relsCache = List.unmodifiable(rels);
  }

  /// 插入图片文件：经 [persist] 落盘拿到相对名后写入当前光标处。
  /// 返回插入的相对名。persist 生产环境传 ResourceStore.saveImage。
  Future<String> insertImageFile(
    File source, {
    required Future<String> Function(File source) persist,
  }) async {
    final rel = await persist(source);
    final c = controller;
    final selection = c.selection;
    final offset = (selection.isValid && selection.baseOffset >= 0)
        ? selection.baseOffset
        : c.document.length - 1;
    c.replaceText(offset, 0, quill.BlockEmbed.image(rel), null);
    return rel;
  }

  /// 从文档删除指定相对名的图片 embed。返回是否找到并删除。
  ///
  /// 删除长度由 [locateImageRemoval] 精确计算：embed 本身占 1 字符位，
  /// 其后紧跟的换行符一并删除（块级 embed 的行终止符），避免留下空行——
  /// 即旧实现硬编码魔法数 2 的正确来源。
  bool removeImage(String rel) {
    final loc = locateImageRemoval(controller.document.toDelta().toJson(), rel);
    if (loc == null) return false;
    controller.replaceText(loc.$1, loc.$2, '', null);
    return true;
  }

  /// 计算 Delta ops 中目标图片 embed 的文档偏移与应删除长度。
  @visibleForTesting
  static (int, int)? locateImageRemoval(List<dynamic> ops, String relPath) {
    int offset = 0;
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final insert = op is Map ? op['insert'] : null;
      if (insert is Map && insert['image'] == relPath) {
        var len = 1; // embed 占 1 个字符位
        if (i + 1 < ops.length) {
          final nextIns = ops[i + 1] is Map ? ops[i + 1]['insert'] : null;
          if (nextIns is String && nextIns.startsWith('\n')) len++;
        }
        return (offset, len);
      }
      offset += insert is String ? insert.length : 1;
    }
    return null;
  }

  /// 批量解析 rel→abs 映射：单次 docs-root 解析 + N 次 join，
  /// 消除每个 embed 各自 resolve 的 O(N²) 平台通道调用。
  Future<Map<String, String>> resolveAbsPaths([List<String>? rels]) async {
    final list = rels ?? imageRels();
    final root = await _resolveDocsRoot();
    return {
      for (final r in list) r: NoteDeltaImages.imageAbsPathCore(r, root),
    };
  }

  /// 单个相对名 → 绝对路径（复用批量核心，一次 root 解析）。
  Future<String> imageAbsPath(String rel) =>
      resolveAbsPaths([rel]).then((m) => m[rel]!);

  void _invalidate() => _relsCache = null;

  /// 释放内部控制器。
  Future<void> dispose() async {
    _controller?.removeListener(_invalidate);
    _controller?.dispose();
    _controller = null;
  }
}
