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

  /// 备份文件存放的子目录
  static const backupSubDir = 'daily_gig_journal';

  WebDavHelper({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  /// 构建基础 URL（去掉尾部斜杠）
  String get _baseUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;

  /// 备份目录完整 URL（用于文件操作，无尾部斜杠）
  String get _backupPath => '$_baseUrl/$backupSubDir';

  /// 备份目录 URL（用于 PROPFIND/MKCOL，带尾部斜杠）
  String get _backupDirUrl => '$_backupPath/';

  /// 构建请求头
  Map<String, String> get _headers {
    final auth = base64Encode(utf8.encode('$username:$password'));
    return {
      'Authorization': 'Basic $auth',
      'User-Agent': 'DailyGigJournal/1.0',
    };
  }

  /// 发送 HTTP 请求并返回响应，自动管理客户端生命周期
  Future<http.Response> _send(http.BaseRequest request) async {
    final client = http.Client();
    try {
      final streamed = await client.send(request);
      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  // ==================== 目录管理 ====================

  /// 确保备份子目录存在，不存在则创建
  Future<WebDavResult> ensureBackupDir() async {
    try {
      // 先检查目录是否存在
      final checkRequest = http.Request('PROPFIND', Uri.parse(_backupDirUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '0';

      final checkResp = await _send(checkRequest);

      if (checkResp.statusCode == 207) {
        return const WebDavResult.success('备份目录已存在');
      }

      // 目录不存在（404），创建它
      if (checkResp.statusCode == 404) {
        return await _createBackupDir();
      }

      // 可能是其他状态，尝试创建
      // 坚果云在 PROPFIND 不存在路径时可能返回不同的状态码
      final createResult = await _createBackupDir();
      if (createResult.isSuccess) return createResult;

      // 如果创建失败但 PROPFIND 没报错，说明目录可能已存在
      return const WebDavResult.success('备份目录可用');
    } on SocketException {
      return const WebDavResult.error('无法连接服务器');
    } catch (e) {
      return WebDavResult.error('检查目录失败: $e');
    }
  }

  /// 创建备份子目录 (MKCOL)
  Future<WebDavResult> _createBackupDir() async {
    try {
      final request = http.Request('MKCOL', Uri.parse(_backupDirUrl))
        ..headers.addAll(_headers);

      final resp = await _send(request);

      // 201 Created: 创建成功
      // 405 Method Not Allowed: 目录已存在
      // 409 Conflict: 父目录不存在（递归创建）
      if (resp.statusCode == 201) {
        return const WebDavResult.success('备份目录已创建');
      }
      if (resp.statusCode == 405) {
        return const WebDavResult.success('备份目录已存在');
      }
      if (resp.statusCode == 409) {
        // 尝试先创建父级目录 — 坚果云一般不会出现此情况
        return await _createParentDirs();
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavResult.error('认证失败，请检查账号和密码');
      }
      return WebDavResult.error('创建目录失败 (HTTP ${resp.statusCode})');
    } catch (e) {
      return WebDavResult.error('创建目录失败: $e');
    }
  }

  /// 递归创建父目录
  Future<WebDavResult> _createParentDirs() async {
    // 对坚果云等大多数 WebDAV 服务器，只需创建目标目录即可
    // 如果返回 409，说明需要逐级创建
    final parts = backupSubDir.split('/');
    var currentPath = _baseUrl;

    for (final part in parts) {
      if (part.isEmpty) continue;
      currentPath = '$currentPath/$part';

      final request = http.Request('MKCOL', Uri.parse('$currentPath/'))
        ..headers.addAll(_headers);

      final resp = await _send(request);

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavResult.error('认证失败，请检查账号和密码');
      }
      // 201 = 创建成功, 405 = 已存在, 都继续
    }
    return const WebDavResult.success('备份目录已创建');
  }

  // ==================== 连接测试 ====================

  /// 测试连接：尝试 PROPFIND 根目录，并确保备份目录存在
  Future<WebDavResult> testConnection() async {
    try {
      final request = http.Request('PROPFIND', Uri.parse(_baseUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '0';

      final resp = await _send(request);

      if (resp.statusCode == 401) {
        return WebDavResult.error('认证失败，请检查账号和密码');
      }
      if (resp.statusCode != 207 && resp.statusCode != 200) {
        return WebDavResult.error('服务器返回异常状态: ${resp.statusCode}');
      }

      // 确保备份目录存在
      final dirResult = await ensureBackupDir();
      if (!dirResult.isSuccess) return dirResult;

      return const WebDavResult.success('连接成功！服务器可达，备份目录已就绪');
    } on SocketException {
      return const WebDavResult.error('无法连接服务器，请检查网络和地址');
    } catch (e) {
      return WebDavResult.error('连接失败: $e');
    }
  }

  // ==================== 文件操作 ====================

  /// 上传文件到 WebDAV 备份目录
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

      // 确保备份目录存在
      final dirResult = await ensureBackupDir();
      if (!dirResult.isSuccess) return dirResult;

      final bytes = await file.readAsBytes();
      final url = '$_backupPath/$remoteFileName';

      final request = http.Request('PUT', Uri.parse(url))
        ..headers.addAll(_headers)
        ..bodyBytes = bytes;

      final resp = await _send(request);

      if (resp.statusCode == 201 || resp.statusCode == 200 || resp.statusCode == 204) {
        return const WebDavResult.success('备份成功！文件已上传到云盘');
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
  /// [remotePath] 可以是文件名（自动拼接到备份目录）或完整 href
  Future<WebDavResult> downloadFile(
    String remotePath,
    String localPath,
  ) async {
    try {
      // 如果 remotePath 已经是完整 URL，直接使用；否则拼接到备份目录
      final url = remotePath.startsWith('http')
          ? remotePath
          : '$_backupPath/$remotePath';

      final request = http.Request('GET', Uri.parse(url))
        ..headers.addAll(_headers);

      final resp = await _send(request);

      if (resp.statusCode == 200) {
        if (resp.bodyBytes.isEmpty) {
          return const WebDavResult.error('下载的文件为空，备份可能已损坏');
        }

        final file = File(localPath);
        final bakPath = '$localPath.bak';
        final restorePath = '$localPath.restore';

        if (await file.exists()) {
          await file.copy(bakPath);
        }

        try {
          await file.writeAsBytes(resp.bodyBytes);
          return const WebDavResult.success('恢复成功！数据已从云盘下载，请重启应用');
        } on FileSystemException {
          // 数据库文件被锁定，写入 .restore 文件，重启后自动替换
          try {
            await File(restorePath).writeAsBytes(resp.bodyBytes);
            return const WebDavResult.success(
              '数据库文件被占用，已保存到临时位置，请重启应用以完成恢复',
            );
          } catch (e2) {
            return WebDavResult.error('写入恢复文件失败: $e2');
          }
        } catch (e) {
          final bakFile = File(bakPath);
          if (await bakFile.exists()) {
            await bakFile.copy(localPath);
          }
          return WebDavResult.error('写入文件失败: $e');
        }
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

  /// 列出备份目录中的文件
  Future<WebDavListResult> listFiles({String prefix = 'daily_gig_backup'}) async {
    try {
      // PROPFIND 备份子目录（带尾部斜杠）
      final request = http.Request('PROPFIND', Uri.parse(_backupDirUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '1';

      final resp = await _send(request);

      if (resp.statusCode == 404) {
        // 备份目录不存在
        return const WebDavListResult.success([]);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavListResult.error('认证失败，请检查账号和密码');
      }

      if (resp.statusCode == 207) {
        var files = await _listFilesInDir(_backupDirUrl, prefix);

        // 如果子目录为空，也检查根目录（兼容旧版本备份）
        if (files.isEmpty) {
          files = await _listFilesInDir(_baseUrl, prefix);
        }

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

  /// PROPFIND 指定目录并解析文件列表
  Future<List<WebDavFileInfo>> _listFilesInDir(
    String dirUrl,
    String prefix,
  ) async {
    try {
      final url = dirUrl.endsWith('/') ? dirUrl : '$dirUrl/';
      final request = http.Request('PROPFIND', Uri.parse(url))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '1';

      final resp = await _send(request);
      if (resp.statusCode != 207) return [];

      final document = XmlDocument.parse(resp.body);
      final files = <WebDavFileInfo>[];
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

        if (isCollection || name.isEmpty) continue;
        if (prefix.isNotEmpty && !name.startsWith(prefix)) continue;

        files.add(WebDavFileInfo(
          name: name,
          href: href,
          size: size,
          lastModified: lastModified ?? '',
        ));
      }
      return files;
    } catch (_) {
      return [];
    }
  }

  /// 删除备份目录中的远程文件
  Future<WebDavResult> deleteFile(String remoteFileName) async {
    try {
      final url = '$_backupPath/$remoteFileName';

      final request = http.Request('DELETE', Uri.parse(url))
        ..headers.addAll(_headers);

      final resp = await _send(request);

      if (resp.statusCode == 200 || resp.statusCode == 204 || resp.statusCode == 202) {
        return const WebDavResult.success('已删除云盘备份文件');
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

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
