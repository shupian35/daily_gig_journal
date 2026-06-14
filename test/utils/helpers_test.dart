import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/utils/helpers.dart';

void main() {
  group('Helpers', () {
    group('日期格式化', () {
      test('formatDate 输出 YYYY-MM-DD', () {
        expect(Helpers.formatDate(DateTime(2025, 6, 14)), '2025-06-14');
        expect(Helpers.formatDate(DateTime(2025, 1, 1)), '2025-01-01');
      });

      test('toDisplayDate 输出中文格式', () {
        expect(Helpers.toDisplayDate('2025-06-14'), '2025年6月14日');
      });

      test('toDisplayDate 无效输入返回原文', () {
        expect(Helpers.toDisplayDate('invalid'), 'invalid');
      });

      test('getChineseWeekday 返回中文星期', () {
        expect(Helpers.getChineseWeekday(DateTime(2025, 6, 9)), '星期一');
        expect(Helpers.getChineseWeekday(DateTime(2025, 6, 15)), '星期日');
      });

      test('toMonthKey 输出 YYYY-MM', () {
        expect(Helpers.toMonthKey(DateTime(2025, 6, 14)), '2025-06');
      });

      test('toDisplayMonth 输出中文月份', () {
        expect(Helpers.toDisplayMonth('2025-06'), '2025年6月');
      });

      test('parseDate 解析日期字符串', () {
        final d = Helpers.parseDate('2025-06-14');
        expect(d, isNotNull);
        expect(d!.year, 2025);
        expect(d.month, 6);
        expect(d.day, 14);
      });

      test('parseDate 无效字符串返回 null', () {
        expect(Helpers.parseDate('abc'), isNull);
      });
    });

    group('时间与工资计算', () {
      test('calculateWorkHours 正常计算', () {
        expect(Helpers.calculateWorkHours('09:00', '18:00'), 9.0);
        expect(Helpers.calculateWorkHours('08:00', '12:00'), 4.0);
        expect(Helpers.calculateWorkHours('14:00', '18:30'), 4.5);
      });

      test('calculateWorkHours 结束不大于开始返回 0', () {
        expect(Helpers.calculateWorkHours('18:00', '09:00'), 0.0);
      });

      test('parseTime 解析时间', () {
        final t = Helpers.parseTime('14:30');
        expect(t['hour'], 14);
        expect(t['minute'], 30);
      });

      test('parseTime 无效格式返回默认 09:00', () {
        final t = Helpers.parseTime('invalid');
        expect(t['hour'], 9);
        expect(t['minute'], 0);
      });
    });

    group('格式化显示', () {
      test('formatCurrency 整数不显示小数', () {
        expect(Helpers.formatCurrency(200), '¥200');
        expect(Helpers.formatCurrency(0), '¥0');
      });

      test('formatCurrency 非整数显示 1 位小数', () {
        expect(Helpers.formatCurrency(200.5), '¥200.5');
      });

      test('formatHours 格式化时长', () {
        expect(Helpers.formatHours(8.0), '8h');
        expect(Helpers.formatHours(4.5), '4h30m');
        expect(Helpers.formatHours(0), '0h');
      });
    });
  });
}
