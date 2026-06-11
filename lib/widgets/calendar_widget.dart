import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/constants.dart';

/// 自定义日历组件 —— 精致杂志风
class CalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Set<DateTime> workDates;
  final Set<DateTime> noteDates;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime)? onPageChanged;
  final CalendarFormat calendarFormat;
  final void Function(CalendarFormat)? onFormatChanged;

  const CalendarWidget({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.workDates,
    required this.noteDates,
    required this.onDaySelected,
    this.onPageChanged,
    this.calendarFormat = CalendarFormat.week,
    this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2035),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          calendarFormat: calendarFormat,
          onDaySelected: (selectedDay, focusedDay) {
            onDaySelected(selectedDay, focusedDay);
          },
          onPageChanged: (focusedDay) {
            onPageChanged?.call(focusedDay);
          },
          onFormatChanged: onFormatChanged,

          locale: 'zh_CN',

          eventLoader: (day) {
            final events = <String>[];
            if (workDates.any((d) => isSameDay(d, day))) {
              events.add('work');
            }
            if (noteDates.any((d) => isSameDay(d, day))) {
              events.add('note');
            }
            return events;
          },

          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;
              return Positioned(
                bottom: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.map((e) {
                    final color = e == 'work'
                        ? AppConstants.workDotColor
                        : AppConstants.noteDotColor;
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            selectedBuilder: (context, date, _) {
              return _buildDayCell(date, true, isDark);
            },
            todayBuilder: (context, date, _) {
              return _buildDayCell(date, false, isDark, isToday: true);
            },
          ),

          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: true,
            formatButtonTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppConstants.primaryDark,
            ),
            formatButtonDecoration: BoxDecoration(
              color: AppConstants.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              border: Border.all(
                color: AppConstants.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left_rounded,
              color: isDark ? const Color(0xFFA09892) : const Color(0xFF8D7E76),
              size: 22,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFFA09892) : const Color(0xFF8D7E76),
              size: 22,
            ),
            titleTextStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppConstants.textPrimaryDark
                  : AppConstants.textPrimary,
              letterSpacing: 0.3,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            headerPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),

          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: isDark
                  ? AppConstants.textSecondaryDark
                  : AppConstants.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            weekendStyle: TextStyle(
              color: isDark
                  ? AppConstants.primaryLight
                  : AppConstants.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
                  width: 0.5,
                ),
              ),
            ),
          ),

          daysOfWeekHeight: 32,
          rowHeight: 44,
        ),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    bool isSelected,
    bool isDark, {
    bool isToday = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppConstants.primaryColor
                  : (isToday
                      ? AppConstants.primaryColor.withValues(alpha: 0.12)
                      : Colors.transparent),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isToday
                          ? AppConstants.primaryDark
                          : (isDark
                              ? AppConstants.textPrimaryDark
                              : AppConstants.textPrimary)),
                  fontWeight: isSelected || isToday
                      ? FontWeight.w600
                      : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
