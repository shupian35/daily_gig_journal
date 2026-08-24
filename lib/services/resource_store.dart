import 'dart:io';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/helpers.dart';
import '../widgets/drawing_data.dart';
import 'backup_service.dart';

/// 资源写入接缝（架构审查候选 A，ADR-0009/0010）。
///
/// 图片/草稿的「落盘 + 变更集上报」收口到此单一深模块：调用方只声明动词
/// （save/remove），目录创建、文件名生成、复制/删除、向
/// [backupChangeSetProvider] 上报均为内部副作用。调用方不再知道
/// 「备份变更集」这件事存在——旧的手写 `BackupService.trackXxx(ref, rel)`
/// 四胞胎已删除，勿再复活。
class ResourceStore {
  final ProviderContainer _container;

  /// 应用文档目录解析器。可注入以便测试指向临时目录。
  final Future<String> Function() _resolveRoot;

  ResourceStore({
    required ProviderContainer container,
    Future<String> Function()? rootResolver,
  })  : _container = container,
        _resolveRoot = rootResolver ?? _defaultRoot;

  static Future<String> _defaultRoot() async =>
      (await getApplicationDocumentsDirectory()).path;

  /// 非 Consumer 上下文（DrawingScreen 用 setState，AGENTS.md 豁免其接入
  /// Riverpod）的唯一入口：containerOf 劫持集中在此一处，不散落调用方。
  static ResourceStore of(BuildContext context) =>
      ProviderScope.containerOf(context).read(resourceStoreProvider);

  BackupChangeSetNotifier get _changes =>
      _container.read(backupChangeSetProvider.notifier);

  Future<Directory> _ensureSubDir(String sub) async {
    final dir = Directory(p.join(await _resolveRoot(), sub));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 复制 [source] 到 images/ 目录，生成 `img_<date>_<rand>.png` 文件名，
  /// 返回相对名 `images/<basename>`（ADR-0009），并上报上传条目。
  Future<String> saveImage(File source) async {
    final dir = await _ensureSubDir(BackupService.imagesSubDir);
    final fileName = 'img_${Helpers.generateImageFileName()}';
    final dest = File(p.join(dir.path, fileName));
    await source.copy(dest.path);
    final rel = '${BackupService.imagesSubDir}/$fileName';
    _changes.markImageUpload(rel);
    return rel;
  }

  /// 删除图片本地文件并上报软删除条目（云端 move 到 trashed/）。
  Future<void> removeImage(String relName) async {
    final abs = p.join(await _resolveRoot(), relName);
    final f = File(abs);
    if (await f.exists()) await f.delete();
    _changes.markImageTrash(relName);
  }

  /// 序列化 [draft] 到 drafts/ 目录，返回相对名 `drafts/<basename>`，
  /// 并上报上传条目。
  Future<String> saveDraft(CanvasDraft draft) async {
    final dir = await _ensureSubDir(BackupService.draftsSubDir);
    final fileName =
        'draft_${Helpers.generateImageFileName().replaceAll('.png', '.json')}';
    final file = File(p.join(dir.path, fileName));
    await draft.saveToFile(file.path);
    final rel = '${BackupService.draftsSubDir}/$fileName';
    _changes.markDraftUpload(rel);
    return rel;
  }

  /// 删除草稿本地文件并上报软删除条目。
  Future<void> removeDraft(String relName) async {
    final abs = p.join(await _resolveRoot(), relName);
    final f = File(abs);
    if (await f.exists()) await f.delete();
    _changes.markDraftTrash(relName);
  }
}

/// 接缝的注入点。Consumer 调用方用 `ref.read(resourceStoreProvider)`；
/// 非 Consumer 上下文走 [ResourceStore.of]。
final resourceStoreProvider = Provider<ResourceStore>((ref) {
  return ResourceStore(container: ref.container);
});
