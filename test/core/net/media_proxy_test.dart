import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/net/media_proxy.dart';

/// Spins up a loopback server that serves [data] honouring `Range` like a real
/// CDN (206 + `Content-Range`, clamped to EOF). Records each received range and
/// the custom header, so tests can assert what the proxy asked upstream.
Future<_FakeUpstream> _serveBuffer(Uint8List data) async {
  final ranges = <String?>[];
  final headers = <String?>[];
  final remotePorts = <int?>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    ranges.add(req.headers.value(HttpHeaders.rangeHeader));
    headers.add(req.headers.value('X-Test'));
    remotePorts.add(req.connectionInfo?.remotePort);
    final range = req.headers.value(HttpHeaders.rangeHeader);
    var start = 0;
    var end = data.length - 1;
    if (range != null && range.startsWith('bytes=')) {
      final spec = range.substring(6).split('-');
      start = int.parse(spec[0]);
      if (spec[1].isNotEmpty) {
        final asked = int.parse(spec[1]);
        if (asked < end) end = asked;
      }
    }
    req.response.statusCode = HttpStatus.partialContent;
    req.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${data.length}',
    );
    req.response.headers.contentLength = end - start + 1;
    req.response.headers.contentType = ContentType('video', 'mp4');
    req.response.add(data.sublist(start, end + 1));
    await req.response.close();
  });
  return _FakeUpstream(server, ranges, headers, remotePorts);
}

Future<_FakeUpstream> _serveBufferWithFirstReadFailure(Uint8List data) async {
  final ranges = <String?>[];
  final headers = <String?>[];
  final remotePorts = <int?>[];
  var failedFirstRead = false;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    ranges.add(req.headers.value(HttpHeaders.rangeHeader));
    headers.add(req.headers.value('X-Test'));
    remotePorts.add(req.connectionInfo?.remotePort);
    final range = req.headers.value(HttpHeaders.rangeHeader);
    var start = 0;
    var end = data.length - 1;
    if (range != null && range.startsWith('bytes=')) {
      final spec = range.substring(6).split('-');
      start = int.parse(spec[0]);
      if (spec[1].isNotEmpty) {
        final asked = int.parse(spec[1]);
        if (asked < end) end = asked;
      }
    }
    req.response.statusCode = HttpStatus.partialContent;
    req.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${data.length}',
    );
    req.response.headers.contentLength = end - start + 1;
    req.response.headers.contentType = ContentType('audio', 'wav');
    if (!failedFirstRead) {
      failedFirstRead = true;
      req.response.add(data.sublist(start, start + 1));
      await req.response.flush();
      try {
        await req.response.close();
      } on HttpException {
        // The fake CDN intentionally closes before the declared length.
      }
      return;
    }
    req.response.add(data.sublist(start, end + 1));
    await req.response.close();
  });
  return _FakeUpstream(server, ranges, headers, remotePorts);
}

Future<_ControlledUpstream> _serveControlledBuffer(Uint8List data) async {
  final ranges = <String?>[];
  final headers = <String?>[];
  final remotePorts = <int?>[];
  final releases = <Completer<void>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    ranges.add(req.headers.value(HttpHeaders.rangeHeader));
    headers.add(req.headers.value('X-Test'));
    remotePorts.add(req.connectionInfo?.remotePort);
    final release = Completer<void>();
    releases.add(release);
    await release.future;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    var start = 0;
    var end = data.length - 1;
    if (range != null && range.startsWith('bytes=')) {
      final spec = range.substring(6).split('-');
      start = int.parse(spec[0]);
      if (spec[1].isNotEmpty) {
        final asked = int.parse(spec[1]);
        if (asked < end) end = asked;
      }
    }
    req.response.statusCode = HttpStatus.partialContent;
    req.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${data.length}',
    );
    req.response.headers.contentLength = end - start + 1;
    req.response.headers.contentType = ContentType('audio', 'wav');
    req.response.add(data.sublist(start, end + 1));
    await req.response.close();
  });
  return _ControlledUpstream(server, ranges, headers, remotePorts, releases);
}

class _FakeUpstream {
  _FakeUpstream(this.server, this.ranges, this.headers, this.remotePorts);
  final HttpServer server;
  final List<String?> ranges;
  final List<String?> headers;
  // Client-side ephemeral port of each request, as seen by the server. A new
  // socket gets a new port; a reused keep-alive connection keeps the same one.
  final List<int?> remotePorts;
  Uri url(String name) => Uri.parse('http://127.0.0.1:${server.port}/$name');
}

class _ControlledUpstream extends _FakeUpstream {
  _ControlledUpstream(
    super.server,
    super.ranges,
    super.headers,
    super.remotePorts,
    this.releases,
  );

  final List<Completer<void>> releases;

  Future<void> waitForRequests(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (ranges.length < count) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Expected $count upstream requests, got ${ranges.length}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void release(int index) {
    releases[index].complete();
  }
}

Future<int> _drainAllowingTruncated(HttpClientResponse res) async {
  var bytes = 0;
  try {
    await for (final chunk in res) {
      bytes += chunk.length;
    }
  } on HttpException {
    return bytes;
  }
  return bytes;
}

void main() {
  // MediaProxy is a process-wide singleton; without a reset between tests an
  // in-flight stream or the bound server leaks into the next test and makes the
  // suite order-dependent (a released upstream throws "proxy released", a
  // stopped stream keeps flowing). reset() drops the server and all entries.
  tearDown(() => MediaProxy.instance.reset('test_teardown'));

  test(
    'serves a bounded block, re-advertises range, releases upstream',
    () async {
      final data = Uint8List.fromList(List.generate(100, (i) => i));
      final upstream = await _serveBuffer(data);
      addTearDown(() => upstream.server.close(force: true));

      final registration = await MediaProxy.instance.wrap(
        upstream.url('media.mp4'),
        {'X-Test': 'ok'},
      );
      final client = HttpClient();
      addTearDown(() => client.close());

      final req = await client.getUrl(registration.url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=10-');
      final res = await req.close();
      final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));

      expect(res.statusCode, HttpStatus.partialContent);
      expect(body, data.sublist(10));
      expect(
        res.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 10-99/100',
      );
      expect(res.headers.contentLength, 90);
      // Open-ended player range becomes a block-aligned upstream fetch with auth.
      expect(upstream.ranges, ['bytes=0-${MediaProxy.chunkBytes - 1}']);
      expect(upstream.headers, ['ok']);

      registration.release();
      final releasedReq = await client.getUrl(registration.url);
      final releasedRes = await releasedReq.close();
      await releasedRes.drain<void>();
      expect(releasedRes.statusCode, HttpStatus.notFound);
    },
  );

  test('relays upstream rejection body', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    upstream.listen((req) async {
      req.response.statusCode = HttpStatus.forbidden;
      req.response.write('no cookie value');
      await req.response.close();
    });

    final registration = await MediaProxy.instance.wrap(
      Uri.parse('http://127.0.0.1:${upstream.port}/blocked.mp4'),
      const {},
    );
    addTearDown(registration.release);
    final client = HttpClient();
    addTearDown(() => client.close());

    final req = await client.getUrl(registration.url);
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    expect(res.statusCode, HttpStatus.forbidden);
    expect(body, 'no cookie value');
  });

  test(
    'serves repeated reads inside one block from cache (no extra upstream)',
    () async {
      final data = Uint8List.fromList(List.generate(100, (i) => i));
      final upstream = await _serveBuffer(data);
      addTearDown(() => upstream.server.close(force: true));

      final registration = await MediaProxy.instance.wrap(
        upstream.url('media.mp4'),
        const {},
      );
      addTearDown(registration.release);
      final client = HttpClient();
      addTearDown(() => client.close());

      Future<List<int>> read(int from) async {
        final req = await client.getUrl(registration.url);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
        final res = await req.close();
        return res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      }

      expect(await read(10), data.sublist(10));
      expect(await read(20), data.sublist(20));
      expect(await read(50), data.sublist(50));
      // All three fall in block 0; only the first hits upstream.
      expect(upstream.ranges, ['bytes=0-${MediaProxy.chunkBytes - 1}']);
    },
  );

  test(
    'fetches a second block when the read crosses the grid boundary',
    () async {
      final total = MediaProxy.chunkBytes + 100;
      final data = Uint8List(total);
      for (var i = 0; i < total; i++) {
        data[i] = i & 0xff;
      }
      final upstream = await _serveBuffer(data);
      addTearDown(() => upstream.server.close(force: true));

      final registration = await MediaProxy.instance.wrap(
        upstream.url('media.mp4'),
        const {},
      );
      addTearDown(registration.release);
      final client = HttpClient();
      addTearDown(() => client.close());

      Future<int> readLen(int from) async {
        final req = await client.getUrl(registration.url);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
        final res = await req.close();
        var n = 0;
        await for (final c in res) {
          n += c.length;
        }
        return n;
      }

      // First block: served bounded to the grid boundary.
      expect(await readLen(0), MediaProxy.chunkBytes);
      // Crossing into block 1 triggers a clamped second fetch.
      expect(await readLen(MediaProxy.chunkBytes), 100);
      expect(upstream.ranges, [
        'bytes=0-${MediaProxy.chunkBytes - 1}',
        'bytes=${MediaProxy.chunkBytes}-${total - 1}',
      ]);
    },
  );

  test('audio proxy streams the full range across blocks', () async {
    // AVPlayer asks for the whole file and treats a truncated 206 as broken,
    // so audio must deliver the full requested range — not one bounded block.
    final total = MediaProxy.chunkBytes * 2 + 100;
    final data = Uint8List(total);
    for (var i = 0; i < total; i++) {
      data[i] = i & 0xff;
    }
    final upstream = await _serveBuffer(data);
    addTearDown(() => upstream.server.close(force: true));

    final registration = await MediaProxy.instance.wrapAudio(
      upstream.url('audio.wav'),
      {'X-Test': 'ok'},
    );
    addTearDown(registration.release);
    final client = HttpClient();
    addTearDown(() => client.close());

    final req = await client.getUrl(registration.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${total - 1}');
    final res = await req.close();
    final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));

    expect(res.statusCode, HttpStatus.partialContent);
    expect(body, data);
    expect(
      res.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 0-${total - 1}/$total',
    );
    expect(res.headers.contentLength, total);
    // Fetched as gated 4 MiB blocks, not one giant upstream connection.
    expect(upstream.ranges, [
      'bytes=0-${MediaProxy.chunkBytes - 1}',
      'bytes=${MediaProxy.chunkBytes}-${MediaProxy.chunkBytes * 2 - 1}',
      'bytes=${MediaProxy.chunkBytes * 2}-${total - 1}',
    ]);
    expect(upstream.headers, ['ok', 'ok', 'ok']);
  });

  test('audio proxy retries a failed upstream block read', () async {
    final data = Uint8List.fromList(List.generate(100, (i) => i));
    final upstream = await _serveBufferWithFirstReadFailure(data);
    addTearDown(() => upstream.server.close(force: true));

    final registration = await MediaProxy.instance.wrapAudio(
      upstream.url('audio.wav'),
      {'X-Test': 'ok'},
    );
    addTearDown(registration.release);
    final client = HttpClient();
    addTearDown(() => client.close());

    final req = await client.getUrl(registration.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${data.length - 1}');
    final res = await req.close();
    final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));

    expect(res.statusCode, HttpStatus.partialContent);
    expect(body, data);
    expect(upstream.ranges, [
      'bytes=0-${MediaProxy.chunkBytes - 1}',
      'bytes=0-${MediaProxy.chunkBytes - 1}',
    ]);
    expect(upstream.headers, ['ok', 'ok']);
    expect(upstream.remotePorts.whereType<int>().toSet(), hasLength(2));
  });

  test('audio proxy serves an in-block slice', () async {
    final data = Uint8List.fromList(List.generate(100, (i) => i));
    final upstream = await _serveBuffer(data);
    addTearDown(() => upstream.server.close(force: true));

    final registration = await MediaProxy.instance.wrapAudio(
      upstream.url('audio.wav'),
      const {},
    );
    addTearDown(registration.release);
    final client = HttpClient();
    addTearDown(() => client.close());

    final req = await client.getUrl(registration.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=10-30');
    final res = await req.close();
    final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));

    expect(res.statusCode, HttpStatus.partialContent);
    expect(body, data.sublist(10, 31));
    expect(
      res.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 10-30/100',
    );
    expect(res.headers.contentLength, 21);
  });

  test('audio proxy reuses one upstream connection across blocks', () async {
    // Each 4 MiB block is still a separate upstream request, but they must ride
    // one pooled keep-alive connection — a fresh TCP+TLS handshake per block is
    // what overheated the phone during background playback.
    final total = MediaProxy.chunkBytes * 2 + 100;
    final data = Uint8List(total);
    for (var i = 0; i < total; i++) {
      data[i] = i & 0xff;
    }
    final upstream = await _serveBuffer(data);
    addTearDown(() => upstream.server.close(force: true));

    final registration = await MediaProxy.instance.wrapAudio(
      upstream.url('audio.wav'),
      const {},
    );
    addTearDown(registration.release);
    final client = HttpClient();
    addTearDown(() => client.close());

    final req = await client.getUrl(registration.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${total - 1}');
    final res = await req.close();
    await res.drain<void>();

    // Three block fetches, all over a single reused connection (one port).
    expect(upstream.ranges, hasLength(3));
    expect(upstream.remotePorts.whereType<int>().toSet(), hasLength(1));
  });

  test('new long audio range stops the previous long stream', () async {
    final total = MediaProxy.chunkBytes * 4;
    final data = Uint8List(total);
    for (var i = 0; i < total; i++) {
      data[i] = i & 0xff;
    }
    final upstream = await _serveControlledBuffer(data);
    addTearDown(() => upstream.server.close(force: true));

    final registration = await MediaProxy.instance.wrapAudio(
      upstream.url('audio.wav'),
      const {},
    );
    addTearDown(registration.release);
    final client = HttpClient();
    addTearDown(() => client.close());

    final firstReq = await client.getUrl(registration.url);
    firstReq.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${total - 1}');
    final firstResFuture = firstReq.close();
    await upstream.waitForRequests(1);
    upstream.release(0);
    final firstRes = await firstResFuture;
    final firstDrain = _drainAllowingTruncated(firstRes);

    // First stream is now parked on its block-1 fetch (held by the fake CDN).
    await upstream.waitForRequests(2);

    // The second range spans blocks 2-3: long enough (> chunkBytes) to claim
    // the stream, and starting at a block nobody has fetched, so its first
    // fetch is a NEW upstream request. Request 3 arriving therefore proves the
    // takeover claim already happened (the claim precedes the first block fetch
    // in program order). Only then is block 1 released, so the first stream
    // deterministically wakes up already superseded. Starting it at block 1
    // instead would join the in-flight fetch (no observable signal) and race
    // the claim against the release.
    final secondReq = await client.getUrl(registration.url);
    secondReq.headers.set(
      HttpHeaders.rangeHeader,
      'bytes=${MediaProxy.chunkBytes * 2}-${total - 1}',
    );
    final secondResFuture = secondReq.close();
    await upstream.waitForRequests(3);

    upstream.release(1);
    expect(await firstDrain, MediaProxy.chunkBytes);

    upstream.release(2);
    final secondRes = await secondResFuture;
    final secondDrain = _drainAllowingTruncated(secondRes);
    await upstream.waitForRequests(4);
    upstream.release(3);
    expect(await secondDrain, total - MediaProxy.chunkBytes * 2);

    expect(upstream.ranges, [
      'bytes=0-${MediaProxy.chunkBytes - 1}',
      'bytes=${MediaProxy.chunkBytes}-${MediaProxy.chunkBytes * 2 - 1}',
      'bytes=${MediaProxy.chunkBytes * 2}-${MediaProxy.chunkBytes * 3 - 1}',
      'bytes=${MediaProxy.chunkBytes * 3}-${total - 1}',
    ]);
  });

  test('reset completes without throwing and the server rebinds', () async {
    final data = Uint8List.fromList(List.generate(100, (i) => i));
    final upstream = await _serveBuffer(data);
    addTearDown(() => upstream.server.close(force: true));

    final first = await MediaProxy.instance.wrap(
      upstream.url('a.mp4'),
      const {},
    );
    // reset() reads the port internally; if it did so after close() it would
    // throw "HttpServer is not bound to a socket" and break a video→audio switch.
    await MediaProxy.instance.reset('test');
    first.release();

    // A fresh registration still works on a newly bound server.
    final second = await MediaProxy.instance.wrap(
      upstream.url('b.mp4'),
      const {},
    );
    addTearDown(second.release);
    final client = HttpClient();
    addTearDown(() => client.close());
    final req = await client.getUrl(second.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
    final res = await req.close();
    final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    expect(res.statusCode, HttpStatus.partialContent);
    expect(body, data);
  });

  test('revive is a no-op on a healthy server and keeps the URL alive', () async {
    final data = Uint8List.fromList(List.generate(100, (i) => i));
    final upstream = await _serveBuffer(data);
    addTearDown(() => upstream.server.close(force: true));
    final registration = await MediaProxy.instance.wrap(
      upstream.url('a.mp4'),
      const {},
    );
    addTearDown(registration.release);

    expect(await MediaProxy.instance.revive(), isTrue);

    final client = HttpClient();
    addTearDown(() => client.close());
    final req = await client.getUrl(registration.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
    final res = await req.close();
    final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    expect(res.statusCode, HttpStatus.partialContent);
    expect(body, data);
  });

  test('revive with no server running reports healthy', () async {
    await MediaProxy.instance.reset('test');
    expect(await MediaProxy.instance.revive(), isTrue);
  });
}
