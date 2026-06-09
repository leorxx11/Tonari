import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/net/media_proxy.dart';

void main() {
  test('forwards range and releases registered upstream', () async {
    final ranges = <String?>[];
    final customHeaders = <String?>[];
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    upstream.listen((req) async {
      ranges.add(req.headers.value(HttpHeaders.rangeHeader));
      customHeaders.add(req.headers.value('X-Test'));
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 5-9/10');
      req.response.add(utf8.encode('hello'));
      await req.response.close();
    });

    final registration = await MediaProxy.instance.wrap(
      Uri.parse('http://127.0.0.1:${upstream.port}/media.mp4'),
      {'X-Test': 'ok'},
    );
    final client = HttpClient();
    addTearDown(() => client.close());

    final req = await client.getUrl(registration.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=5-9');
    final res = await req.close();
    await res.drain<void>();

    expect(res.statusCode, HttpStatus.partialContent);
    expect(ranges, ['bytes=5-9']);
    expect(customHeaders, ['ok']);

    registration.release();
    final releasedReq = await client.getUrl(registration.url);
    final releasedRes = await releasedReq.close();
    await releasedRes.drain<void>();

    expect(releasedRes.statusCode, HttpStatus.notFound);
  });
}
