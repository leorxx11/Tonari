import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/media_proxy.dart';
import '../../../core/scanner/file_classifier.dart';
import '../../browse/data/remote_models.dart';
import 'p115_cipher.dart';
import 'p115_cookie_store.dart';

class P115Exception implements Exception {
  const P115Exception(this.message);
  final String message;
  @override
  String toString() => message;
}

class P115AuthExpiredException extends P115Exception {
  const P115AuthExpiredException() : super('115 登录已失效');
}

/// 115 returned an HTML page (verification / rate-limit / WAF) instead of JSON.
/// Distinct from auth expiry: the cookie is still valid, so callers must NOT
/// clear it — surface a retry hint instead.
class P115BlockedException extends P115Exception {
  const P115BlockedException()
    : super('115 暂时限制了访问，可能是短时间请求过多或需在网页端验证，请稍后重试或切换网络。');
}

class P115Client {
  P115Client({required this.cookieStore, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 25),
            ),
          );

  final P115CookieStore cookieStore;
  final Dio _dio;

  DateTime? _lastListAt;
  static const _listMinInterval = Duration(milliseconds: 350);

  static const sourceId = 'p115';
  static const sourceName = '115 网盘';
  static const _downloadUserAgent = 'Mozilla/5.0 115Browser/30.4.0';

  Future<List<RemoteEntry>> list(String cid) async {
    final out = <RemoteEntry>[];
    var offset = 0;
    const limit = 500;
    while (true) {
      final json = await _getJson(
        'https://webapi.115.com/files',
        query: {
          'aid': 1,
          'cid': cid,
          'offset': offset,
          'limit': limit,
          'show_dir': 1,
          'fc_mix': 0,
          'natsort': 1,
          'format': 'json',
        },
      );
      final page = mapEntries(json);
      out.addAll(page);
      final count = int.tryParse('${json['count'] ?? json['total'] ?? 0}') ?? 0;
      offset += page.length;
      if (page.length < limit || (count > 0 && offset >= count)) break;
    }
    return out;
  }

  Future<ResolvedMediaUrl> resolveDownloadUrl(String pickcode) async {
    final cookie = await _cookie();
    final encrypted = P115Cipher.encryptJson({'pickcode': pickcode});
    final res = await _dio.post<dynamic>(
      'https://proapi.115.com/app/chrome/downurl',
      data: {'data': encrypted},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': cookie.header, 'User-Agent': _downloadUserAgent},
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const P115AuthExpiredException();
    }
    final setCookies = <String>[];
    final body = await _followDownurl(res, cookie, setCookies);
    final json = _asJson(body);
    if (!_truthy(json['state'])) {
      if (_authExpired(json)) throw const P115AuthExpiredException();
      throw P115Exception('${json['error'] ?? json['message'] ?? '获取直链失败'}');
    }
    final data = jsonDecode(P115Cipher.decryptToString('${json['data']}'));
    final url = _extractDownloadUrl(data);
    // The CDN 403s "no cookie value" unless we send the session cookie PLUS the
    // signed anti-leech cookies 115 sets during the download redirect (acw_tc +
    // a dynamic one), with a 115 referer. fvp/FFmpeg also won't forward a Cookie
    // header at all, so stream through the local proxy which injects them all.
    final proxied = await MediaProxy.instance.wrap(Uri.parse(url), {
      'User-Agent': _downloadUserAgent,
      'Cookie': _mergeCookieHeader(cookie.header, setCookies),
      'Referer': 'https://115.com/',
    });
    return ResolvedMediaUrl(url: proxied.url, release: proxied.release);
  }

  Future<List<int>> getBytesByPickcode(String pickcode) async {
    final resolved = await resolveDownloadUrl(pickcode);
    try {
      final res = await _dio.get<List<int>>(
        resolved.url.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          headers: resolved.headers,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw const P115AuthExpiredException();
      }
      if (res.statusCode != 200) {
        throw P115Exception('115 文件下载失败：${res.statusCode}');
      }
      return res.data!;
    } finally {
      await resolved.release?.call();
    }
  }

  /// 115 proapi 302-redirects the downurl POST to a `dl302` gateway that serves
  /// the encrypted JSON. dart:io doesn't auto-follow a POST redirect, so chase
  /// the `Location` chain manually (GET) and return the JSON-bearing body.
  Future<dynamic> _followDownurl(
    Response<dynamic> res,
    P115Cookie cookie,
    List<String> setCookies,
  ) async {
    var current = res;
    setCookies.addAll(current.headers['set-cookie'] ?? const []);
    for (var hop = 0; hop < 5; hop++) {
      final location = current.headers.value('location');
      if (location == null || location.isEmpty) return current.data;
      current = await _dio.get<dynamic>(
        location,
        options: Options(
          headers: {
            'Cookie': _mergeCookieHeader(cookie.header, setCookies),
            'User-Agent': _downloadUserAgent,
          },
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      setCookies.addAll(current.headers['set-cookie'] ?? const []);
      if (current.statusCode == 401 || current.statusCode == 403) {
        throw const P115AuthExpiredException();
      }
    }
    return current.data;
  }

  static List<RemoteEntry> mapEntries(Map<String, dynamic> json) {
    final rows = (json['data'] as List? ?? const []).cast<dynamic>();
    final entries = rows.map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final fid = '${item['fid'] ?? ''}';
      final isFile = fid.isNotEmpty && fid != '0' && fid != 'null';
      final name = '${item['n'] ?? item['name'] ?? item['file_name']}';
      if (!isFile) {
        final cid = '${item['cid'] ?? item['file_id']}';
        return RemoteEntry(
          id: cid,
          path: cid,
          name: name,
          kind: RemoteEntryKind.folder,
          sourceId: sourceId,
        );
      }
      return RemoteEntry(
        id: fid,
        path: fid,
        name: name,
        kind: remoteEntryKindFromFileKind(FileClassifier.classify(name)),
        size: int.tryParse('${item['s'] ?? item['file_size'] ?? ''}'),
        pickcode: '${item['pc'] ?? item['pick_code']}',
        sourceId: sourceId,
      );
    }).toList();
    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<Map<String, dynamic>> _getJson(
    String url, {
    required Map<String, dynamic> query,
  }) async {
    await _throttleList();
    final cookie = await _cookie();
    final res = await _dio.get<dynamic>(
      url,
      queryParameters: query,
      options: Options(
        headers: {'Cookie': cookie.header},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const P115AuthExpiredException();
    }
    final json = _asJson(res.data);
    if (!_truthy(json['state'])) {
      if (_authExpired(json)) throw const P115AuthExpiredException();
      throw P115Exception('${json['error'] ?? json['message'] ?? '115 请求失败'}');
    }
    return json;
  }

  Future<P115Cookie> _cookie() async {
    final cookie = await cookieStore.read();
    if (cookie == null) throw const P115AuthExpiredException();
    return cookie;
  }

  // 115 throttles bursts of /files calls by serving an HTML verification page.
  // The recursive folder scan fans out one request per directory plus paging,
  // so space list requests apart to stay under that threshold.
  Future<void> _throttleList() async {
    final last = _lastListAt;
    if (last != null) {
      final wait = _listMinInterval - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastListAt = DateTime.now();
  }

  Map<String, dynamic> _asJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    try {
      return Map<String, dynamic>.from(jsonDecode('$data') as Map);
    } on FormatException {
      throw const P115BlockedException();
    }
  }

  static bool _truthy(Object? value) => value == true || value == 1;

  static bool _authExpired(Map<String, dynamic> json) {
    final code = '${json['errno'] ?? json['errNo'] ?? json['code'] ?? ''}';
    return code == '401' || code == '403' || code == '911';
  }

  static String _mergeCookieHeader(
    String baseHeader,
    Iterable<String> setCookies,
  ) {
    final values = <String, String>{};

    void putPair(String pair) {
      final trimmed = pair.trim();
      final i = trimmed.indexOf('=');
      if (i < 0) return;
      values[trimmed.substring(0, i)] = trimmed.substring(i + 1);
    }

    for (final pair in baseHeader.split(';')) {
      putPair(pair);
    }
    for (final header in setCookies) {
      putPair(header.split(';').first);
    }
    return values.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static String _extractDownloadUrl(Object? data) {
    final map = Map<String, dynamic>.from(data as Map);
    final single = map['url'];
    if (single is String) return single;
    for (final value in map.values) {
      final info = Map<String, dynamic>.from(value as Map);
      final url = info['url'];
      if (url is String) return url;
      if (url is Map) return '${url['url']}';
    }
    throw const P115Exception('115 未返回可播放直链');
  }
}

final p115ClientProvider = Provider<P115Client>((ref) {
  return P115Client(cookieStore: ref.watch(p115CookieStoreProvider));
});
