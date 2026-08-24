import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';
import 'package:daily_gig_journal/utils/webdav_helper.dart';

/// 构建坚果云风格的 PROPFIND 响应
/// [dir] 为 href 中的目录路径（如 'daily_gig_journal' 或 'daily_gig_journal/images'）
String _buildPropfindResponse(String dir, List<String> fileNames) {
  final buf = StringBuffer();
  buf.writeln('<?xml version="1.0" encoding="utf-8"?>');
  buf.writeln('<D:multistatus xmlns:D="DAV:">');
  for (final name in fileNames) {
    buf.writeln('  <D:response>');
    buf.writeln('    <D:href>/dav/$dir/$name</D:href>');
    buf.writeln('    <D:propstat>');
    buf.writeln('      <D:prop>');
    buf.writeln('        <D:displayname>$name</D:displayname>');
    buf.writeln('        <D:getcontentlength>12345</D:getcontentlength>');
    buf.writeln(
        '        <D:getlastmodified>Mon, 14 Jun 2025 08:30:00 GMT</D:getlastmodified>');
    buf.writeln('      </D:prop>');
    buf.writeln('      <D:status>HTTP/1.1 200 OK</D:status>');
    buf.writeln('    </D:propstat>');
    buf.writeln('  </D:response>');
  }
  buf.writeln('</D:multistatus>');
  return buf.toString();
}

WebDavHelper _helperWith(MockClient client) => WebDavHelper(
      serverUrl: 'https://dav.example.com/dav',
      username: 'user',
      password: 'pass',
      httpClient: client,
    );

void main() {
  group('WebDavHelper listFiles XML 解析', () {
    test('解析标准 PROPFIND 响应', () {
      final xml = _buildPropfindResponse('daily_gig_journal', [
        'daily_gig_backup_2025-06-14T08-30-00.db',
        'daily_gig_backup_auto_2025-06-13T10-00-00.db',
      ]);

      final document = XmlDocument.parse(xml);
      final responses = document.findAllElements('D:response');
      final files = <Map<String, String>>[];

      for (final r in responses) {
        final href = r
            .findElements('D:href')
            .firstOrNull
            ?.innerText
            .trim() ?? '';
        final displayName = r
            .findElements('D:propstat')
            .expand((ps) => ps.findElements('D:prop'))
            .expand((p) => p.findElements('D:displayname'))
            .firstOrNull
            ?.innerText
            .trim() ?? '';
        final name = displayName.isNotEmpty
            ? displayName
            : href.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';

        files.add({'href': href, 'name': name, 'displayName': displayName});
      }

      expect(files.length, 2);
      expect(files[0]['name'], 'daily_gig_backup_2025-06-14T08-30-00.db');
      expect(files[1]['name'], 'daily_gig_backup_auto_2025-06-13T10-00-00.db');
    });

    test('解析 webdav 目录名 href 不为空', () {
      final xml = _buildPropfindResponse('daily_gig_journal', ['backup.db']);
      final document = XmlDocument.parse(xml);
      final responses = document.findAllElements('D:response');

      final href = responses.first
          .findElements('D:href')
          .firstOrNull
          ?.innerText
          .trim() ?? '';

      expect(href, '/dav/daily_gig_journal/backup.db');
    });

    test('无 displayName 时从 href 提取文件名', () {
      final buf = StringBuffer();
      buf.writeln('<?xml version="1.0"?>');
      buf.writeln('<D:multistatus xmlns:D="DAV:">');
      buf.writeln('  <D:response>');
      buf.writeln('    <D:href>/dav/daily_gig_journal/backup.db</D:href>');
      buf.writeln('    <D:propstat>');
      buf.writeln('      <D:prop>');
      buf.writeln('        <D:getcontentlength>99</D:getcontentlength>');
      buf.writeln('      </D:prop>');
      buf.writeln('      <D:status>HTTP/1.1 200 OK</D:status>');
      buf.writeln('    </D:propstat>');
      buf.writeln('  </D:response>');
      buf.writeln('</D:multistatus>');

      final document = XmlDocument.parse(buf.toString());
      final responses = document.findAllElements('D:response');

      final href = responses.first
          .findElements('D:href')
          .firstOrNull
          ?.innerText
          .trim() ?? '';
      final name = href.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';

      expect(name, 'backup.db');
    });
  });

  group('WebDavHelper listFiles ADR-0010 布局', () {
    test('只列固定名 DB + 子目录内容，旧前缀文件被过滤', () async {
      final helper = _helperWith(MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/daily_gig_journal/')) {
          return http.Response(
            _buildPropfindResponse('daily_gig_journal', [
              'daily_gig_journal.db',
              // 旧格式备份：必须被过滤（ADR-0010 §6）
              'daily_gig_backup_2025-06-14T08-30-00.db',
            ]),
            207,
          );
        }
        if (path.endsWith('/images/')) {
          return http.Response(
            _buildPropfindResponse('daily_gig_journal/images',
                ['img_2025-06-14_000001.png']),
            207,
          );
        }
        if (path.endsWith('/drafts/')) {
          return http.Response(
            _buildPropfindResponse('daily_gig_journal/drafts',
                ['draft_2025-06-14_000001.json']),
            207,
          );
        }
        if (path.endsWith('/trashed/')) {
          return http.Response(
            _buildPropfindResponse(
                'daily_gig_journal/trashed', ['img_old.png']),
            207,
          );
        }
        return http.Response('', 404);
      }));

      final result = await helper.listFiles();

      expect(result.isSuccess, isTrue);
      final names = result.files.map((f) => f.name).toSet();
      expect(names, {
        'daily_gig_journal.db',
        'img_2025-06-14_000001.png',
        'draft_2025-06-14_000001.json',
        'img_old.png',
      });
      expect(
        names.any((n) => n.startsWith('daily_gig_backup')),
        isFalse,
      );
    });

    test('备份目录不存在 (404) 返回空列表成功', () async {
      final helper = _helperWith(MockClient((req) async {
        return http.Response('', 404);
      }));

      final result = await helper.listFiles();

      expect(result.isSuccess, isTrue);
      expect(result.files, isEmpty);
    });

    test('认证失败向上传播错误', () async {
      final helper = _helperWith(MockClient((req) async {
        return http.Response('', 401);
      }));

      final result = await helper.listFiles();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('认证失败'));
    });
  });
}
