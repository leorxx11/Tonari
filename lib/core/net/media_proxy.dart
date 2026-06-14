import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../diagnostics/diagnostic_log.dart';

/// App-local HTTP proxy on `127.0.0.1` that injects auth headers the media
/// player can't send itself. fvp/FFmpeg drops the `Cookie` header set via
/// `avio.headers`, so 115's CDN (which 403s without the session cookie) is
/// unplayable directly — the player hits this proxy instead.
///
/// Three upstream realities shape the design:
///  * FFmpeg keeps several large reads alive at once for MP4/TS (audio and
///    video interleaved far apart), so we must never cancel one read to favour
///    another — that just thrashes.
///  * 115 caps concurrent connections per signed URL (~2); a third returns
///    `403 115 pmt …`.
///  * FFmpeg issues a flurry of tiny `bytes=X-` reads that drift within a small
///    window, so fetching anything large per request amplifies traffic wildly.
///
/// So we treat the file as a grid of [chunkBytes] blocks, fetch each block once
/// (gated, in-flight-deduped, LRU-cached), and answer every player `bytes=X-`
/// with a *bounded* 206 covering only the rest of X's block, then close. The
/// player re-requests for more (it always does), repeated reads inside a block
/// are cache hits with zero upstream traffic, and no connection lingers to EOF.
class MediaProxy {
  MediaProxy._();
  static final MediaProxy instance = MediaProxy._();

  /// Grid block size for upstream fetches and the bounded slice served back.
  static const chunkBytes = 4 * 1024 * 1024;

  /// Max simultaneous upstream connections per signed URL. 115 returns
  /// `403 115 pmt …` beyond this.
  static const maxConcurrentUpstream = 2;

  HttpServer? _server;
  final _entries = <String, _Upstream>{};
  var _seq = 0;
  var _requestSeq = 0;

  /// Registers [url] + [headers] and returns a loopback URL the player can open
  /// without any headers of its own.
  Future<MediaProxyRegistration> wrap(
    Uri url,
    Map<String, String> headers,
  ) async {
    await _ensureStarted();
    final id = '${_seq++}';
    _entries[id] = _Upstream(url, headers);
    final name = url.pathSegments.isNotEmpty ? url.pathSegments.last : 'media';
    final headerNames = headers.keys.toList()..sort();
    DiagnosticLog.write('media_proxy', 'register', {
      'proxyId': id,
      'upstreamScheme': url.scheme,
      'upstreamHost': url.host,
      'pathExtension': _extension(['', name]),
      'headerNames': headerNames,
    });
    return MediaProxyRegistration._(
      Uri.parse('http://127.0.0.1:${_server!.port}/$id/$name'),
      () => _entries.remove(id),
    );
  }

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
    _server = server;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final reqId = ++_requestSeq;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final rangeFields = _rangeFields(range);
    final stopwatch = Stopwatch()..start();
    final id = req.uri.pathSegments.isEmpty ? '' : req.uri.pathSegments.first;
    final up = _entries[id];
    if (up == null) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }

    final start = (rangeFields['rangeStart'] as int?) ?? 0;
    final requestedEnd = rangeFields['rangeEnd'] as int?;
    final index = start ~/ chunkBytes;
    final cached = up.isCached(index);
    // Cache hits dominate and carry no signal; log only when we touch upstream.
    // Rejections and errors below are always logged.
    if (!cached) {
      DiagnosticLog.write('media_proxy', 'request_start', {
        'requestId': reqId,
        'proxyId': id,
        'method': req.method,
        'range': range,
        ...rangeFields,
        'pathExtension': _extension(req.uri.pathSegments),
      });
    }

    try {
      final block = await up.block(req.method, index);

      if (!cached) {
        DiagnosticLog.write('media_proxy', 'upstream_response', {
          'requestId': reqId,
          'proxyId': id,
          'status': block.status,
          'contentRange': block.contentRange,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
      }

      if (block.status >= 400) {
        res.statusCode = block.status;
        _copyContentHeaders(res, block);
        res.add(block.body);
        await res.flush();
        await res.close();
        DiagnosticLog.write('media_proxy', 'upstream_rejected', {
          'requestId': reqId,
          'proxyId': id,
          'status': block.status,
          'bytes': block.body.length,
          'bodySample': utf8.decode(
            block.body.take(512).toList(),
            allowMalformed: true,
          ),
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
        return;
      }

      final total = _contentRangeTotal(block.contentRange) ?? up.total;
      final blockEnd = block.start + block.body.length - 1;
      final endTarget = requestedEnd ?? (total != null ? total - 1 : blockEnd);
      final sliceEnd = endTarget < blockEnd ? endTarget : blockEnd;
      final offset = start - block.start;

      if (offset < 0 || offset >= block.body.length || start > sliceEnd) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await res.close();
        DiagnosticLog.write('media_proxy', 'transfer_done', {
          'requestId': reqId,
          'proxyId': id,
          'bytes': 0,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
        return;
      }

      res.statusCode = block.status;
      _copyContentHeaders(res, block);
      if (total != null) {
        res.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$sliceEnd/$total',
        );
      }
      final len = sliceEnd - start + 1;
      res.headers.set(HttpHeaders.contentLengthHeader, '$len');
      res.add(
        Uint8List.view(block.body.buffer, block.body.offsetInBytes + offset, len),
      );
      await res.flush();
      await res.close();
      if (!cached) {
        DiagnosticLog.write('media_proxy', 'transfer_done', {
          'requestId': reqId,
          'proxyId': id,
          'bytes': len,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
      }
    } catch (e) {
      DiagnosticLog.write('media_proxy', 'request_error', {
        'requestId': reqId,
        'proxyId': id,
        'errorType': '${e.runtimeType}',
        'message': '$e',
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
      // Player seeked (closed this connection) or upstream failed — best effort.
      try {
        await res.close();
      } catch (_) {}
    }
  }
}

void _copyContentHeaders(HttpResponse res, _Block block) {
  final type = block.contentType;
  if (type != null) res.headers.set(HttpHeaders.contentTypeHeader, type);
  res.headers.set(HttpHeaders.acceptRangesHeader, block.acceptRanges ?? 'bytes');
}

Map<String, Object?> _rangeFields(String? range) {
  if (range == null || !range.startsWith('bytes=')) {
    return const {'rangeStart': null, 'rangeEnd': null};
  }
  final spec = range.substring(6).split(',').first;
  final dash = spec.indexOf('-');
  if (dash < 0) return const {'rangeStart': null, 'rangeEnd': null};
  final start = spec.substring(0, dash);
  final end = spec.substring(dash + 1);
  return {
    'rangeStart': int.tryParse(start),
    'rangeEnd': end.isEmpty ? null : int.tryParse(end),
  };
}

int? _contentRangeTotal(String? contentRange) {
  if (contentRange == null) return null;
  final slash = contentRange.lastIndexOf('/');
  if (slash < 0) return null;
  return int.tryParse(contentRange.substring(slash + 1).trim());
}

String _extension(List<String> pathSegments) {
  if (pathSegments.length < 2) return '';
  final name = pathSegments.last;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

class MediaProxyRegistration {
  MediaProxyRegistration._(this.url, this.release);

  final Uri url;
  final void Function() release;
}

class _Upstream {
  _Upstream(this.url, this.headers);
  final Uri url;
  final Map<String, String> headers;

  final _gate = _Semaphore(MediaProxy.maxConcurrentUpstream);
  static const _maxBlocks = 8;
  final _cache = <int, _Block>{};
  final _lru = <int>[];
  final _inflight = <int, Future<_Block>>{};

  /// File size, learned from the first `Content-Range` we see.
  int? total;

  bool isCached(int index) => _cache.containsKey(index);

  /// Returns block [index] from cache, an in-flight fetch, or a fresh one.
  Future<_Block> block(String method, int index) {
    final hit = _cache[index];
    if (hit != null) {
      _lru
        ..remove(index)
        ..add(index);
      return Future<_Block>.value(hit);
    }
    final pending = _inflight[index];
    if (pending != null) return pending;
    final fut = _fetch(method, index);
    _inflight[index] = fut;
    fut.whenComplete(() {
      if (identical(_inflight[index], fut)) _inflight.remove(index);
    });
    return fut;
  }

  Future<_Block> _fetch(String method, int index) async {
    await _gate.acquire();
    final client = HttpClient();
    try {
      final start = index * MediaProxy.chunkBytes;
      var end = start + MediaProxy.chunkBytes - 1;
      final known = total;
      if (known != null && end > known - 1) end = known - 1;
      final fwd = await client.openUrl(method, url);
      fwd.followRedirects = true;
      headers.forEach(fwd.headers.set);
      fwd.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      final res = await fwd.close();
      final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
      final builder = BytesBuilder(copy: false);
      await for (final part in res) {
        builder.add(part);
      }
      final block = _Block(
        start: start,
        status: res.statusCode,
        body: builder.takeBytes(),
        contentRange: contentRange,
        contentType: res.headers.value(HttpHeaders.contentTypeHeader),
        acceptRanges: res.headers.value(HttpHeaders.acceptRangesHeader),
      );
      final t = _contentRangeTotal(contentRange);
      if (t != null) total = t;
      if (res.statusCode == HttpStatus.partialContent && block.body.isNotEmpty) {
        _store(index, block);
      }
      return block;
    } finally {
      client.close(force: true);
      _gate.release();
    }
  }

  void _store(int index, _Block block) {
    _cache[index] = block;
    _lru
      ..remove(index)
      ..add(index);
    while (_lru.length > _maxBlocks) {
      _cache.remove(_lru.removeAt(0));
    }
  }
}

class _Block {
  _Block({
    required this.start,
    required this.status,
    required this.body,
    required this.contentRange,
    required this.contentType,
    required this.acceptRanges,
  });

  final int start;
  final int status;
  final Uint8List body;
  final String? contentRange;
  final String? contentType;
  final String? acceptRanges;
}

/// Minimal FIFO async semaphore. Queues waiters instead of cancelling, so a
/// blocked fetch resumes once a slot frees rather than being dropped.
class _Semaphore {
  _Semaphore(this._max);
  final int _max;
  var _count = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() {
    if (_count < _max) {
      _count++;
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else if (_count > 0) {
      _count--;
    }
  }
}
