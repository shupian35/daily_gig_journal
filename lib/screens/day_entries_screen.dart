import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_entry.dart';
import '../providers/notes_provider.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import 'note_edit_screen.dart';

/// 单日工作条目列表页 —— 精致杂志风
class DayEntriesScreen extends ConsumerWidget {
  final String dateStr;

  const DayEntriesScreen({super.key, required this.dateStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(notesByDateListProvider(dateStr));
    final displayDate = Helpers.toDisplayDate(dateStr);
    final date = Helpers.parseDate(dateStr);
    final weekday = date != null ? Helpers.getChineseWeekday(date) : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayDate),
              if (weekday.isNotEmpty)
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppConstants.textSecondaryDark
                        : AppConstants.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _navigateToEdit(context, ref, dateStr, null);
          },
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text('添加工作'),
        ),
        body: entriesAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildEntriesList(context, ref, entries);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppConstants.dangerRed.withValues(alpha: 0.08),
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      size: 28, color: AppConstants.dangerRed),
                ),
                const SizedBox(height: 16),
                Text('加载失败: $err',
                    style: const TextStyle(color: AppConstants.dangerRed)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppConstants.primaryColor.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.work_outline_rounded,
              size: 36,
              color: AppConstants.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '当天还没有工作安排',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击下方按钮添加工作',
            style: TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(
    BuildContext context,
    WidgetRef ref,
    List<WorkEntry> entries,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildEntryCard(context, ref, entry, index, entries.length);
      },
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    WidgetRef ref,
    WorkEntry entry,
    int index,
    int total,
  ) {
    final totalWage = entry.dailyWage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = index == total - 1;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: InkWell(
        onTap: () {
          _navigateToEdit(context, ref, dateStr, entry.id);
        },
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 序号指示器
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(
                    color: AppConstants.primaryColor.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppConstants.primaryDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isNotEmpty ? entry.title : '(无标题)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: entry.title.isNotEmpty
                            ? null
                            : AppConstants.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.workLocation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13,
                              color: isDark
                                  ? AppConstants.textSecondaryDark
                                  : AppConstants.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              entry.workLocation,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppConstants.textSecondaryDark
                                    : AppConstants.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (entry.contact.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13,
                              color: isDark
                                  ? AppConstants.textSecondaryDark
                                  : AppConstants.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              entry.contact,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppConstants.textSecondaryDark
                                    : AppConstants.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 13,
                            color: isDark
                                ? AppConstants.textSecondaryDark
                                : AppConstants.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${entry.startTime} - ${entry.endTime}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppConstants.textSecondaryDark
                                : AppConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          Helpers.formatHours(entry.workHours),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppConstants.textSecondaryDark
                                : AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 工资 & 操作
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Helpers.formatCurrency(totalWage),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.incomeGreen,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _confirmDelete(context, ref, entry),
                    borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppConstants.dangerRed.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkEntry entry,
  ) async {
    final displayDate = Helpers.toDisplayDate(entry.date);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除 $displayDate 的\n"${entry.title.isNotEmpty ? entry.title : '(无标题)'}" 吗？\n此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.dangerRed,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(
        deleteNoteProvider((id: entry.id!, date: entry.date)).future,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已删除'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  void _navigateToEdit(
    BuildContext context,
    WidgetRef ref,
    String dateStr,
    int? noteId,
  ) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(dateStr: dateStr, noteId: noteId),
      ),
    )
        .then((_) {
      ref.invalidate(notesByDateListProvider(dateStr));
    });
  }
}
