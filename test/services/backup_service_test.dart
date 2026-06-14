import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/services/backup_service.dart';

void main() {
  group('BackupService', () {
    group('parseTimestampFromName', () {
      test('正确解析备份文件名中的时间戳', () {
        final dt = BackupService.parseTimestampFromName(
          'daily_gig_backup_auto_2025-06-14T08-30-00.db',
        );
        expect(dt, isNotNull);
        expect(dt!.year, 2025);
        expect(dt.month, 6);
        expect(dt.day, 14);
        expect(dt.hour, 8);
        expect(dt.minute, 30);
      });

      test('不含 auto_ 前缀返回 null', () {
        final dt = BackupService.parseTimestampFromName(
          'daily_gig_backup_2025-06-14T08-30-00.db',
        );
        expect(dt, isNull);
      });

      test('非法格式返回 null', () {
        final dt = BackupService.parseTimestampFromName(
          'daily_gig_backup_auto_not_a_date.db',
        );
        expect(dt, isNull);
      });

      test('空字符串返回 null', () {
        final dt = BackupService.parseTimestampFromName('');
        expect(dt, isNull);
      });

      test('解析手动备份文件名（非 auto）', () {
        final dt = BackupService.parseTimestampFromName(
          'daily_gig_backup_2025-01-15T12-00-00.db',
        );
        // 不含 auto_ 前缀，不匹配
        expect(dt, isNull);
      });
    });

    group('autoBackupRetentionDays', () {
      test('保留期常量是 30 天', () {
        expect(BackupService.autoBackupRetentionDays, 30);
      });
    });
  });
}
