import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/work_entry.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/app_card.dart';
import '../widgets/tags_field.dart';
import 'note_edit_screen.dart';

/// 全局搜索页 —— 精致杂志风
///
/// 入口：日历 AppBar 的搜索 IconButton。
/// 关键词变更使用 200ms debounce 写到 [searchKeywordProvider]；
/// tag 与日期范围立即生效。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _keywordController = TextEditingController();
  final FocusNode _keywordFocus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 同步已存在的 state（典型场景：从搜索跳出去又回来，关键词还在）
    final existing = ref.read(searchKeywordProvider);
    if (existing.isNotEmpty) {
      _keywordController.text = existing;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keywordFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keywordController.dispose();
    _keywordFocus.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ref.read(searchKeywordProvider.notifier).state = value;
    });
  }

  void _clearAll() {
    _keywordController.clear();
    _debounce?.cancel();
    ref.read(searchKeywordProvider.notifier).state = '';
    ref.read(searchDateRangeProvider.notifier).state = (from: null, to: null);
    ref.read(searchTagFilterProvider.notifier).state = null;
  }

  Future<void> _pickDateRange() async {
    final range = ref.read(searchDateRangeProvider);
    final initialFrom = range.from ?? DateTime.now();
    final initialTo = range.to ?? DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: initialFrom, end: initialTo),
    );
    if (picked != null) {
      ref.read(searchDateRangeProvider.notifier).state =
          (from: picked.start, to: picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final hideIncome = ref.watch(hideIncomeProvider);
    final allTagsAsync = ref.watch(allTagsProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final range = ref.watch(searchDateRangeProvider);
    final tagFilter = ref.watch(searchTagFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.searchClearFilters,
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 搜索框 + 筛选条 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _keywordController,
              focusNode: _keywordFocus,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _keywordController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _keywordController.clear();
                          _onKeywordChanged('');
                        },
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: _onKeywordChanged,
              textInputAction: TextInputAction.search,
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // 日期范围筛选 chip
                _FilterChipPill(
                  label: range.from == null && range.to == null
                      ? l10n.searchDateRangeAll
                      : '${Helpers.toDisplayDate(_formatDate(range.from!), locale)} ~ ${Helpers.toDisplayDate(_formatDate(range.to!), locale)}',
                  selected: range.from != null,
                  onTap: _pickDateRange,
                  icon: Icons.event_rounded,
                ),
                const SizedBox(width: 6),
                // tag 筛选 chip：所有 tag
                allTagsAsync.maybeWhen(
                  data: (tags) => Row(
                    children: [
                      _FilterChipPill(
                        label: l10n.searchFilterAllTags,
                        selected: tagFilter == null,
                        onTap: () => ref
                            .read(searchTagFilterProvider.notifier)
                            .state = null,
                      ),
                      const SizedBox(width: 6),
                      ...tags.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterChipPill(
                            label: t,
                            selected: tagFilter == t,
                            onTap: () => ref
                                .read(searchTagFilterProvider.notifier)
                                .state = t,
                          ),
                        ),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 0.5),
          // ── 结果 ──
          Expanded(
            child: resultsAsync.when(
              data: (list) => _buildResults(
                context,
                list,
                hideIncome: hideIncome,
                locale: locale,
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (err, _) => Center(
                child: Text('${l10n.loadFailed}: $err',
                    style: const TextStyle(color: AppConstants.dangerRed)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    List<WorkEntry> list, {
    required bool hideIncome,
    required String locale,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (list.isEmpty) {
      final hasFilters = _keywordController.text.isNotEmpty ||
          ref.read(searchDateRangeProvider).from != null ||
          ref.read(searchTagFilterProvider) != null;
      if (!hasFilters) {
        // 用户尚未输入 —— 显示提示空态
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              l10n.searchHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppConstants.textSecondaryDark
                    : AppConstants.textSecondary,
              ),
            ),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppConstants.primaryColor.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 32,
                  color: AppConstants.primaryColor.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.searchEmpty,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.searchEmptyHint,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppConstants.textSecondaryDark
                    : AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 摘要头部
    final totalWage = list.fold<double>(0.0, (s, n) => s + n.dailyWage);
    final workDays = list.length;

    // 按月份分组
    final byMonth = <String, List<WorkEntry>>{};
    for (final e in list) {
      final key = e.date.substring(0, 7);
      byMonth.putIfAbsent(key, () => []).add(e);
    }
    final monthKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: monthKeys.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          // 摘要头部
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCell(
                      label: l10n.searchResultsCount(list.length),
                      value: null,
                    ),
                  ),
                  _SummaryCell(
                    label: l10n.searchTotalIncome,
                    value: hideIncome
                        ? '***'
                        : Helpers.formatCurrency(totalWage, locale),
                    accent: true,
                  ),
                  const SizedBox(width: 12),
                  _SummaryCell(
                    label: l10n.searchWorkDays,
                    value: '$workDays',
                  ),
                ],
              ),
            ),
          );
        }
        final monthKey = monthKeys[idx - 1];
        final monthEntries = byMonth[monthKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 6),
              child: Text(
                Helpers.toDisplayMonth(monthKey, locale),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryDark,
                ),
              ),
            ),
            ...monthEntries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ResultCard(
                    entry: e,
                    hideIncome: hideIncome,
                    locale: locale,
                  ),
                )),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 摘要单元格
class _SummaryCell extends StatelessWidget {
  final String label;
  final String? value;
  final bool accent;
  const _SummaryCell({
    required this.label,
    required this.value,
    this.accent = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppConstants.textSecondaryDark
                : AppConstants.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value ?? label,
          style: TextStyle(
            fontSize: value == null ? 13 : 18,
            fontWeight: FontWeight.w700,
            color: accent ? AppConstants.incomeGreen : null,
          ),
        ),
      ],
    );
  }
}

/// 单条结果卡
class _ResultCard extends StatelessWidget {
  final WorkEntry entry;
  final bool hideIncome;
  final String locale;
  const _ResultCard({
    required this.entry,
    required this.hideIncome,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(
                dateStr: entry.date,
                noteId: entry.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title.isNotEmpty ? entry.title : l10n.noTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hideIncome
                        ? '***'
                        : Helpers.formatCurrency(entry.dailyWage, locale),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.incomeGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    Helpers.toDisplayDate(entry.date, locale),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppConstants.textSecondaryDark
                          : AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
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
                      color: isDark
                          ? AppConstants.textSecondaryDark
                          : AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
              if (entry.workLocation.isNotEmpty ||
                  entry.contact.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (entry.workLocation.isNotEmpty) ...[
                      Icon(Icons.location_on_outlined,
                          size: 12,
                          color: isDark
                              ? AppConstants.textSecondaryDark
                              : AppConstants.textSecondary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          entry.workLocation,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppConstants.textSecondaryDark
                                : AppConstants.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                TagChips(tags: entry.tags, maxVisible: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 搜索页 chip
class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppConstants.primaryColor.withValues(alpha: isDark ? 0.24 : 0.16)
              : (isDark ? const Color(0xFF262630) : Colors.white),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(
            color: selected
                ? AppConstants.primaryColor
                : (isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2)),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected
                      ? AppConstants.primaryDark
                      : (isDark
                          ? AppConstants.textSecondaryDark
                          : AppConstants.textSecondary)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? AppConstants.primaryDark
                    : (isDark
                        ? AppConstants.textPrimaryDark
                        : AppConstants.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}