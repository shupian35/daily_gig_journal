import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/constants.dart';

/// 自定义日历组件
/// 封装 table_calendar，并提供标记日期、点击等配置
class CalendarWidget extends StatelessWidget {
  /// 当前聚焦日期
  final DateTime focusedDay;
  /// 当前选中日期
  final DateTime selectedDay;
  /// 有工作安排的日期集合
  final Set<DateTime> workDates;
  /// 有笔记的日期集合
  final Set<DateTime> noteDates;
  /// 日期选中回调
  final Function(DateTime, DateTime) onDaySelected;
  /// 页面切换回调（月份改变）
  final Function(DateTime)? onPageChanged;
  /// 日历格式（默认周视图）
  final CalendarFormat calendarFormat;
  /// 格式切换回调
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

    return TableCalendar(
      // 核心日期配置
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

      // 语言中文化
      locale: 'zh_CN',

      // ===================== 事件标记 =====================
      eventLoader: (day) {
        // 返回该日期的事件列表（用于标记圆点）
        final events = <String>[];
        if (workDates.any((d) => isSameDay(d, day))) {
          events.add('work');
        }
        if (noteDates.any((d) => isSameDay(d, day))) {
          events.add('note');
        }
        return events;
      },

      // 日历建造器：自定义日期单元格外观
      calendarBuilders: CalendarBuilders(
        // 标记圆点建造器
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: events.map((e) {
                final color = e == 'work'
                    ? AppConstants.workDotColor
                    : AppConstants.noteDotColor;
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
          );
        },
        // 选中日期样式
        selectedBuilder: (context, date, _) {
          return _buildAnimatedDayCell(date, true, isDark);
        },
        // 今天样式
        todayBuilder: (context, date, _) {
          return _buildAnimatedDayCell(date, false, isDark, isToday: true);
        },
      ),

      // ===================== 样式配置 =====================
      // 头部样式
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: true,
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF3D3D3D),
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252540) : const Color(0xFFFFF9F2),
        ),
      ),
      // 星期行样式
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          fontSize: 13,
        ),
        weekendStyle: TextStyle(
          color: isDark ? AppConstants.primaryLight : AppConstants.primaryDark,
          fontSize: 13,
        ),
      ),
    );
  }

  /// 构建带动画的日期单元格
  Widget _buildAnimatedDayCell(
    DateTime date,
    bool isSelected,
    bool isDark, {
    bool isToday = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppConstants.primaryColor
                  : (isToday
                      ? AppConstants.primaryColor.withValues(alpha: 0.2)
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
                          : (isDark ? Colors.white70 : Colors.black87)),
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
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
