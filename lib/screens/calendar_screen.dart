import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/wage_summary_card.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import 'note_edit_screen.dart';

/// 日历首页 —— 精致杂志风
class CalendarScreen extends ConsumerStatefulWidget {
  final Function(String dateStr)? onDaySelected;

  const CalendarScreen({super.key, this.onDaySelected});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final workDatesAsync = ref.watch(workDatesProvider);
    final monthlyWageAsync = ref.watch(monthlyTotalWageProvider);
    final monthlyDaysAsync = ref.watch(monthlyWorkDaysProvider);
    final hideIncome = ref.watch(hideIncomeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程清单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded, size: 22),
            tooltip: '回到今天',
            onPressed: () {
              final today = DateTime.now();
              setState(() {
                _focusedDay = DateTime(today.year, today.month, today.day);
                _selectedDay = _focusedDay;
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 700;
          if (isTablet) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Column(children: [
                      if (!hideIncome) _buildWageSummary(monthlyWageAsync, monthlyDaysAsync),
                      _buildCalendar(workDatesAsync),
                    ]),
                  ),
                ),
                Container(
                  width: 0.5,
                  color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildUpcomingWeekPlan(hideIncome),
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(children: [
              if (!hideIncome) _buildWageSummary(monthlyWageAsync, monthlyDaysAsync),
              _buildCalendar(workDatesAsync),
              _buildUpcomingWeekPlan(hideIncome),
            ]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _navigateToDayEntries(Helpers.formatDate(DateTime.now()));
        },
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('添加今日工作'),
      ),
    );
  }

  Widget _buildWageSummary(
    AsyncValue<double> wageAsync,
    AsyncValue<int> daysAsync,
  ) {
    return wageAsync.when(
      data: (totalWage) {
        final workDays = daysAsync.asData?.value ?? 0;
        final monthDisplay =
            Helpers.toDisplayMonth(Helpers.toMonthKey(_focusedDay));
        return WageSummaryCard(
          totalWage: totalWage,
          workDays: workDays,
          monthDisplay: monthDisplay,
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Text('加载失败: $err',
            style: const TextStyle(color: AppConstants.dangerRed)),
      ),
    );
  }

  Widget _buildCalendar(AsyncValue<Set<DateTime>> workDatesAsync) {
    final workDates = workDatesAsync.asData?.value ?? <DateTime>{};

    return CalendarWidget(
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      workDates: workDates,
      noteDates: workDates,
      calendarFormat: _calendarFormat,
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        final dateStr = Helpers.formatDate(selectedDay);
        _navigateToDayEntries(dateStr);
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        ref.read(focusedDateProvider.notifier).state = focusedDay;
      },
    );
  }

  Widget _buildUpcomingWeekPlan(bool hideIncome) {
    final today = DateTime.now();
    final todayStr = Helpers.formatDate(today);
    final endDay = today.add(const Duration(days: 6));
    final endStr = Helpers.formatDate(endDay);

    final rangeNotesAsync = ref.watch(
      notesByDateRangeProvider((start: todayStr, end: endStr)),
    );

    return rangeNotesAsync.when(
      data: (notes) {
        final grouped = <String, List<_PlanItem>>{};
        for (final note in notes) {
          grouped.putIfAbsent(note.date, () => []).add(_PlanItem(
                noteId: note.id!,
                date: note.date,
                title: note.title.isNotEmpty ? note.title : '(无标题)',
                workLocation: note.workLocation,
                contact: note.contact,
                timeRange: '${note.startTime}-${note.endTime}',
                wage: note.dailyWage,
              ));
        }

        if (grouped.isEmpty) {
          return _buildEmptyWeekState();
        }

        final entries = grouped.entries.toList();

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '未来一周',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              ...entries.map((entry) {
                final ds = entry.key;
                final items = entry.value;
                final date = Helpers.parseDate(ds);
                final displayDate =
                    date != null ? Helpers.toDisplayDate(ds) : ds;
                final weekday =
                    date != null ? Helpers.getChineseWeekday(date) : '';
                final isToday = ds == todayStr;
                final dailyTotal =
                    items.fold(0.0, (sum, item) => sum + item.wage);

                return _buildDayCard(
                  displayDate: displayDate,
                  weekday: weekday,
                  isToday: isToday,
                  items: items,
                  dailyTotal: dailyTotal,
                  hideIncome: hideIncome,
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => Center(
        child: Text('加载失败: $err',
            style: const TextStyle(color: AppConstants.dangerRed)),
      ),
    );
  }

  Widget _buildEmptyWeekState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC8895A).withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.event_note_rounded,
              size: 28,
              color: const Color(0xFFC8895A).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '未来一周暂无工作安排',
            style: TextStyle(
              fontSize: 14,
              color: AppConstants.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard({
    required String displayDate,
    required String weekday,
    required bool isToday,
    required List<_PlanItem> items,
    required double dailyTotal,
    required bool hideIncome,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: isToday
              ? AppConstants.primaryColor.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2)),
          width: isToday ? 1 : 0.5,
        ),
        boxShadow: isToday ? AppConstants.cardShadow(isDark) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期行
            Row(
              children: [
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor,
                      borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                    ),
                    child: const Text(
                      '今天',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (isToday) const SizedBox(width: 8),
                Text(
                  '$displayDate ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppConstants.textSecondaryDark
                        : AppConstants.textSecondary,
                  ),
                ),
                const Spacer(),
                if (!hideIncome)
                  Text(
                    '合计 ${Helpers.formatCurrency(dailyTotal)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.incomeGreen,
                      letterSpacing: -0.2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // 分隔线
            Container(
              height: 0.5,
              color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
            ),
            const SizedBox(height: 10),
            // 工作条目
            ...items.map((item) => InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditScreen(
                          dateStr: item.date,
                          noteId: item.noteId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppConstants.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.workLocation.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.location_on_outlined,
                              size: 13,
                              color: isDark
                                  ? const Color(0xFFA09892)
                                  : const Color(0xFFB5A99F)),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              item.workLocation,
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
                        if (item.contact.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.person_outline_rounded,
                              size: 13,
                              color: isDark
                                  ? const Color(0xFFA09892)
                                  : const Color(0xFFB5A99F)),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              item.contact,
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
                        const SizedBox(width: 10),
                        Text(
                          item.timeRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppConstants.textSecondaryDark
                                : AppConstants.textSecondary,
                          ),
                        ),
                        if (!hideIncome) ...[
                          const SizedBox(width: 10),
                          Text(
                            Helpers.formatCurrency(item.wage),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.incomeGreen,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _navigateToDayEntries(String dateStr) {
    if (widget.onDaySelected != null) {
      widget.onDaySelected!(dateStr);
    }
  }
}

class _PlanItem {
  final int noteId;
  final String date;
  final String title;
  final String workLocation;
  final String contact;
  final String timeRange;
  final double wage;
  const _PlanItem({
    required this.noteId,
    required this.date,
    required this.title,
    required this.workLocation,
    required this.contact,
    required this.timeRange,
    required this.wage,
  });
}
