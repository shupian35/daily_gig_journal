import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_note.dart';
import '../providers/notes_provider.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import 'note_edit_screen.dart';

/// 某一天的工作条目列表页
/// 显示该日期下的所有工作记录，支持添加、编辑、删除
class DayEntriesScreen extends ConsumerWidget {
  /// 目标日期，格式 YYYY-MM-DD
  final String dateStr;

  const DayEntriesScreen({super.key, required this.dateStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(notesByDateListProvider(dateStr));
    final displayDate = Helpers.toDisplayDate(dateStr);
    final date = Helpers.parseDate(dateStr);
    final weekday = date != null ? Helpers.getChineseWeekday(date) : '';

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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _navigateToEdit(context, ref, dateStr, null);
        },
        icon: const Icon(Icons.add),
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
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('加载失败: $err', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    ));
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.work_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '当天还没有工作安排',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加工作',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// 工作条目列表
  Widget _buildEntriesList(
    BuildContext context,
    WidgetRef ref,
    List<WorkNote> entries,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildEntryCard(context, ref, entry, index);
      },
    );
  }

  /// 单个工作条目卡片
  Widget _buildEntryCard(
    BuildContext context,
    WidgetRef ref,
    WorkNote entry,
    int index,
  ) {
    final totalWage = entry.dailyWage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _navigateToEdit(context, ref, dateStr, entry.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 序号
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      entry.title.isNotEmpty ? entry.title : '(无标题)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: entry.title.isNotEmpty
                            ? null
                            : Colors.grey.shade400,
                      ),
                    ),
                    if (entry.workLocation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entry.workLocation,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
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
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.startTime} - ${entry.endTime}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          Helpers.formatHours(entry.workHours),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.incomeGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 删除按钮
                  InkWell(
                    onTap: () => _confirmDelete(context, ref, entry),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade300,
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

  /// 确认删除
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkNote entry,
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
            style: TextButton.styleFrom(foregroundColor: AppConstants.dangerRed),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(deleteNoteProvider((id: entry.id!, date: entry.date)).future);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 导航到编辑页
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
      // 返回后刷新列表
      ref.invalidate(notesByDateListProvider(dateStr));
    });
  }
}
