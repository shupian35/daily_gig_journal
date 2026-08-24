import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:daily_gig_journal/services/backup_service.dart';
import 'package:daily_gig_journal/utils/webdav_helper.dart';

void main() {
  group('BackupService', () {
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

    group('restoreFromCloud', () {
      late Directory tempDir;
      late String localDbPath;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('restore_test');
        localDbPath = '${tempDir.path}/daily_gig.db';
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      WebDavHelper helperWith(MockClient client) => WebDavHelper(
            serverUrl: 'https://dav.example.com/dav',
            username: 'user',
            password: 'pass',
            httpClient: client,
          );

      test('success: HEAD exists then DB downloaded and overwrites local file',
          () async {
        final requests = <http.BaseRequest>[];
        final helper = helperWith(MockClient((req) async {
          requests.add(req);
          if (req.method == 'HEAD') return http.Response('', 200);
          return http.Response.bytes(utf8.encode('new-db-bytes'), 200);
        }));

        await File(localDbPath).writeAsString('old-local-data');

        final result = await BackupService.restoreFromCloud(
          helper: helper,
          localDbPath: localDbPath,
        );

        expect(result.isSuccess, isTrue);
        expect(await File(localDbPath).readAsString(), 'new-db-bytes');
        // 只请求固定名 daily_gig_journal.db（ADR-0010）
        final getUrl =
            requests.firstWhere((r) => r.method == 'GET').url.toString();
        expect(getUrl, endsWith('/daily_gig_journal/daily_gig_journal.db'));
      });

      test('cloud missing: HEAD 404 short-circuits without GET', () async {
        final getRequests = <http.BaseRequest>[];
        final helper = helperWith(MockClient((req) async {
          if (req.method == 'HEAD') return http.Response('', 404);
          getRequests.add(req);
          return http.Response('', 500);
        }));

        await File(localDbPath).writeAsString('old-local-data');

        final result = await BackupService.restoreFromCloud(
          helper: helper,
          localDbPath: localDbPath,
        );

        expect(result.isSuccess, isFalse);
        expect(result.message, contains('未找到'));
        expect(getRequests, isEmpty);
        // 本地文件未被破坏
        expect(await File(localDbPath).readAsString(), 'old-local-data');
      });

      test('download failure: HEAD ok but GET fails, reports error', () async {
        final helper = helperWith(MockClient((req) async {
          if (req.method == 'HEAD') return http.Response('', 200);
          return http.Response('server error', 500);
        }));

        final result = await BackupService.restoreFromCloud(
          helper: helper,
          localDbPath: localDbPath,
        );

        expect(result.isSuccess, isFalse);
        expect(result.message, contains('下载失败'));
      });
    });
  });
}
