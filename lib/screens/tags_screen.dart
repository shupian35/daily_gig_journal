import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_card.dart';

/// 标签管理页 —— 精致杂志风
///
/// 列出所有去重标签及命中条数;支持重命名 / 删除 / 合并。
/// 写入通过 [EntryCoordinator] 触发同一 watch 链路失效（tag 字典刷新 + 搜索结果重算）。
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  bool _working = false;

  Future<void> _rename(String oldName, int count) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tagsRenameDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.tagsRenameLabel,
            hintText: oldName,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.tagsRename),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    setState(() => _working = true);
    try {
      final repo = ref.read(workEntryRepositoryProvider);
      final changed =
          await repo.renameTag(from: oldName, to: newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tagsCount(changed))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _merge(String from, int count) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tagsMerge),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.tagsMergeTargetHint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.tagsMerge),
          ),
        ],
      ),
    );
    if (target == null || target.isEmpty || target == from) return;
    if (!mounted) return; // 跨 async gap 守卫: 避免 dispose 后再使用 context
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tagsMerge),
        content: Text(l10n.tagsMergeConfirm(count, from, target)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.primaryDark,
            ),
            child: Text(l10n.tagsMerge),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final repo = ref.read(workEntryRepositoryProvider);
      await repo.mergeTag(from: from, to: target);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tagsCount(count))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete(String tag, int count) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tagsDelete),
        content: Text(l10n.tagsDeleteConfirm(tag, count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.dangerRed,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final repo = ref.read(workEntryRepositoryProvider);
      await repo.deleteTag(tag);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tagsManage),
      ),
      body: Stack(
        children: [
          allTagsAsync.when(
            data: (tags) {
              if (tags.isEmpty) {
                return Center(
                  child: Text(
                    l10n.tagsEmpty,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppConstants.textSecondaryDark
                          : AppConstants.textSecondary,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return _TagRow(
                    tag: tag,
                    disabled: _working,
                    onRename: (count) => _rename(tag, count),
                    onMerge: (count) => _merge(tag, count),
                    onDelete: (count) => _delete(tag, count),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('${l10n.loadFailed}: $err',
                  style: const TextStyle(color: AppConstants.dangerRed)),
            ),
          ),
          if (_working)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  final String tag;
  final bool disabled;
  final void Function(int count) onRename;
  final void Function(int count) onMerge;
  final void Function(int count) onDelete;
  const _TagRow({
    required this.tag,
    required this.disabled,
    required this.onRename,
    required this.onMerge,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entriesAsync = ref.watch(entriesByTagProvider(tag));
    final count = entriesAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Icon(Icons.tag_rounded,
                  size: 18, color: AppConstants.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0 ? l10n.tagsNoCount : l10n.tagsCount(count),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppConstants.textSecondaryDark
                          : AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.tagsRename,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: disabled ? null : () => onRename(count),
            ),
            IconButton(
              tooltip: l10n.tagsMerge,
              icon: const Icon(Icons.merge_outlined, size: 18),
              onPressed: disabled ? null : () => onMerge(count),
            ),
            IconButton(
              tooltip: l10n.tagsDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppConstants.dangerRed),
              onPressed: disabled ? null : () => onDelete(count),
            ),
          ],
        ),
      ),
    );
  }
}