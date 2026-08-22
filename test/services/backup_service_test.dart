import "package:flutter_test/flutter_test.dart";
import "package:daily_gig_journal/services/backup_service.dart";

void main() {
  group('BackupService', () {
    group('parseTimestampFromName', () {
      test('correctly parses auto backup filename timestamp', () {
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
    });

    group('autoBackupRetentionDays', () {
      test('retention constant is 30 days', () {
        expect(BackupService.autoBackupRetentionDays, 30);
      });
    });

    group('BackupChangeSet', () {
      test('default constructor has empty sets', () {
        final cs = BackupChangeSet();
        expect(cs.imagesToUpload, isEmpty);
        expect(cs.draftsToUpload, isEmpty);
        expect(cs.imagesToTrash, isEmpty);
        expect(cs.draftsToTrash, isEmpty);
        expect(cs.isEmpty, isTrue);
      });

      test('isEmpty reports correctly when populated', () {
        final cs = BackupChangeSet(
          imagesToUpload: {'images/x.png'},
          draftsToUpload: {'drafts/z.json'},
        );
        expect(cs.isEmpty, isFalse);
      });

      test('trash-only counts as non-empty (deletion must sync)', () {
        final cs = BackupChangeSet(
          imagesToTrash: {'images/old.png'},
        );
        expect(cs.isEmpty, isFalse);
      });
    });

    group('AutoBackupError', () {
      test('consecutiveCount increments across failures', () {
        AutoBackupError make(int n) => AutoBackupError(
          occurredAt: DateTime(2026, 7, 25),
          reason: 'test',
          consecutiveCount: n,
        );
        expect(make(1).consecutiveCount, 1);
        expect(make(3).consecutiveCount, 3);
      });
    });

    group('AutoBackupSummary', () {
      test('stores all fields', () {
        final s = AutoBackupSummary(
          completedAt: DateTime(2026, 7, 25, 10, 0),
          uploadedImages: 5,
          skippedImages: 12,
          uploadedDrafts: 1,
          uploadedBytes: 1024000,
          dbUploaded: true,
        );
        expect(s.uploadedImages, 5);
        expect(s.skippedImages, 12);
        expect(s.uploadedBytes, 1024000);
        expect(s.dbUploaded, isTrue);
      });
    });

    group('parseDavLastModified', () {
      test('parses RFC1123 HTTP-date returned by PROPFIND getlastmodified', () {
        final dt = BackupService.parseDavLastModified(
          'Mon, 14 Jun 2026 08:30:00 GMT',
        );
        expect(dt, isNotNull);
        final utc = dt!.toUtc();
        expect(utc.year, 2026);
        expect(utc.month, 6);
        expect(utc.day, 14);
        expect(utc.hour, 8);
        expect(utc.minute, 30);
      });

      test('regression: DateTime.parse throws on HTTP-date, parser succeeds', () {
        const raw = 'Mon, 14 Jun 2026 08:30:00 GMT';
        expect(() => DateTime.parse(raw), throwsFormatException);
        expect(BackupService.parseDavLastModified(raw), isNotNull);
      });

      test('returns null on empty or unparseable input', () {
        expect(BackupService.parseDavLastModified(''), isNull);
        expect(BackupService.parseDavLastModified('not-a-date'), isNull);
        // ISO 8601 不被 HttpDate 接受（这正是旧实现的 bug 根源）。
        expect(
          BackupService.parseDavLastModified('2026-06-14T08:30:00'),
          isNull,
        );
      });
    });

    group('cloud DB name constant', () {
      test('uses fixed overwrite name daily_gig_journal.db', () {
        expect(BackupService.cloudDbName, 'daily_gig_journal.db');
      });

      test('subDir constants match ADR-0010', () {
        expect(BackupService.imagesSubDir, 'images');
        expect(BackupService.draftsSubDir, 'drafts');
        expect(BackupService.trashedSubDir, 'trashed');
      });
    });
  });
}
