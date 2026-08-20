import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';

/// 标签输入控件。
///
/// 设计:
///   - 已选 tag 渲染为可删除 chip
///   - 输入框 Enter / "," 提交为新 tag
///   - 顶部"建议标签"行展示 `allTagsProvider` 中未选的 tag(可选),
///     点击即添加
///   - 完全 `ConsumerStatefulWidget` 自管 state,不向外部抛 `ChangedState 通知`,
///     通过 [onChanged] 回写当前 tag 集合(供父组件随表单一起保存)。
class TagsField extends ConsumerStatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onChanged;
  final bool showSuggestions;

  const TagsField({
    super.key,
    required this.initialTags,
    required this.onChanged,
    this.showSuggestions = true,
  });

  @override
  ConsumerState<TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends ConsumerState<TagsField> {
  late List<String> _tags;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _publish() {
    widget.onChanged(List.unmodifiable(_tags));
  }

  void _addTag(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (_tags.contains(t)) {
      _controller.clear();
      return;
    }
    setState(() => _tags.add(t));
    _controller.clear();
    _publish();
  }

  void _removeTag(String t) {
    setState(() => _tags.remove(t));
    _publish();
  }

  void _onSubmitted(String value) {
    // 支持 "a, b, c" 或单个 "a"
    for (final part in value.split(',')) {
      _addTag(part);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTagsAsync = ref.watch(allTagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已选 chip 行
        if (_tags.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l10n.tagsEmpty,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppConstants.textSecondaryDark
                    : AppConstants.textSecondary,
              ),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags
                .map(
                  (t) => Chip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => _removeTag(t),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppConstants.primaryColor.withValues(
                      alpha: isDark ? 0.16 : 0.1,
                    ),
                    side: BorderSide(
                      color: AppConstants.primaryColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSm,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 6),
        // 输入框
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.tagsHint,
            prefixIcon: const Icon(Icons.tag_rounded, size: 18),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: _onSubmitted,
        ),
        // 建议标签(已有 tag 字典中未选的前 N 个)
        if (widget.showSuggestions)
          allTagsAsync.maybeWhen(
            data: (all) {
              final suggestions = all
                  .where((t) => !_tags.contains(t))
                  .take(8)
                  .toList();
              if (suggestions.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tagsSuggestedTags,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppConstants.textSecondaryDark
                            : AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestions
                          .map(
                            (t) => InkWell(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusSm,
                              ),
                              onTap: () => _addTag(t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF3A3A44)
                                      : const Color(0xFFF0EBE4),
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// 展示用 chip 行(只读,用于列表/卡片)。
///
/// 显示前 [maxVisible] 个 tag,超过部分用 `+N` 兜底。
class TagChips extends StatelessWidget {
  final List<String> tags;
  final int maxVisible;

  const TagChips({
    super.key,
    required this.tags,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final visible = tags.take(maxVisible).toList();
    final overflow = tags.length - visible.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visible.map(
          (t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withValues(
                alpha: isDark ? 0.16 : 0.1,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
            ),
            child: Text(
              t,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF3A3A44)
                  : const Color(0xFFF0EBE4),
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
            ),
            child: Text(
              l10n.tagsMoreCount(overflow),
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppConstants.textSecondaryDark
                    : AppConstants.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}