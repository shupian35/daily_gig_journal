import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

/// WebDAV 云备份客户端
/// 支持坚果云等标准 WebDAV 服务器
class WebDavHelper {
  final String serverUrl;
  final String username;
  final String password;

  /// 备份文件存放的子目录
  static const backupSubDir = 'daily_gig_journal';

  /// ADR-0010 固定名云端数据库文件
  static const cloudDbName = 'daily_gig_journal.db';

  /// ADR-0010 布局子目录
  static const adr0010SubDirs = ['images', 'drafts', 'trashed'];

  /// 可注入的 HTTP 客户端（仅测试用）；为空时内部自建并在请求后关闭
  final http.Client? httpClient;

  WebDavHelper({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.httpClient,
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
    final client = httpClient ?? http.Client();
    final owned = httpClient == null;
    try {
      final streamed = await client.send(request);
      return await http.Response.fromStream(streamed);
    } finally {
      if (owned) client.close();
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

  /// 确保备份子目录下某个子目录存在（如 images/ 或 drafts/），不存在则创建
  /// [subDir] 相对 backupSubDir 的子路径，如 'images' / 'drafts' / 'trashed'
  Future<WebDavResult> ensureSubDir(String subDir) async {
    try {
      // 先确保父级备份目录存在
      final parentResult = await ensureBackupDir();
      if (!parentResult.isSuccess) return parentResult;

      final subUrl = '$_backupPath/$subDir/';
      // PROPFIND 检查子目录是否存在
      final checkRequest = http.Request('PROPFIND', Uri.parse(subUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '0';
      final checkResp = await _send(checkRequest);
      if (checkResp.statusCode == 207) {
        return const WebDavResult.success('子目录已存在');
      }
      // 不存在则 MKCOL
      final mkcolRequest = http.Request('MKCOL', Uri.parse(subUrl))
        ..headers.addAll(_headers);
      final mkcolResp = await _send(mkcolRequest);
      if (mkcolResp.statusCode == 201 || mkcolResp.statusCode == 405) {
        return const WebDavResult.success('子目录已创建');
      }
      if (mkcolResp.statusCode == 401 || mkcolResp.statusCode == 403) {
        return const WebDavResult.error('认证失败，请检查账号和密码');
      }
      return WebDavResult.error('创建子目录失败 (HTTP ${mkcolResp.statusCode})');
    } on SocketException {
      return const WebDavResult.error('网络连接失败');
    } catch (e) {
      return WebDavResult.error('创建子目录失败: $e');
    }
  }

  /// HEAD 探测文件是否存在
  /// 返回 true 表示存在（200/204），false 表示不存在（404）或网络失败
  Future<bool> headFile(String remoteRelativePath) async {
    try {
      final url = '$_backupPath/$remoteRelativePath';
      final request = http.Request('HEAD', Uri.parse(url))
        ..headers.addAll(_headers);
      final resp = await _send(request);
      return resp.statusCode == 200 || resp.statusCode == 204 || resp.statusCode == 207;
    } catch (_) {
      return false;
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

  /// 直接上传字节流到备份子目录 (ADR-0010 增量备份)。
  /// [remoteRelativePath] 相对 backupSubDir 的路径, 如 'images/img_x.png' 或 'daily_gig_journal.db'。
  Future<WebDavResult> uploadBytes(
    List<int> bytes,
    String remoteRelativePath,
  ) async {
    try {
      final dirResult = await ensureBackupDir();
      if (!dirResult.isSuccess) return dirResult;

      final url = '$_backupPath/$remoteRelativePath';
      final request = http.Request('PUT', Uri.parse(url))
        ..headers.addAll(_headers)
        ..bodyBytes = bytes;
      final resp = await _send(request);
      if (resp.statusCode == 201 ||
          resp.statusCode == 200 ||
          resp.statusCode == 204) {
        return const WebDavResult.success('上传成功');
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavResult.error('认证失败，请检查账号和密码');
      }
      if (resp.statusCode == 507) {
        return const WebDavResult.error('云盘空间不足');
      }
      return WebDavResult.error('上传失败 (HTTP ${resp.statusCode})');
    } on SocketException {
      return const WebDavResult.error('网络连接失败');
    } catch (e) {
      return WebDavResult.error('上传失败: $e');
    }
  }

  /// 下载文件到字节 (ADR-0010 软删除用)。
  /// [remoteRelativePath] 相对 backupSubDir 的路径。
  Future<WebDavBytesResult> downloadFileToBytes(String remoteRelativePath) async {
    try {
      final url = '$_backupPath/$remoteRelativePath';
      final request = http.Request('GET', Uri.parse(url))
        ..headers.addAll(_headers);
      final resp = await _send(request);
      if (resp.statusCode == 200) {
        if (resp.bodyBytes.isEmpty) {
          return const WebDavBytesResult.error('下载的文件为空');
        }
        return WebDavBytesResult.success(resp.bodyBytes);
      }
      if (resp.statusCode == 404) {
        return const WebDavBytesResult.error('文件不存在');
      }
      return WebDavBytesResult.error('下载失败 (HTTP ${resp.statusCode})');
    } catch (e) {
      return WebDavBytesResult.error('下载失败: $e');
    }
  }

  /// 列出指定子目录的文件 (ADR-0010 增量备份用)。
  /// [subDir] 相对 backupSubDir 的子目录, 如 'images' / 'drafts' / 'trashed'。
  Future<WebDavListResult> listFilesInSubDir(String subDir) async {
    try {
      final subUrl = '$_backupPath/$subDir/';
      final request = http.Request('PROPFIND', Uri.parse(subUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '1';
      final resp = await _send(request);
      if (resp.statusCode == 404) {
        return const WebDavListResult.success([]);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const WebDavListResult.error('认证失败，请检查账号和密码');
      }
      if (resp.statusCode == 207) {
        final files = await _listFilesInDir(subUrl);
        files.sort(_newestFirst);
        return WebDavListResult.success(files);
      }
      return WebDavListResult.error('列出文件失败 (HTTP ${resp.statusCode})');
    } on SocketException {
      return const WebDavListResult.error('网络连接失败');
    } catch (e) {
      return WebDavListResult.error('列出文件失败: $e');
    }
  }

  /// 从 WebDAV 下载文件到本地
  /// [remotePath] 可以是文件名、绝对路径 (/dav/...)、或完整 URL
  Future<WebDavResult> downloadFile(
    String remotePath,
    String localPath,
  ) async {
    try {
      final url = _resolveUrl(remotePath);

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

  /// 列出云端 ADR-0010 布局资源（§6 只显示新格式资源）：
  /// 固定名 [cloudDbName] + images/ + drafts/ + trashed/ 子目录内容。
  /// 旧前缀 daily_gig_backup_* 与根目录 fallback 已废弃，不再列出。
  Future<WebDavListResult> listFiles() async {
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
      if (resp.statusCode != 207) {
        return WebDavListResult.error('列出文件失败 (HTTP ${resp.statusCode})');
      }

      // 根目录只保留固定名 DB
      final files = await _listFilesInDir(_backupDirUrl)
        ..retainWhere((f) => f.name == cloudDbName);

      // 子目录资源（images / drafts / trashed）
      for (final sub in adr0010SubDirs) {
        final r = await listFilesInSubDir(sub);
        if (!r.isSuccess) return WebDavListResult.error(r.errorMessage!);
        files.addAll(r.files);
      }

      files.sort(_newestFirst);
      return WebDavListResult.success(files);
    } on SocketException {
      return const WebDavListResult.error('网络连接失败');
    } catch (e) {
      return WebDavListResult.error('列出文件失败: $e');
    }
  }

  /// 按类型化时间新→旧排序（解析失败视为最旧，排最后）。
  static int _newestFirst(WebDavFileInfo a, WebDavFileInfo b) =>
      (b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0));

  /// PROPFIND 指定目录并解析文件列表
  Future<List<WebDavFileInfo>> _listFilesInDir(String dirUrl) async {
    try {
      final url = dirUrl.endsWith('/') ? dirUrl : '$dirUrl/';
      final request = http.Request('PROPFIND', Uri.parse(url))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '1';

      final resp = await _send(request);
      if (resp.statusCode != 207) return [];

      final document = XmlDocument.parse(resp.body);
      final files = <WebDavFileInfo>[];

      // 兼容不同 WebDAV 服务器的大小写命名空间前缀
      final responses = [
        ...document.findAllElements('D:response'),
        ...document.findAllElements('d:response'),
      ];
      if (responses.isEmpty) {
        // 兜底：按本地名称搜索
        responses.addAll(document.descendantElements
            .where((e) => e.name.local == 'response'));
      }

      for (final response in responses) {
        final href = _davText(response, 'href');
        final displayName = _davTextDeep(response, 'displayname');
        final contentLength = _davTextDeep(response, 'getcontentlength');
        final lastModified = _davTextDeep(response, 'getlastmodified');

        final name = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : href.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
        final size = int.tryParse(contentLength ?? '') ?? 0;
        final isCollection = href.endsWith('/');

        if (isCollection || name.isEmpty) continue;

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

  /// 将各种路径格式解析为完整 URL
  String _resolveUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl; // 已经是完整 URL
    }
    if (pathOrUrl.startsWith('/')) {
      // 绝对路径，拼接到 baseUrl 的 origin
      final uri = Uri.parse(_baseUrl);
      return '${uri.scheme}://${uri.host}$pathOrUrl';
    }
    // 纯文件名，拼接到备份目录
    return '$_backupPath/$pathOrUrl';
  }

  /// 从 DAV 元素中查找子元素文本（兼容大小写命名空间前缀）
  static String _davText(XmlElement parent, String localName) {
    final elements = [
      ...parent.findElements('D:$localName'),
      ...parent.findElements('d:$localName'),
    ];
    if (elements.isEmpty) {
      final fallback = parent.descendantElements
          .where((e) => e.name.local == localName)
          .firstOrNull;
      return fallback?.innerText.trim() ?? '';
    }
    return elements.first.innerText.trim();
  }

  /// 从 DAV 深层嵌套中查找子元素文本
  /// 路径: propstat → prop → target
  static String? _davTextDeep(XmlElement parent, String localName) {
    final propstats = [
      ...parent.findElements('D:propstat'),
      ...parent.findElements('d:propstat'),
    ];
    if (propstats.isEmpty) {
      final fallback = parent.descendantElements
          .where((e) => e.name.local == 'propstat');
      for (final ps in fallback) {
        final props = [
          ...ps.findElements('D:prop'),
          ...ps.findElements('d:prop'),
        ];
        if (props.isEmpty) {
          final pFallback = ps.descendantElements
              .where((e) => e.name.local == 'prop');
          for (final p in pFallback) {
            final result = _davText(p, localName);
            if (result.isNotEmpty) return result;
          }
        } else {
          for (final p in props) {
            final result = _davText(p, localName);
            if (result.isNotEmpty) return result;
          }
        }
      }
      return null;
    }
    for (final ps in propstats) {
      final props = [
        ...ps.findElements('D:prop'),
        ...ps.findElements('d:prop'),
      ];
      if (props.isEmpty) {
        final pFallback = ps.descendantElements
            .where((e) => e.name.local == 'prop');
        for (final p in pFallback) {
          final result = _davText(p, localName);
          if (result.isNotEmpty) return result;
        }
      } else {
        for (final p in props) {
          final result = _davText(p, localName);
          if (result.isNotEmpty) return result;
        }
      }
    }
    return null;
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

/// WebDAV 文件信息。
///
/// 协议层的 HTTP-date 表示细节（RFC 1123，如
/// `Mon, 14 Jun 2026 08:30:00 GMT`）在此构造时一次性消化为类型化的
/// [lastModified]；解析失败得 null。注意不能用 [DateTime.parse]：
/// 它只接受 ISO 8601（这正是旧实现的 bug 根源）。
class WebDavFileInfo {
  final String name;
  final String href;
  final int size;

  /// PROPFIND getlastmodified 原始字符串（HTTP-date）。
  final String lastModifiedRaw;

  /// 类型化时间（本地时区）；原始串为空或不可解析时为 null。
  final DateTime? lastModified;

  WebDavFileInfo({
    required this.name,
    required this.href,
    required this.size,
    required String lastModified,
  })  : lastModifiedRaw = lastModified,
        lastModified = parseHttpDate(lastModified);

  /// 解析 RFC 1123 HTTP-date 为本地时间；无法解析返回 null。
  static DateTime? parseHttpDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return HttpDate.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 将 [lastModified] 转为中文本地时间显示；
  /// 解析失败时退回原始字符串。
  /// 输入：Mon, 14 Jun 2025 08:30:00 GMT
  /// 输出：2025年6月14日 16:30（本地时区）
  String get formattedDate {
    final local = lastModified;
    if (local == null) return lastModifiedRaw;
    final fmt = DateFormat('yyyy年M月d日 HH:mm');
    return fmt.format(local);
  }
}

/// 下载字节结果 (公开, 供 BackupService 软删除使用)
class WebDavBytesResult {
  final bool isSuccess;
  final List<int>? bytes;
  final String? errorMessage;
  const WebDavBytesResult.success(this.bytes)
      : isSuccess = true,
        errorMessage = null;
  const WebDavBytesResult.error(this.errorMessage)
      : isSuccess = false,
        bytes = null;
}
