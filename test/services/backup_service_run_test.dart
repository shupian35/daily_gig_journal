import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_gig_journal/providers/settings_provider.dart';
import 'package:daily_gig_journal/services/backup_service.dart';
import 'package:daily_gig_journal/utils/webdav_helper.dart';

/// 进程内假 WebDAV 服务器（fake transport）：实现 [http.Client] 接口，
/// 维护虚拟云端对象状态（objects/bodies/lastModified），记录所有请求。
/// BackupService 只经 WebDavHelper 与 HTTP 语义交互，因此本 fake 即可
/// 驱动完整 auto-backup 行为，无需网络与真实账号。
class _FakeDav extends http.BaseClient {
  /// 虚拟云端对象：相对 daily_gig_journal/ 的路径，如 'images/a.png'。
  final Set<String> objects = {};

  /// 对象内容（PUT 写入、GET 读出）。
  final Map<String, List<int>> bodies = {};

  /// 对象的 getlastmodified（用于 trashed 清理的 PROPFIND 列表）。
  final Map<String, DateTime> lastModified = {};

  /// 收到的全部请求（按序）。
  final List<http.BaseRequest> requests = [];

  /// 非空时挂起所有请求，用于互斥测试制造"备份进行中"窗口。
  Completer<void>? gate;

  void seed(String rel, List<int> bytes, {DateTime? lm}) {
    objects.add(rel);
    bodies[rel] = bytes;
    lastModified[rel] = lm ?? DateTime.now();
  }

  List<http.BaseRequest> method(String m) =>
      requests.where((r) => r.method == m).toList();

  bool requested(String m, String suffix) => requests
      .any((r) => r.method == m && r.url.path.endsWith(suffix));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (gate != null) await gate!.future;

    final segments = request.url.pathSegments;
    final anchor = segments.indexOf(WebDavHelper.backupSubDir);
    final rel = anchor >= 0 && anchor + 1 < segments.length
        ? segments.sublist(anchor + 1).join('/')
        : '';

    switch (request.method) {
      case 'MKCOL':
        return _resp(201);
      case 'PROPFIND':
        return _propfind(request, rel);
      case 'HEAD':
        return _resp(objects.contains(rel) ? 200 : 404);
      case 'PUT':
        final bytes = (request as http.Request).bodyBytes;
        objects.add(rel);
        bodies[rel] = bytes;
        lastModified[rel] = DateTime.now();
        return _resp(201);
      case 'GET':
        final bytes = bodies[rel];
        if (!objects.contains(rel) || bytes == null || bytes.isEmpty) {
          return _resp(404);
        }
        return _resp(200, bytes);
      case 'DELETE':
        objects.remove(rel);
        bodies.remove(rel);
        lastModified.remove(rel);
        return _resp(204);
    }
    return _resp(405);
  }

  http.StreamedResponse _resp(int status, [List<int> body = const []]) {
    return http.StreamedResponse(Stream.value(body), status,
        contentLength: body.length,
        headers: {'content-length': '${body.length}'});
  }

  /// Depth 0 → 目录存在（207 空表）；Depth 1 → 列出 [dir] 下对象。
  http.StreamedResponse _propfind(http.BaseRequest request, String rel) {
    final depth = request.headers['Depth'] ?? '0';
    if (depth != '1') return _resp(207);

    final dir = rel.endsWith('/') ? rel.substring(0, rel.length - 1) : rel;
    final children =
        objects.where((o) => o.startsWith('$dir/') && !o.contains('/', dir.length + 1));
    final entries = <String>[
      _davEntry('$dir/', null),
      for (final o in children)
        _davEntry(o, lastModified[o], size: bodies[o]?.length ?? 0),
    ];
    final xml = '<?xml version="1.0"?>\n'
        '<D:multistatus xmlns:D="DAV:">\n${entries.join('\n')}\n</D:multistatus>';
    final body = utf8.encode(xml);
    return http.StreamedResponse(Stream.value(body), 207,
        contentLength: body.length);
  }

  String _davEntry(String rel, DateTime? lm, {int size = 0}) {
    final lmStr =
        lm == null ? '' : '<D:getlastmodified>${HttpDate.format(lm.toUtc())}</D:getlastmodified>';
    return '<D:response>'
        '<D:href>/dav/${WebDavHelper.backupSubDir}/$rel</D:href>'
        '<D:propstat><D:prop>$lmStr'
        '<D:getcontentlength>$size</D:getcontentlength>'
        '</D:prop></D:propstat></D:response>';
  }

  @override
  void close() {}
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackupService.runAutoBackup · 行为测试（ADR-0010 fake transport）', () {
    late Directory tempDir;
    late String dbPath;
    late _FakeDav dav;
    late ProviderContainer container;

    final fixedNow = DateTime(2026, 8, 25, 12, 0);

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_run_test');
      dbPath = p.join(tempDir.path, 'daily_gig.db');
      await File(dbPath).writeAsBytes(utf8.encode('local-db-v1'));
      dav = _FakeDav();
      container = ProviderContainer(overrides: [
        autoBackupProvider.overrideWith((ref) => true),
        webDavConfiguredProvider.overrideWith((ref) => true),
      ]);
      addTearDown(container.dispose);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    BackupService makeService() => BackupService(
          container: container,
          helperFactory: () => WebDavHelper(
            serverUrl: 'https://dav.example.com/dav',
            username: 'user',
            password: 'pass',
            httpClient: dav,
          ),
          localDbPathResolver: () async => dbPath,
          clock: () => fixedNow,
        );

    test('HEAD 探测命中 → 跳过该文件上传（不发 PUT），未命中才 PUT', () async {
      dav.seed('images/cloud_has.png', utf8.encode('cloud'));
      await Directory(p.join(tempDir.path, 'images')).create(recursive: true);
      await File(p.join(tempDir.path, 'images', 'cloud_has.png'))
          .writeAsBytes(utf8.encode('local'));
      await File(p.join(tempDir.path, 'images', 'brand_new.png'))
          .writeAsBytes(utf8.encode('new'));

      container.read(backupChangeSetProvider.notifier)
        ..markImageUpload('images/cloud_has.png')
        ..markImageUpload('images/brand_new.png');

      await makeService().runAutoBackup().completion;

      expect(dav.requested('PUT', '/images/cloud_has.png'), isFalse,
          reason: '云端已存在，HEAD 命中必须跳过');
      expect(dav.requested('PUT', '/images/brand_new.png'), isTrue);

      final summary = container.read(lastAutoBackupSummaryProvider);
      expect(summary, isNotNull);
      expect(summary!.skippedImages, 1);
      expect(summary.uploadedImages, 1);
    });

    test('本地已删文件 → 移入 trashed/：PUT 到 trashed 路径而非直接 DELETE', () async {
      dav.seed('images/gone.png', utf8.encode('old-image-bytes'));

      container
          .read(backupChangeSetProvider.notifier)
          .markImageTrash('images/gone.png');

      await makeService().runAutoBackup().completion;

      // 软删除三步：HEAD 原位 → GET 取回 → PUT 到 trashed/ → DELETE 原位
      expect(dav.requested('PUT', '/trashed/gone.png'), isTrue);
      expect(dav.bodies['trashed/gone.png'], utf8.encode('old-image-bytes'));
      expect(dav.requested('DELETE', '/images/gone.png'), isTrue);
      expect(dav.objects.contains('images/gone.png'), isFalse);
      expect(dav.objects.contains('trashed/gone.png'), isTrue);
    });

    test('trashed 超 30 天 → 清理 DELETE 发生；未过期不动；解析失败不动', () async {
      dav.seed('trashed/expired.png', utf8.encode('x'),
          lm: fixedNow.subtract(const Duration(days: 40)));
      dav.seed('trashed/fresh.png', utf8.encode('y'),
          lm: fixedNow.subtract(const Duration(days: 1)));

      await makeService().runAutoBackup().completion;

      expect(dav.requested('DELETE', '/trashed/expired.png'), isTrue);
      expect(dav.requested('DELETE', '/trashed/fresh.png'), isFalse);
      expect(dav.objects.contains('expired.png') ||
          dav.objects.contains('trashed/expired.png'), isFalse);
    });

    test('DB 每次 PUT 覆盖（两次运行各一次 PUT，字节为当时本地内容）', () async {
      final service = makeService();

      await service.runAutoBackup().completion;
      expect(dav.requested('PUT', '/${BackupService.cloudDbName}'), isTrue);

      await File(dbPath).writeAsBytes(utf8.encode('local-db-v2'));
      dav.requests.clear();
      await service.runAutoBackup().completion;

      final dbPuts = dav
          .method('PUT')
          .where((r) => r.url.path.endsWith('/${BackupService.cloudDbName}'))
          .toList();
      expect(dbPuts.length, 1);
      expect(dav.bodies[BackupService.cloudDbName], utf8.encode('local-db-v2'));
    });

    test('变更集取走后 reset', () async {
      container.read(backupChangeSetProvider.notifier)
        ..markDraftUpload('drafts/d.json')
        ..markImageUpload('images/i.png');
      expect(container.read(backupChangeSetProvider).isEmpty, isFalse);

      await makeService().runAutoBackup().completion;

      expect(container.read(backupChangeSetProvider).isEmpty, isTrue);
    });

    test('并发第二调用被互斥跳过（started=false），不排队不竞态', () async {
      dav.gate = Completer<void>();
      final service = makeService();

      final first = service.runAutoBackup();
      expect(first.started, isTrue);

      final second = service.runAutoBackup();
      expect(second.started, isFalse, reason: '第一次尚未完成，第二次必须被互斥跳过');

      dav.gate!.complete();
      await first.completion;
      await second.completion;

      final dbPuts = dav
          .method('PUT')
          .where((r) => r.url.path.endsWith('/${BackupService.cloudDbName}'))
          .toList();
      expect(dbPuts.length, 1, reason: '并发期间只允许一份备份在跑');

      // 互斥释放后可再次运行
      dav.requests.clear();
      final third = service.runAutoBackup();
      expect(third.started, isTrue);
      await third.completion;
    });

    test('成功后 summary/error 横幅状态更新且持久化 error 键清空', () async {
      // 先种一个错误状态，验证成功路径会清掉
      container.read(lastAutoBackupErrorProvider.notifier).state =
          AutoBackupError(
        occurredAt: fixedNow,
        reason: 'previous',
        consecutiveCount: 2,
      );

      await makeService().runAutoBackup().completion;

      expect(container.read(lastAutoBackupSummaryProvider), isNotNull);
      expect(container.read(lastAutoBackupErrorProvider), isNull);
    });
  });
}
