import 'dart:convert';

import 'package:path/path.dart' as p;

/// Quill Delta 笔记内容中图片相关的纯函数集（架构审查候选 C，ADR-0009）。
///
/// 收敛此前散落三处的同构实现：
/// - 遍历 Delta 收集图片相对名（embed 渲染端 / 编辑屏各一份）
/// - v5→v6 迁移的绝对路径改写（sqlite_work_entry_repository 内一份）
/// - 受管图片 basename 白名单正则与文件名生成格式的人肉同步
///
/// 本模块不做任何 IO、不依赖 Flutter，可被任意层直测。
class NoteDeltaImages {
  NoteDeltaImages._();

  /// 受管图片 basename 规范（ADR-0009）：`img_<YYYY-MM-DD>_<6 位数字>.png`。
  ///
  /// 三段式常量是唯一事实源：
  /// - 白名单正则 [managedImageBasenameRegExp]（v6 迁移只改写命中者）
  /// - 文件名生成器（Helpers.generateImageFileName 引用主体与扩展名片段，
  ///   ResourceStore.saveImage / DrawingCanvas 再加各自前缀）
  static const String managedImagePrefix = 'img_';
  static const String imageDateRandBodyPattern = r'\d{4}-\d{2}-\d{2}_\d{6}';
  static const String managedImageExtension = '.png';

  /// 受管图片 basename 白名单。basename 不命中的绝对路径在 v6 迁移中保留原值
  /// （第三方手改的 JSON 不强行迁移，展示坏图）。
  static final RegExp managedImageBasenameRegExp =
      RegExp('^$managedImagePrefix$imageDateRandBodyPattern\\$managedImageExtension\$');

  /// basename 是否受管（可安全改写为相对名）。
  static bool isManagedImageBasename(String basename) =>
      managedImageBasenameRegExp.hasMatch(basename);

  /// 按「日期_随机数」规范拼接受管图片文件名主体（不含前缀与扩展名）。
  /// [sixDigitRand] 会被补零到 6 位。供 Helpers.generateImageFileName 引用，
  /// 保证生成格式与白名单正则永不漂移。
  static String imageDateRandBody(String datePart, int sixDigitRand) =>
      '${datePart}_${sixDigitRand.toString().padLeft(6, '0')}';

  /// 平台无关 basename：同时切分 / 与 \（Windows 反斜杠路径在非 Windows
  /// 平台上 p.basename 不切分）。
  static String anySepBasename(String path) =>
      path.split(RegExp(r'[/\\]')).last;

  /// 遍历 Delta JSON，按文档顺序收集所有图片嵌入的 image 字段值
  /// （ADR-0009 后约定存相对名 `images/<basename>`）。
  /// 解析失败返回空列表。
  static List<String> collectRelPaths(String deltaJson) {
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is! List) return const [];
      return collectRelPathsFromOps(decoded);
    } catch (_) {
      return const [];
    }
  }

  /// [collectRelPaths] 的已解码 ops 版本（编辑器内存中的 Delta 无需再序列化）。
  static List<String> collectRelPathsFromOps(List<dynamic> ops) {
    final rels = <String>[];
    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is Map && insert.containsKey('image')) {
        final rel = insert['image'];
        if (rel is String) rels.add(rel);
      }
    }
    return rels;
  }

  /// 把 Delta JSON 中 image 字段的绝对路径重写为相对名 `images/<basename>`。
  ///
  /// 仅当 basename 命中 [managedImageBasenameRegExp] 且判定为绝对路径才改写；
  /// 已是相对名 / 纯文件名 / 白名单外路径 / 第三方手改 JSON 一律保留原值。
  /// 无变化返回原文；破损 JSON 原样返回（v5→v6 迁移复用此函数）。
  static String rewriteToRelativePaths(String deltaJson) {
    try {
      final List<dynamic> ops = jsonDecode(deltaJson);
      bool changed = false;
      for (final op in ops) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is! Map) continue;
        if (!insert.containsKey('image')) continue;
        final v = insert['image'];
        if (v is! String) continue;
        // 已经是相对名 → 幂等跳过
        if (v.startsWith('images/')) continue;
        // 判定为绝对路径（常见 Unix 前缀 / Windows 盘符反斜杠）
        final isAbsolute = v.contains('/data/') ||
            v.contains('/storage/') ||
            v.contains('/private/var/') ||
            v.contains('/var/mobile/') ||
            v.contains(r'\');
        if (!isAbsolute) continue;
        final base = anySepBasename(v);
        if (!isManagedImageBasename(base)) continue;
        insert['image'] = 'images/$base';
        changed = true;
      }
      return changed ? jsonEncode(ops) : deltaJson;
    } catch (_) {
      return deltaJson;
    }
  }

  /// Quill Delta JSON → 纯文本。
  ///
  /// 单一实现服务两类消费方（行为差异经参数表达，不再三份拷贝靠注释维系）：
  /// - 搜索（sqlite/in_memory）：默认参数——嵌入对象跳过、不裁剪、
  ///   空/破损/非列表输入返回 ''
  /// - 导出（ExportHelper）：传 [embedPlaceholder] 写入占位符、
  ///   [trimResult] 裁剪首尾、[fallback] 在解析失败时返回原文
  static String deltaToPlainText(
    String deltaJson, {
    String Function(Map<Object?, Object?> insert)? embedPlaceholder,
    bool trimResult = false,
    String? fallback,
  }) {
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is! List) throw const FormatException('not an ops list');
      final buf = StringBuffer();
      for (final op in decoded) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is String) {
          buf.write(insert);
        } else if (insert is Map && embedPlaceholder != null) {
          buf.write(embedPlaceholder(insert));
        }
      }
      final s = buf.toString();
      return trimResult ? s.trim() : s;
    } catch (_) {
      return fallback ?? '';
    }
  }

  /// 图片相对名 → 绝对路径核心（同步纯函数，[docsRoot] 由调用方注入）。
  ///
  /// 已是绝对路径（含盘符反斜杠或以 / 开头）→ 原样返回；
  /// 否则与 docsRoot join。跨设备恢复场景：docsRoot 可能变化，
  /// 但 images/ 子目录结构稳定（ADR-0009 关键不变量）。
  static String imageAbsPathCore(String relPath, String docsRoot) {
    if (relPath.contains(r'\') || relPath.startsWith('/')) {
      return relPath;
    }
    return p.join(docsRoot, relPath);
  }
}
