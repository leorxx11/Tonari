import 'dart:async';
import 'dart:io';

/// App-local HTTP proxy on `127.0.0.1` that injects auth headers the media
/// player can't send itself. fvp/FFmpeg drops the `Cookie` header set via
/// `avio.headers`, so 115's CDN (which 403s without the session cookie) is
/// unplayable directly — the player hits this proxy instead and we forward
/// upstream with the right headers, streaming bytes (and `Range`) straight
/// back so seeking still works.
class MediaProxy {
  MediaProxy._();
  static final MediaProxy instance = MediaProxy._();

  HttpServer? _server;
  final _client = HttpClient();
  final _entries = <String, _Upstream>{};
  var _seq = 0;

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
    final id = req.uri.pathSegments.isEmpty ? '' : req.uri.pathSegments.first;
    final up = _entries[id];
    if (up == null) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    try {
      final fwd = await _client.openUrl(req.method, up.url);
      fwd.followRedirects = true;
      up.headers.forEach(fwd.headers.set);
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) fwd.headers.set(HttpHeaders.rangeHeader, range);
      final upRes = await fwd.close();
      res.statusCode = upRes.statusCode;
      upRes.headers.forEach((name, values) {
        if (name.toLowerCase() == HttpHeaders.transferEncodingHeader) return;
        res.headers.set(name, values.join(','));
      });
      await upRes.pipe(res);
    } catch (_) {
      // Player seeked (closed this connection) or upstream failed — best effort.
      try {
        await res.close();
      } catch (_) {}
    }
  }
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
}
