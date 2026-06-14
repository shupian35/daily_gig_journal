import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/models/work_entry.dart';

void main() {
  group('WorkEntry', () {
    test('fromMap 正确解析数据库行', () {
      final map = {
        'id': 1,
        'date': '2025-06-14',
        'title': '会展协助',
        'work_location': '会展中心A馆',
        'contact': '张三',
        'start_time': '08:00',
        'end_time': '17:00',
        'hourly_wage': 25.0,
        'work_hours': 8.0,
        'daily_wage': 200.0,
        'note_content': '[]',
        'created_at': '2025-06-14T08:00:00',
        'updated_at': '2025-06-14T17:00:00',
      };

      final entry = WorkEntry.fromMap(map);

      expect(entry.id, 1);
      expect(entry.date, '2025-06-14');
      expect(entry.title, '会展协助');
      expect(entry.workLocation, '会展中心A馆');
      expect(entry.contact, '张三');
      expect(entry.hourlyWage, 25.0);
      expect(entry.workHours, 8.0);
      expect(entry.dailyWage, 200.0);
    });

    test('fromMap 处理缺失字段用默认值', () {
      final map = {'date': '2025-06-14'};
      final entry = WorkEntry.fromMap(map);

      expect(entry.title, '');
      expect(entry.workLocation, '');
      expect(entry.contact, '');
      expect(entry.startTime, '09:00');
      expect(entry.endTime, '18:00');
      expect(entry.hourlyWage, 0.0);
      expect(entry.workHours, 0.0);
      expect(entry.dailyWage, 0.0);
      expect(entry.noteContent, '[]');
    });

    test('toMap 正确序列化为数据库行', () {
      final entry = WorkEntry(
        date: '2025-06-14',
        title: '家教',
        workLocation: '学生家',
        contact: '李四',
        startTime: '14:00',
        endTime: '18:00',
        hourlyWage: 60.0,
        workHours: 4.0,
        dailyWage: 240.0,
        noteContent: '[]',
      );

      final map = entry.toMap();

      expect(map['date'], '2025-06-14');
      expect(map['title'], '家教');
      expect(map['contact'], '李四');
      expect(map['hourly_wage'], 60.0);
      expect(map['daily_wage'], 240.0);
      expect(map['updated_at'], isNotNull);
    });

    test('toMap(forUpdate: true) 不包含 created_at', () {
      final entry = WorkEntry(
        date: '2025-06-14',
        title: '测试',
        workLocation: '', contact: '',
        startTime: '09:00',
        endTime: '18:00',
        hourlyWage: 0,
        workHours: 0,
        dailyWage: 0,
        noteContent: '[]',
      );

      final map = entry.toMap(forUpdate: true);

      expect(map.containsKey('created_at'), false);
      expect(map.containsKey('updated_at'), true);
    });

    test('empty 工厂返回合理默认值', () {
      final entry = WorkEntry.empty('2025-06-14');

      expect(entry.date, '2025-06-14');
      expect(entry.title, '');
      expect(entry.startTime, '09:00');
      expect(entry.endTime, '18:00');
      expect(entry.workHours, 9.0);
      expect(entry.dailyWage, 0.0);
    });

    test('copyWith 正确部分更新', () {
      final original = WorkEntry.empty('2025-06-14');
      final updated = original.copyWith(title: '新标题', dailyWage: 300.0);

      expect(updated.title, '新标题');
      expect(updated.dailyWage, 300.0);
      // 未修改的字段保持不变
      expect(updated.date, '2025-06-14');
      expect(updated.startTime, '09:00');
    });
  });
}
