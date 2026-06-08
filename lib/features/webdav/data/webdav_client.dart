import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

class WebdavConfig {
  const WebdavConfig({
    required this.scheme,
    required this.host,
    this.port,
    this.basePath,
    this.username,
    this.password,
  });

  final String scheme;
  final String host;
  final int? port;
  final String? basePath;
  final String? username;
  final String? password;

  String get origin => '$scheme://${port == null ? host : '$host:$port'}';

  String get normalizedBasePath {
    var p = basePath?.trim() ?? '';
    if (p.isEmpty) return '/';
    if (!p.startsWith('/')) p = '/$p';
    return p;
  }

  String get baseUrl => '$origin$normalizedBasePath';

  String? get authHeader {
    final u = username;
    if (u == null || u.isEmpty) return null;
    final raw = '$u:${password ?? ''}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  /// Percent-encoded full URL for a file at [absolutePath] (a decoded absolute
  /// server path). basePath is already part of the path, so only origin is
  /// prepended.
  String streamUrl(String absolutePath) {
    final enc = absolutePath
        .split('/')
        .map((s) => s.isEmpty ? s : Uri.encodeComponent(s))
        .join('/');
    return '$origin$enc';
  }
}

class WebdavEntry {
  const WebdavEntry({
    required this.name,
    required this.path,
    required this.isDir,
    this.size,
  });

  final String name;

  /// Decoded absolute server path, e.g. `/dav/folder/track.mp3`.
  final String path;
  final bool isDir;
  final int? size;
}

class WebdavException implements Exception {
  const WebdavException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WebdavClient {
  WebdavClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final Dio _dio;

  /// PROPFIND Depth:0 on the root. Returns normally on success, throws
  /// [WebdavException] with a user-readable message otherwise.
  Future<void> testConnection(WebdavConfig config) async {
    final res = await _propfind(config, _dirUrl(config, null), depth: 0);
    final code = res.statusCode ?? 0;
    if (code == 200 || code == 207) return;
    throw WebdavException(_describeStatus(code));
  }

  /// Lists immediate children of [dirPath] (absolute server path, decoded).
  /// Null lists the configured base path. Directories first, then files,
  /// both alphabetical.
  Future<List<WebdavEntry>> list(WebdavConfig config, [String? dirPath]) async {
    final res = await _propfind(config, _dirUrl(config, dirPath), depth: 1);
    final code = res.statusCode ?? 0;
    if (code != 200 && code != 207) {
      throw WebdavException(_describeStatus(code));
    }
    final self = dirPath ?? config.normalizedBasePath;
    final entries = _parse(res.data?.toString() ?? '', self);
    entries.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Playable URL for a file's absolute server [path], percent-encoded.
  String fileUrl(WebdavConfig config, String path) => config.streamUrl(path);

  /// Downloads a file's bytes (used for small files like subtitles; audio is
  /// streamed by the player, not downloaded).
  Future<List<int>> getBytes(WebdavConfig config, String path) async {
    final auth = config.authHeader;
    try {
      final res = await _dio.get<List<int>>(
        config.streamUrl(path),
        options: Options(
          responseType: ResponseType.bytes,
          headers: auth == null ? null : {'Authorization': auth},
        ),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw WebdavException(_describeDio(e));
    }
  }

  String _dirUrl(WebdavConfig config, String? dirPath) {
    final path = dirPath ?? config.normalizedBasePath;
    var url = '${config.origin}${_encodePath(path)}';
    if (!url.endsWith('/')) url += '/';
    return url;
  }

  String _encodePath(String decodedPath) => decodedPath
      .split('/')
      .map((s) => s.isEmpty ? s : Uri.encodeComponent(s))
      .join('/');

  Future<Response<dynamic>> _propfind(
    WebdavConfig config,
    String url, {
    required int depth,
  }) async {
    final auth = config.authHeader;
    final headers = <String, String>{
      'Depth': '$depth',
      'Content-Type': 'application/xml; charset=utf-8',
    };
    if (auth != null) headers['Authorization'] = auth;
    try {
      return await _dio.request<dynamic>(
        url,
        data: _propfindBody,
        options: Options(
          method: 'PROPFIND',
          headers: headers,
          validateStatus: (s) => s != null && s < 500,
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (e) {
      throw WebdavException(_describeDio(e));
    }
  }

  static const _propfindBody =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:resourcetype/><d:getcontentlength/>'
      '</d:prop></d:propfind>';

  List<WebdavEntry> _parse(String body, String selfPath) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } on XmlException {
      throw const WebdavException('返回内容不是合法 XML（可能不是 WebDAV 服务）');
    }

    final self = _stripSlash(selfPath);
    final out = <WebdavEntry>[];
    for (final resp in doc.findAllElements('response', namespace: '*')) {
      final href = _text(resp, 'href');
      if (href == null) continue;
      final path = Uri.decodeFull(Uri.parse(href).path);
      if (_stripSlash(path) == self) continue; // skip the directory itself

      final prop = _okProp(resp);
      if (prop == null) continue;

      final rtype = _child(prop, 'resourcetype');
      final isDir =
          rtype != null &&
          rtype.findElements('collection', namespace: '*').isNotEmpty;
      final len = _text(prop, 'getcontentlength');
      out.add(
        WebdavEntry(
          name: _nameOf(path),
          path: path,
          isDir: isDir,
          size: len == null ? null : int.tryParse(len),
        ),
      );
    }
    return out;
  }

  XmlElement? _okProp(XmlElement response) {
    XmlElement? fallback;
    for (final ps in response.findElements('propstat', namespace: '*')) {
      fallback ??= ps;
      final status = _text(ps, 'status') ?? '';
      if (status.contains('200')) return _child(ps, 'prop');
    }
    return fallback == null ? null : _child(fallback, 'prop');
  }

  XmlElement? _child(XmlElement parent, String local) {
    final m = parent.findElements(local, namespace: '*');
    return m.isEmpty ? null : m.first;
  }

  String? _text(XmlElement parent, String local) {
    final e = _child(parent, local);
    if (e == null) return null;
    final t = e.innerText.trim();
    return t.isEmpty ? null : t;
  }

  String _nameOf(String path) {
    final p = _stripSlash(path);
    final i = p.lastIndexOf('/');
    return i < 0 ? p : p.substring(i + 1);
  }

  String _stripSlash(String s) =>
      (s.length > 1 && s.endsWith('/')) ? s.substring(0, s.length - 1) : s;

  String _describeStatus(int code) {
    if (code == 401 || code == 403) return '认证失败，检查用户名 / 密码';
    if (code == 404) return '路径不存在（404），检查路径配置';
    if (code == 405) return '服务器不支持 WebDAV（PROPFIND 405），检查地址 / 路径';
    return '服务器返回 $code';
  }

  String _describeDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时';
      case DioExceptionType.connectionError:
        return '无法连接到主机，检查地址 / 端口 / 网络';
      case DioExceptionType.badCertificate:
        return '证书校验失败（https）';
      default:
        return e.message ?? '连接失败';
    }
  }
}

final webdavClientProvider = Provider<WebdavClient>((ref) {
  return WebdavClient();
});
