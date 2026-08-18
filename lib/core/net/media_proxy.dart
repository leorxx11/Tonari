import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../diagnostics/diagnostic_log.dart';

/// App-local HTTP proxy on `127.0.0.1` that injects auth headers media players
/// can't send themselves. P115's CDN 403s without the session cookie, so players
/// hit this proxy instead.
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

  /// Registers [url] + [headers] for video playback.
  Future<MediaProxyRegistration> wrapVideo(
    Uri url,
    Map<String, String> headers,
  ) async {
    return _wrap(url, headers, _ProxyMode.boundedBlocks);
  }

  /// Registers [url] + [headers] for audio playback.
  ///
  /// Audio plays through AVPlayer (just_audio), which — unlike FFmpeg — does not
  /// re-request after a short 206. It asks for the whole range and treats a
  /// truncated reply as a broken stream, so audio gets [_ProxyMode.streamRange]:
  /// the full requested range is delivered in one response, fetched internally
  /// as gated 4 MiB blocks so no long-lived upstream connection burns 115's
  /// per-URL connection quota.
  Future<MediaProxyRegistration> wrapAudio(
    Uri url,
    Map<String, String> headers,
  ) async {
    return _wrap(url, headers, _ProxyMode.streamRange);
  }

  Future<MediaProxyRegistration> wrap(Uri url, Map<String, String> headers) {
    return wrapVideo(url, headers);
  }

  Future<MediaProxyRegistration> _wrap(
    Uri url,
    Map<String, String> headers,
    _ProxyMode mode,
  ) async {
    await _ensureStarted();
    final id = '${_seq++}';
    _entries[id] = _Upstream(url, headers, mode);
    final name = url.pathSegments.isNotEmpty ? url.pathSegments.last : 'media';
    final headerNames = headers.keys.toList()..sort();
    DiagnosticLog.write('media_proxy', 'register', {
      'proxyId': id,
      'mode': mode.name,
      'upstreamScheme': url.scheme,
      'upstreamHost': url.host,
      'pathExtension': _extension(['', name]),
      'headerNames': headerNames,
      'serverPort': _server!.port,
      'activeEntries': _entries.length,
    });
    if (DiagnosticLog.enabled) {
      await _probeLoopback(id);
    }
    return MediaProxyRegistration._(
      Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: _server!.port,
        pathSegments: [id, name],
      ),
      () {
        final removed = _entries.remove(id);
        removed?.close();
        DiagnosticLog.write('media_proxy', 'release', {
          'proxyId': id,
          'mode': mode.name,
          'serverPort': _server?.port,
          'activeEntries': _entries.length,
        });
      },
    );
  }

  Future<void> reset(String reason) => _closeServer(reason);

  /// Rebinds the listener on the *same port* after an iOS suspend killed it,
  /// keeping every registration. Players hold URLs pointing at this port, so
  /// reviving in place lets a paused player pick up exactly where it was —
  /// no re-resolve, no re-initialize. Returns false when the port can't be
  /// reclaimed (caller must reopen the media instead). No-op when healthy.
  Future<bool> revive() async {
    final server = _server;
    if (server == null) return true;
    if (await _canAcceptConnections(server)) return true;
    final port = server.port;
    DiagnosticLog.write('media_proxy', 'revive_start', {
      'port': port,
      'activeEntries': _entries.length,
    });
    try {
      await server.close(force: true).timeout(const Duration(seconds: 2));
    } catch (_) {
      // The listener is already dead — close failing is expected.
    }
    // A concurrent reset/restart swapped the server while we were closing.
    if (!identical(_server, server)) return true;
    try {
      final fresh = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      fresh.listen(
        _handle,
        onError: (Object e) => DiagnosticLog.write(
          'media_proxy',
          'server_error',
          {'port': port, 'message': '$e'},
        ),
        onDone: () =>
            DiagnosticLog.write('media_proxy', 'server_done', {'port': port}),
      );
      _server = fresh;
      DiagnosticLog.write('media_proxy', 'revive_done', {'port': port});
      return true;
    } catch (e) {
      DiagnosticLog.write('media_proxy', 'revive_failed', {
        'port': port,
        'errorType': '${e.runtimeType}',
        'message': '$e',
      });
      _server = null;
      _entries.clear();
      return false;
    }
  }

  Future<void> _probeLoopback(String id) async {
    final server = _server!;
    final uri = Uri.parse('http://127.0.0.1:${server.port}/__probe/$id');
    final stopwatch = Stopwatch()..start();
    DiagnosticLog.write('media_proxy', 'probe_start', {
      'proxyId': id,
      'serverPort': server.port,
      'activeEntries': _entries.length,
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 2));
      final res = await req.close().timeout(const Duration(seconds: 2));
      await res.drain<void>().timeout(const Duration(seconds: 2));
      DiagnosticLog.write('media_proxy', 'probe_done', {
        'proxyId': id,
        'serverPort': server.port,
        'status': res.statusCode,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
    } catch (e) {
      DiagnosticLog.write('media_proxy', 'probe_error', {
        'proxyId': id,
        'serverPort': server.port,
        'errorType': '${e.runtimeType}',
        'message': '$e',
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _ensureStarted() async {
    final existing = _server;
    if (existing != null) {
      final healthy = await _canAcceptConnections(existing);
      if (healthy) return;
      await _closeServer('health_check_failed');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // Capture the port now: once the server closes, `server.port` throws
    // `HttpServer is not bound to a socket`, and the onDone callback below fires
    // exactly at close — reading it there would raise an uncaught async error.
    final port = server.port;
    // Surface unexpected listener failures; normal recovery happens before
    // each registration through the loopback health check above.
    server.listen(
      _handle,
      onError: (Object e) => DiagnosticLog.write(
        'media_proxy',
        'server_error',
        {'port': port, 'message': '$e'},
      ),
      onDone: () =>
          DiagnosticLog.write('media_proxy', 'server_done', {'port': port}),
    );
    _server = server;
    DiagnosticLog.write('media_proxy', 'server_start', {'port': port});
  }

  Future<bool> _canAcceptConnections(HttpServer server) async {
    final uri = Uri.parse('http://127.0.0.1:${server.port}/__health');
    final stopwatch = Stopwatch()..start();
    DiagnosticLog.write('media_proxy', 'health_start', {
      'serverPort': server.port,
      'targetPort': uri.port,
      'activeEntries': _entries.length,
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 2));
      final res = await req.close().timeout(const Duration(seconds: 2));
      await res.drain<void>().timeout(const Duration(seconds: 2));
      final ok = res.statusCode == HttpStatus.noContent;
      DiagnosticLog.write('media_proxy', 'health_done', {
        'serverPort': server.port,
        'targetPort': uri.port,
        'status': res.statusCode,
        'healthy': ok,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
      return ok;
    } catch (e) {
      DiagnosticLog.write('media_proxy', 'health_error', {
        'serverPort': server.port,
        'targetPort': uri.port,
        'errorType': '${e.runtimeType}',
        'message': '$e',
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _closeServer(String reason) async {
    final server = _server;
    _server = null;
    _entries.clear();
    if (server == null) return;
    // Capture the port before close(): reading `server.port` afterwards throws
    // `HttpServer is not bound to a socket`, which would propagate out of
    // video stop() and abort a concurrent audio switch.
    final port = server.port;
    DiagnosticLog.write('media_proxy', 'server_close_start', {
      'reason': reason,
      'serverPort': port,
    });
    try {
      await server.close(force: true).timeout(const Duration(seconds: 2));
      DiagnosticLog.write('media_proxy', 'server_close_done', {
        'reason': reason,
        'serverPort': port,
      });
    } catch (e) {
      DiagnosticLog.write('media_proxy', 'server_close_error', {
        'reason': reason,
        'serverPort': port,
        'errorType': '${e.runtimeType}',
        'message': '$e',
      });
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final reqId = ++_requestSeq;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final rangeFields = _rangeFields(range);
    final stopwatch = Stopwatch()..start();
    final id = req.uri.pathSegments.isEmpty ? '' : req.uri.pathSegments.first;
    if (id == '__health') {
      DiagnosticLog.write('media_proxy', 'health_request', {
        'requestId': reqId,
        'method': req.method,
        'serverPort': _server?.port,
        'activeEntries': _entries.length,
      });
      res.statusCode = HttpStatus.noContent;
      await res.close();
      return;
    }
    if (id == '__probe') {
      final target = req.uri.pathSegments.length > 1
          ? req.uri.pathSegments[1]
          : '';
      DiagnosticLog.write('media_proxy', 'probe_request', {
        'requestId': reqId,
        'proxyId': target,
        'method': req.method,
        'serverPort': _server?.port,
        'activeEntries': _entries.length,
      });
      res.statusCode = HttpStatus.noContent;
      await res.close();
      return;
    }
    final up = _entries[id];
    DiagnosticLog.write('media_proxy', 'request_received', {
      'requestId': reqId,
      'proxyId': id,
      'method': req.method,
      'range': range,
      ...rangeFields,
      'knownProxy': up != null,
      'mode': up?.mode.name,
      'serverPort': _server?.port,
      'activeEntries': _entries.length,
      'pathExtension': _extension(req.uri.pathSegments),
    });
    if (up == null) {
      DiagnosticLog.write('media_proxy', 'unknown_proxy', {
        'requestId': reqId,
        'proxyId': id,
        'range': range,
        'activeEntries': _entries.length,
      });
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final start = (rangeFields['rangeStart'] as int?) ?? 0;
    final requestedEnd = rangeFields['rangeEnd'] as int?;
    if (up.mode == _ProxyMode.streamRange) {
      await _handleStreamRange(
        req,
        res,
        up,
        id,
        reqId,
        start,
        requestedEnd,
        range,
        stopwatch,
      );
      return;
    }
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
        Uint8List.view(
          block.body.buffer,
          block.body.offsetInBytes + offset,
          len,
        ),
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

  /// Streams the full requested range back in one response (for AVPlayer), but
  /// pulls it from upstream as gated 4 MiB blocks so each upstream connection
  /// stays short and never trips 115's concurrent-connection cap.
  Future<void> _handleStreamRange(
    HttpRequest req,
    HttpResponse res,
    _Upstream up,
    String id,
    int reqId,
    int start,
    int? requestedEnd,
    String? range,
    Stopwatch stopwatch,
  ) async {
    DiagnosticLog.write('media_proxy', 'request_start', {
      'requestId': reqId,
      'proxyId': id,
      'method': req.method,
      'range': range,
      'rangeStart': start,
      'rangeEnd': requestedEnd,
      'mode': up.mode.name,
      'pathExtension': _extension(req.uri.pathSegments),
    });
    final streamId = _isLongStreamRange(start, requestedEnd)
        ? up.claimStreamRange()
        : null;
    var cancelled = false;

    bool isCancelled() {
      if (streamId == null) return false;
      final stale = !up.isCurrentStreamRange(streamId);
      if (stale) cancelled = true;
      return stale;
    }

    try {
      final first = await up.block(
        req.method,
        start ~/ chunkBytes,
        requestId: reqId,
        proxyId: id,
      );
      if (isCancelled()) {
        await res.close();
        DiagnosticLog.write('media_proxy', 'transfer_done', {
          'requestId': reqId,
          'proxyId': id,
          'bytes': 0,
          'cancelled': true,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
        return;
      }
      if (first.status >= 400) {
        res.statusCode = first.status;
        _copyContentHeaders(res, first);
        res.add(first.body);
        await res.flush();
        await res.close();
        DiagnosticLog.write('media_proxy', 'upstream_rejected', {
          'requestId': reqId,
          'proxyId': id,
          'status': first.status,
          'bytes': first.body.length,
          'bodySample': utf8.decode(
            first.body.take(512).toList(),
            allowMalformed: true,
          ),
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
        return;
      }

      final total = _contentRangeTotal(first.contentRange) ?? up.total;
      final end =
          requestedEnd ??
          (total != null ? total - 1 : start + first.body.length - 1);

      res.statusCode = HttpStatus.partialContent;
      _copyContentHeaders(res, first);
      if (total != null) {
        res.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$total',
        );
      }
      res.headers.set(HttpHeaders.contentLengthHeader, '${end - start + 1}');

      var pos = start;
      var block = first;
      var sent = 0;
      while (pos <= end) {
        if (isCancelled()) break;
        if (pos ~/ chunkBytes != block.start ~/ chunkBytes) {
          block = await up.block(
            req.method,
            pos ~/ chunkBytes,
            requestId: reqId,
            proxyId: id,
          );
          if (isCancelled()) break;
          if (block.status >= 400) break;
        }
        final blockEnd = block.start + block.body.length - 1;
        if (pos < block.start || pos > blockEnd) break;
        final sliceEnd = end < blockEnd ? end : blockEnd;
        final offset = pos - block.start;
        final len = sliceEnd - pos + 1;
        res.add(
          Uint8List.view(
            block.body.buffer,
            block.body.offsetInBytes + offset,
            len,
          ),
        );
        await res.flush();
        sent += len;
        pos = sliceEnd + 1;
      }
      await res.close();
      DiagnosticLog.write('media_proxy', 'transfer_done', {
        'requestId': reqId,
        'proxyId': id,
        'bytes': sent,
        'cancelled': cancelled,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
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
  res.headers.set(
    HttpHeaders.acceptRangesHeader,
    block.acceptRanges ?? 'bytes',
  );
}

enum _ProxyMode { boundedBlocks, streamRange }

bool _isLongStreamRange(int start, int? requestedEnd) {
  return requestedEnd == null ||
      requestedEnd - start + 1 > MediaProxy.chunkBytes;
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
  _Upstream(this.url, this.headers, this.mode);
  final Uri url;
  final Map<String, String> headers;
  final _ProxyMode mode;

  final _gate = _Semaphore(MediaProxy.maxConcurrentUpstream);
  static const _maxBlocks = 8;
  final _cache = <int, _Block>{};
  final _lru = <int>[];
  final _inflight = <int, Future<_Block>>{};
  static const _streamRangeBlockAttempts = 2;
  // One pooled client per upstream: block fetches reuse its keep-alive
  // connections instead of paying a fresh TCP + TLS handshake every 4 MiB,
  // which kept the CPU (and the phone) hot during long background playback.
  HttpClient? _client;
  var _streamRangeSeq = 0;
  var _closed = false;

  /// File size, learned from the first `Content-Range` we see.
  int? total;

  bool isCached(int index) => _cache.containsKey(index);

  void close() {
    _closed = true;
    _client?.close(force: true);
    _client = null;
  }

  int claimStreamRange() => ++_streamRangeSeq;

  bool isCurrentStreamRange(int id) => !_closed && id == _streamRangeSeq;

  /// Returns block [index] from cache, an in-flight fetch, or a fresh one.
  Future<_Block> block(
    String method,
    int index, {
    int? requestId,
    String? proxyId,
  }) {
    if (_closed) return Future<_Block>.error(StateError('proxy released'));
    final hit = _cache[index];
    if (hit != null) {
      _lru
        ..remove(index)
        ..add(index);
      return Future<_Block>.value(hit);
    }
    final pending = _inflight[index];
    if (pending != null) return pending;
    final fut = mode == _ProxyMode.streamRange
        ? _fetchStreamRangeBlock(
            method,
            index,
            requestId: requestId,
            proxyId: proxyId,
          )
        : _fetch(method, index);
    _inflight[index] = fut;
    fut.whenComplete(() {
      if (identical(_inflight[index], fut)) _inflight.remove(index);
    });
    return fut;
  }

  Future<_Block> _fetchStreamRangeBlock(
    String method,
    int index, {
    required int? requestId,
    required String? proxyId,
  }) async {
    var attempt = 1;
    while (true) {
      try {
        return await _fetch(method, index);
      } catch (e) {
        final replayable = _isReplayableUpstreamError(e);
        if (replayable) _closeClient();
        if (!replayable || attempt >= _streamRangeBlockAttempts) {
          DiagnosticLog.write('media_proxy', 'block_fetch_error', {
            'requestId': requestId,
            'proxyId': proxyId,
            'blockIndex': index,
            'attempt': attempt,
            'maxAttempts': _streamRangeBlockAttempts,
            'range': _blockRangeHeader(index),
            'errorType': '${e.runtimeType}',
            'message': '$e',
          });
          rethrow;
        }
        DiagnosticLog.write('media_proxy', 'block_retry', {
          'requestId': requestId,
          'proxyId': proxyId,
          'blockIndex': index,
          'attempt': attempt,
          'nextAttempt': attempt + 1,
          'maxAttempts': _streamRangeBlockAttempts,
          'range': _blockRangeHeader(index),
          'errorType': '${e.runtimeType}',
          'message': '$e',
        });
        attempt++;
      }
    }
  }

  Future<_Block> _fetch(String method, int index) async {
    await _gate.acquire();
    if (_closed) {
      _gate.release();
      throw StateError('proxy released');
    }
    final client = _client ??= HttpClient();
    try {
      final start = _blockStart(index);
      final end = _blockEnd(index);
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
      if (res.statusCode == HttpStatus.partialContent &&
          block.body.isNotEmpty) {
        _store(index, block);
      }
      return block;
    } finally {
      _gate.release();
    }
  }

  int _blockStart(int index) => index * MediaProxy.chunkBytes;

  int _blockEnd(int index) {
    final start = _blockStart(index);
    var end = start + MediaProxy.chunkBytes - 1;
    final known = total;
    if (known != null && end > known - 1) end = known - 1;
    return end;
  }

  String _blockRangeHeader(int index) {
    return 'bytes=${_blockStart(index)}-${_blockEnd(index)}';
  }

  void _closeClient() {
    _client?.close(force: true);
    _client = null;
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

bool _isReplayableUpstreamError(Object e) {
  return e is SocketException ||
      e is HttpException ||
      e is TimeoutException ||
      e is HandshakeException ||
      e is TlsException;
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
