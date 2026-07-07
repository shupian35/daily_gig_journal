import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:math';

/// 工具函数集合
class Helpers {
  Helpers._();

  /// 日期格式化器
  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormatter = DateFormat('yyyy年M月d日');
  static final DateFormat _timeFormatter = DateFormat('HH:mm');

  /// 将 DateTime 转为数据库日期字符串 YYYY-MM-DD
  static String formatDate(DateTime date) => _dateFormatter.format(date);

  /// 数据库日期字符串转为展示格式
  /// zh/zh_TW → "2025年3月15日", en → "Mar 15, 2025"
  static String toDisplayDate(String dateStr, [String locale = 'zh']) {
    final date = parseDate(dateStr);
    if (date == null) return dateStr;
    if (locale == 'en') {
      return DateFormat('MMM d, yyyy').format(date);
    }
    return _displayDateFormatter.format(date);
  }

  /// 获取星期名称
  /// zh/zh_TW → 中文星期, en → English weekday
  static String getWeekday(DateTime date, [String locale = 'zh']) {
    if (locale == 'en') {
      const enWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return enWeekdays[date.weekday - 1];
    }
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[date.weekday - 1];
  }

  /// 获取中文星期 (backward compatibility)
  static String getChineseWeekday(DateTime date) => getWeekday(date);

  /// 获取日期的月格式字符串 YYYY-MM
  static String toMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// 获取当前月 YYYY-MM
  static String currentMonthKey() => toMonthKey(DateTime.now());

  /// 格式化月度显示
  /// zh/zh_TW → "2025年3月", en → "March 2025"
  static String toDisplayMonth(String monthKey, [String locale = 'zh']) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;
    if (locale == 'en') {
      const enMonths = ['', 'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'];
      return '${enMonths[month]} $year';
    }
    return '$year年$month月';
  }

  /// 解析日期字符串
  static DateTime? parseDate(String dateStr) {
    try {
      return _dateFormatter.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// 解析时间字符串 HH:mm 为 TimeOfDay
  /// 返回 {hour, minute} map
  static Map<String, int> parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return {
        'hour': int.parse(parts[0]),
        'minute': int.parse(parts[1]),
      };
    } catch (_) {
      return {'hour': 9, 'minute': 0};
    }
  }

  /// 计算两个时间之间的时长（小时，保留1位小数）
  static double calculateWorkHours(String startTime, String endTime) {
    final start = parseTime(startTime);
    final end = parseTime(endTime);
    final startMinutes = start['hour']! * 60 + start['minute']!;
    final endMinutes = end['hour']! * 60 + end['minute']!;

    if (endMinutes <= startMinutes) return 0.0;

    final diffHours = (endMinutes - startMinutes) / 60.0;
    // 保留1位小数
    return (diffHours * 10).round() / 10.0;
  }

  /// 格式化金额显示
  /// zh → '¥', zh_TW → 'NT\$', en → '\$'
  static String formatCurrency(double amount, [String locale = 'zh']) {
    String prefix;
    if (locale == 'en') {
      prefix = '\$';
    } else if (locale == 'zh_TW') {
      prefix = 'NT\$';
    } else {
      prefix = '¥';
    }
    if (amount == amount.roundToDouble()) {
      return '$prefix${amount.toInt()}';
    }
    return '$prefix${amount.toStringAsFixed(1)}';
  }

  /// 格式化时长显示
  static String formatHours(double hours) {
    if (hours <= 0) return '0h';
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (m == 0) return '${h}h';
    return '${h}h${m}m';
  }

  /// 获取图片存储目录，不存在则创建
  static Future<Directory> getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// 生成唯一的图片文件名：日期_随机数.png
  static String generateImageFileName() {
    final now = DateTime.now();
    final datePart = formatDate(now);
    final randomPart = Random().nextInt(999999).toString().padLeft(6, '0');
    return '${datePart}_$randomPart.png';
  }

  /// 获取当前时间字符串
  static String nowTimeString() => _timeFormatter.format(DateTime.now());
}
