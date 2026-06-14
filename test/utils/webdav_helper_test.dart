import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// 模拟坚果云 PROPFIND 响应来验证解析逻辑
String _buildPropfindResponse(List<String> fileNames) {
  final buf = StringBuffer();
  buf.writeln('<?xml version="1.0" encoding="utf-8"?>');
  buf.writeln('<D:multistatus xmlns:D="DAV:">');
  for (final name in fileNames) {
    buf.writeln('  <D:response>');
    buf.writeln('    <D:href>/dav/daily_gig_journal/$name</D:href>');
    buf.writeln('    <D:propstat>');
    buf.writeln('      <D:prop>');
    buf.writeln('        <D:displayname>$name</D:displayname>');
    buf.writeln('        <D:getcontentlength>12345</D:getcontentlength>');
    buf.writeln('        <D:getlastmodified>Mon, 14 Jun 2025 08:30:00 GMT</D:getlastmodified>');
    buf.writeln('      </D:prop>');
    buf.writeln('      <D:status>HTTP/1.1 200 OK</D:status>');
    buf.writeln('    </D:propstat>');
    buf.writeln('  </D:response>');
  }
  buf.writeln('</D:multistatus>');
  return buf.toString();
}

void main() {
  group('WebDavHelper listFiles XML 解析', () {
    test('解析标准 PROPFIND 响应', () {
      final xml = _buildPropfindResponse([
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
      final xml = _buildPropfindResponse(['backup.db']);
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
}
