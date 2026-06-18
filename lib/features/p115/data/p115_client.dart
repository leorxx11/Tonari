import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostic_log.dart';
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
  P115Client({
    required this.cookieStore,
    Dio? dio,
    this.apiMinInterval = const Duration(milliseconds: 1200),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 25),
             ),
           );

  final P115CookieStore cookieStore;
  final Dio _dio;
  final Duration apiMinInterval;

  Future<void> _apiGate = Future<void>.value();
  DateTime? _lastApiAt;
  var _resolveSeq = 0;

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

  Future<ResolvedMediaUrl> resolveVideoUrl(String pickcode) async {
    final direct = await _resolveDirect(pickcode);
    // fvp/FFmpeg won't forward a Cookie header at all, so stream playback
    // through the local proxy which injects the auth headers per request.
    final proxied = await MediaProxy.instance.wrap(direct.url, direct.headers);
    return ResolvedMediaUrl(url: proxied.url, release: proxied.release);
  }

  Future<ResolvedMediaUrl> resolveAudioUrl(String pickcode) async {
    final direct = await _resolveDirect(pickcode);
    final proxied = await MediaProxy.instance.wrapAudio(
      direct.url,
      direct.headers,
    );
    return ResolvedMediaUrl(url: proxied.url, release: proxied.release);
  }

  /// Resolves the signed CDN direct link plus the headers it needs. The CDN
  /// 403s "no cookie value" unless we send the session cookie PLUS the signed
  /// anti-leech cookies 115 sets during the download redirect (acw_tc + a
  /// dynamic one), with a 115 referer.
  Future<({Uri url, Map<String, String> headers})> _resolveDirect(
    String pickcode,
  ) async {
    final resolveId = ++_resolveSeq;
    DiagnosticLog.write('p115', 'resolve_start', {
      'resolveId': resolveId,
      'pickcodeTail': _tail(pickcode),
    });
    try {
      final resolved = await _throttledApi(() async {
        final cookie = await _cookie();
        final encrypted = P115Cipher.encryptJson({'pickcode': pickcode});
        final res = await _dio.post<dynamic>(
          'https://proapi.115.com/app/chrome/downurl',
          data: {'data': encrypted},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {
              'Cookie': cookie.header,
              'User-Agent': _downloadUserAgent,
            },
            followRedirects: false,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        DiagnosticLog.write('p115', 'downurl_response', {
          'resolveId': resolveId,
          'status': res.statusCode,
          'setCookieNames': _cookieNamesFromSetCookies(
            res.headers['set-cookie'] ?? const [],
          ),
          'hasLocation': res.headers.value('location') != null,
        });
        if (res.statusCode == 401 || res.statusCode == 403) {
          throw const P115AuthExpiredException();
        }
        final followed = await _followDownurl(res, cookie);
        return (cookie: cookie, followed: followed);
      });
      final followed = resolved.followed;
      final cookie = resolved.cookie;
      final json = _asJson(followed.body);
      if (!_truthy(json['state'])) {
        if (_authExpired(json)) throw const P115AuthExpiredException();
        throw P115Exception('${json['error'] ?? json['message'] ?? '获取直链失败'}');
      }
      final data = jsonDecode(P115Cipher.decryptToString('${json['data']}'));
      final url = _extractDownloadUrl(data);
      final uri = Uri.parse(url);
      final proxyCookie = _mergeCookieHeader(cookie.header, followed.cookies);
      DiagnosticLog.write('p115', 'resolve_done', {
        'resolveId': resolveId,
        'hopCount': followed.hopCount,
        'lastStatus': followed.lastStatus,
        'downloadScheme': uri.scheme,
        'downloadHost': uri.host,
        'downloadQueryKeys': uri.queryParameters.keys.toList()..sort(),
        'setCookieNames': _cookieNamesFromSetCookies(followed.cookies),
        'proxyCookieNames': _cookieNamesFromHeader(proxyCookie),
      });
      return (
        url: uri,
        headers: {
          'User-Agent': _downloadUserAgent,
          'Cookie': proxyCookie,
          'Referer': 'https://115.com/',
        },
      );
    } catch (e) {
      DiagnosticLog.write('p115', 'resolve_error', {
        'resolveId': resolveId,
        'errorType': '${e.runtimeType}',
        'message': '$e',
      });
      if (e is DioException) throw _networkError(e);
      rethrow;
    }
  }

  /// One-shot whole-file download (subtitles). Goes straight to the CDN with the
  /// auth headers — dio *can* send a Cookie, so no proxy. Routing this through
  /// [MediaProxy] would bound the response to one 4 MiB block and answer 206,
  /// which this 200-expecting path treats as a failure.
  Future<List<int>> getBytesByPickcode(String pickcode) async {
    final direct = await _resolveDirect(pickcode);
    final res = await _dio.get<List<int>>(
      direct.url.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: direct.headers,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const P115AuthExpiredException();
    }
    if (res.statusCode != 200 && res.statusCode != 206) {
      throw P115Exception('115 文件下载失败：${res.statusCode}');
    }
    return res.data!;
  }

  /// 115 proapi 302-redirects the downurl POST to a `dl302` gateway that serves
  /// the encrypted JSON. dart:io doesn't auto-follow a POST redirect, so chase
  /// the `Location` chain manually (GET) and return the JSON-bearing body.
  Future<_DownurlResult> _followDownurl(
    Response<dynamic> res,
    P115Cookie cookie,
  ) async {
    var current = res;
    var hopCount = 0;
    final setCookies = <String>[];
    setCookies.addAll(current.headers['set-cookie'] ?? const []);
    for (var hop = 0; hop < 5; hop++) {
      final location = current.headers.value('location');
      if (location == null || location.isEmpty) {
        return _DownurlResult(
          body: current.data,
          cookies: setCookies,
          hopCount: hopCount,
          lastStatus: current.statusCode,
        );
      }
      hopCount++;
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
    return _DownurlResult(
      body: current.data,
      cookies: setCookies,
      hopCount: hopCount,
      lastStatus: current.statusCode,
    );
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
    return _throttledApi(() async {
      final cookie = await _cookie();
      final Response<dynamic> res;
      try {
        res = await _dio.get<dynamic>(
          url,
          queryParameters: query,
          options: Options(
            headers: {'Cookie': cookie.header},
            validateStatus: (s) => s != null && s < 500,
          ),
        );
      } on DioException catch (e) {
        throw _networkError(e);
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw const P115AuthExpiredException();
      }
      final json = _asJson(res.data);
      if (!_truthy(json['state'])) {
        if (_authExpired(json)) throw const P115AuthExpiredException();
        throw P115Exception(
          '${json['error'] ?? json['message'] ?? '115 请求失败'}',
        );
      }
      return json;
    });
  }

  Future<P115Cookie> _cookie() async {
    final cookie = await cookieStore.read();
    if (cookie == null) throw const P115AuthExpiredException();
    return cookie;
  }

  // Connection-level dio failures carry no useful message for users; map them
  // to the same friendly wording WebDAV uses so offline browse/playback reads
  // as a network problem, not a stack-trace string.
  static P115Exception _networkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const P115Exception('连接 115 超时，请检查网络后重试');
      case DioExceptionType.connectionError:
        return const P115Exception('无法连接到 115，请检查网络');
      case DioExceptionType.badCertificate:
        return const P115Exception('115 证书校验失败');
      default:
        return P115Exception('115 请求失败：${e.message ?? e.type.name}');
    }
  }

  // 115 throttles bursts across cookie-backed API endpoints, not just /files.
  // Keep directory listing, import subtitle downurl resolution, browse resolve,
  // and playback resolve on one serial rhythm so separate UI flows cannot burst.
  Future<T> _throttledApi<T>(Future<T> Function() request) {
    final run = _apiGate.then((_) async {
      final last = _lastApiAt;
      if (last != null) {
        final wait = apiMinInterval - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastApiAt = DateTime.now();
      return request();
    });
    _apiGate = run.then<void>((_) {}, onError: (_) {});
    return run;
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

  static List<String> _cookieNamesFromSetCookies(Iterable<String> headers) {
    final names = <String>{};
    for (final header in headers) {
      final first = header.split(';').first.trim();
      final i = first.indexOf('=');
      if (i > 0) names.add(first.substring(0, i));
    }
    return names.toList()..sort();
  }

  static List<String> _cookieNamesFromHeader(String header) {
    final names = <String>{};
    for (final pair in header.split(';')) {
      final trimmed = pair.trim();
      final i = trimmed.indexOf('=');
      if (i > 0) names.add(trimmed.substring(0, i));
    }
    return names.toList()..sort();
  }

  static String _tail(String value) {
    if (value.length <= 6) return value;
    return value.substring(value.length - 6);
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

class _DownurlResult {
  const _DownurlResult({
    required this.body,
    required this.cookies,
    required this.hopCount,
    required this.lastStatus,
  });

  final dynamic body;
  final List<String> cookies;
  final int hopCount;
  final int? lastStatus;
}

final p115ClientProvider = Provider<P115Client>((ref) {
  return P115Client(cookieStore: ref.watch(p115CookieStoreProvider));
});
