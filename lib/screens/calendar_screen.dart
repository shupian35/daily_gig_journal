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

/// 日历首页
/// 显示周/月视图日历、月度收入摘要、未来一周工作计划
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程清单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
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
                const VerticalDivider(width: 1),
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
        icon: const Icon(Icons.add),
        label: const Text('添加今日工作'),
      ),
    );
  }

  /// 构建月度工资摘要
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
        height: 90,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('加载失败: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  /// 构建日历
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

  /// 构建未来一周工作计划列表
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
        // 分组
        final grouped = <String, List<_PlanItem>>{};
        for (final note in notes) {
          grouped.putIfAbsent(note.date, () => []).add(_PlanItem(
                noteId: note.id!,
                date: note.date,
                title: note.title.isNotEmpty ? note.title : '(无标题)',
                workLocation: note.workLocation,
                timeRange: '${note.startTime}-${note.endTime}',
                wage: note.dailyWage,
              ));
        }

        if (grouped.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.event_note, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  '未来一周暂无工作安排',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final entries = grouped.entries.toList();

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_view_week,
                        size: 18, color: AppConstants.primaryDark),
                    const SizedBox(width: 6),
                    Text(
                      '未来一周工作计划',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              // 日期卡片列表
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

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 日期行
                        Row(
                          children: [
                            if (isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '今天',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ),
                            if (isToday) const SizedBox(width: 6),
                            Text(
                              '$displayDate $weekday',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            if (!hideIncome)
                              Text(
                                '合计 ${Helpers.formatCurrency(dailyTotal)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.incomeGreen,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 工作条目（点击可进入编辑页）
                        ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: InkWell(
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
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle,
                                          size: 6,
                                          color: AppConstants.primaryDark),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style:
                                              const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.workLocation.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.location_on_outlined,
                                            size: 12,
                                            color: Colors.grey.shade400),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            item.workLocation,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Colors.grey.shade500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      Text(
                                        item.timeRange,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                      ),
                                      if (!hideIncome) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          Helpers.formatCurrency(item.wage),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppConstants.incomeGreen,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
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
        child: Text('加载失败: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  /// 导航到当天条目列表页
  void _navigateToDayEntries(String dateStr) {
    if (widget.onDaySelected != null) {
      widget.onDaySelected!(dateStr);
    }
  }
}

/// 工作计划条目（仅用于展示）
class _PlanItem {
  final int noteId;
  final String date;
  final String title;
  final String workLocation;
  final String timeRange;
  final double wage;
  const _PlanItem({
    required this.noteId,
    required this.date,
    required this.title,
    required this.workLocation,
    required this.timeRange,
    required this.wage,
  });
}
