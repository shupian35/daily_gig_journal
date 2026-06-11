import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// WebDAV 云备份客户端
/// 支持坚果云等标准 WebDAV 服务器
class WebDavHelper {
  final String serverUrl;
  final String username;
  final String password;

  WebDavHelper({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  /// 构建基础 URL（去掉尾部斜杠）
  String get _baseUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;

  /// 构建请求头
  Map<String, String> get _headers {
    final auth = base64Encode(utf8.encode('$username:$password'));
    return {
      'Authorization': 'Basic $auth',
      'User-Agent': 'DailyGigJournal/1.0',
    };
  }

  /// HTTP 客户端（不验证 SSL 证书，兼容自签名服务器）
  http.Client get _client {
    final client = http.Client();
    return client;
  }

  /// 测试连接：尝试 PROPFIND 根目录
  Future<WebDavResult> testConnection() async {
    try {
      final request = http.Request('PROPFIND', Uri.parse(_baseUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '0';

      final streamed = await _client.send(request);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 207 || resp.statusCode == 200 || resp.statusCode == 401) {
        if (resp.statusCode == 401) {
          return WebDavResult.error('认证失败，请检查账号和密码');
        }
        return const WebDavResult.success('连接成功！服务器可达');
      }
      return WebDavResult.error('服务器返回异常状态: ${resp.statusCode}');
    } on SocketException {
      return const WebDavResult.error('无法连接服务器，请检查网络和地址');
    } catch (e) {
      return WebDavResult.error('连接失败: $e');
    }
  }

  /// 上传文件到 WebDAV
  /// [localPath] 本地文件路径
  /// [remoteFileName] 远程文件名（不含路径前缀）
  Future<WebDavResult> uploadFile(
    String localPath,
    String remoteFileName,
  ) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        return const WebDavResult.error('本地文件不存在');
      }

      final bytes = await file.readAsBytes();
      final url = '$_baseUrl/$remoteFileName';

      final request = http.Request('PUT', Uri.parse(url))
        ..headers.addAll(_headers)
        ..bodyBytes = bytes;

      final streamed = await _client.send(request);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 201 || resp.statusCode == 200 || resp.statusCode == 204) {
        return WebDavResult.success('备份成功！文件已上传到云盘');
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavResult.error('认证失败，请检查账号和密码');
      }
      if (resp.statusCode == 507) {
        return const WebDavResult.error('云盘空间不足');
      }
      return WebDavResult.error('上传失败 (HTTP ${resp.statusCode})');
    } on SocketException {
      return const WebDavResult.error('网络连接失败，请检查网络');
    } catch (e) {
      return WebDavResult.error('上传失败: $e');
    }
  }

  /// 从 WebDAV 下载文件到本地
  /// [remoteFileName] 远程文件名
  /// [localPath] 本地保存路径
  Future<WebDavResult> downloadFile(
    String remoteFileName,
    String localPath,
  ) async {
    try {
      final url = '$_baseUrl/$remoteFileName';

      final request = http.Request('GET', Uri.parse(url))
        ..headers.addAll(_headers);

      final streamed = await _client.send(request);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(resp.bodyBytes);
        return WebDavResult.success('恢复成功！数据已从云盘下载');
      }
      if (resp.statusCode == 404) {
        return const WebDavResult.error('云盘上未找到备份文件');
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavResult.error('认证失败，请检查账号和密码');
      }
      return WebDavResult.error('下载失败 (HTTP ${resp.statusCode})');
    } on SocketException {
      return const WebDavResult.error('网络连接失败，请检查网络');
    } catch (e) {
      return WebDavResult.error('下载失败: $e');
    }
  }

  /// 列出远程备份文件
  Future<WebDavListResult> listFiles({String prefix = 'daily_gig_backup'}) async {
    try {
      final request = http.Request('PROPFIND', Uri.parse(_baseUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '1';

      final streamed = await _client.send(request);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavListResult.error('认证失败，请检查账号和密码');
      }

      if (resp.statusCode == 207) {
        final document = XmlDocument.parse(resp.body);
        final files = <WebDavFileInfo>[];

        // 解析 DAV:multistatus 响应
        final responses = document.findAllElements('D:response');
        for (final response in responses) {
          final href = response
              .findElements('D:href')
              .firstOrNull
              ?.innerText
              .trim() ?? '';
          final displayName = response
              .findElements('D:propstat')
              .expand((ps) => ps.findElements('D:prop'))
              .expand((p) => p.findElements('D:displayname'))
              .firstOrNull
              ?.innerText
              .trim() ?? '';
          final contentLength = response
              .findElements('D:propstat')
              .expand((ps) => ps.findElements('D:prop'))
              .expand((p) => p.findElements('D:getcontentlength'))
              .firstOrNull
              ?.innerText
              .trim();
          final lastModified = response
              .findElements('D:propstat')
              .expand((ps) => ps.findElements('D:prop'))
              .expand((p) => p.findElements('D:getlastmodified'))
              .firstOrNull
              ?.innerText
              .trim();

          final name = displayName.isNotEmpty
              ? displayName
              : href.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
          final size = int.tryParse(contentLength ?? '') ?? 0;
          final isCollection = href.endsWith('/');

          // 跳过目录本身、非备份文件
          if (isCollection || name.isEmpty) continue;
          if (prefix.isNotEmpty && !name.startsWith(prefix)) continue;

          files.add(WebDavFileInfo(
            name: name,
            href: href,
            size: size,
            lastModified: lastModified ?? '',
          ));
        }

        // 按修改时间降序排列
        files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        return WebDavListResult.success(files);
      }

      return WebDavListResult.error('列出文件失败 (HTTP ${resp.statusCode})');
    } on SocketException {
      return const WebDavListResult.error('网络连接失败');
    } catch (e) {
      return WebDavListResult.error('列出文件失败: $e');
    }
  }

  /// 删除远程文件
  Future<WebDavResult> deleteFile(String remoteFileName) async {
    try {
      final url = '$_baseUrl/$remoteFileName';

      final request = http.Request('DELETE', Uri.parse(url))
        ..headers.addAll(_headers);

      final streamed = await _client.send(request);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200 || resp.statusCode == 204 || resp.statusCode == 202) {
        return WebDavResult.success('已删除云盘备份文件');
      }
      if (resp.statusCode == 404) {
        return const WebDavResult.error('文件不存在');
      }
      return WebDavResult.error('删除失败 (HTTP ${resp.statusCode})');
    } catch (e) {
      return WebDavResult.error('删除失败: $e');
    }
  }
}

/// WebDAV 操作结果
class WebDavResult {
  final bool isSuccess;
  final String message;

  const WebDavResult.success(this.message) : isSuccess = true;
  const WebDavResult.error(this.message) : isSuccess = false;
}

/// 列出文件的结果
class WebDavListResult {
  final bool isSuccess;
  final String? errorMessage;
  final List<WebDavFileInfo> files;

  const WebDavListResult.success(this.files)
      : isSuccess = true,
        errorMessage = null;
  const WebDavListResult.error(this.errorMessage)
      : isSuccess = false,
        files = const [];
}

/// WebDAV 文件信息
class WebDavFileInfo {
  final String name;
  final String href;
  final int size;
  final String lastModified;

  const WebDavFileInfo({
    required this.name,
    required this.href,
    required this.size,
    required this.lastModified,
  });

  /// 格式化文件大小
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
