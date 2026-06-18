import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/browse/data/remote_models.dart';
import 'package:tonari/features/p115/data/p115_cipher.dart';
import 'package:tonari/features/p115/data/p115_client.dart';
import 'package:tonari/features/p115/data/p115_cookie_store.dart';

class _MemoryBackend implements P115CookieBackend {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _DownurlCookieInterceptor extends Interceptor {
  final cookies = <String?>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    cookies.add(options.headers['Cookie'] as String?);
    final uri = options.uri.toString();
    if (uri == 'https://proapi.115.com/app/chrome/downurl') {
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 302,
          headers: Headers.fromMap({
            'location': ['https://dl302.test/first'],
            'set-cookie': ['acw_tc=first; Path=/'],
          }),
        ),
      );
      return;
    }
    if (uri == 'https://dl302.test/first') {
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 302,
          headers: Headers.fromMap({
            'location': ['https://dl302.test/second'],
            'set-cookie': ['acw_tc=second; Path=/', 'dl=token; Path=/'],
          }),
        ),
      );
      return;
    }
    if (uri == 'https://dl302.test/second') {
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'state': false, 'message': 'stop before decrypt'},
        ),
      );
      return;
    }
    handler.reject(
      DioException(requestOptions: options, message: 'unexpected request $uri'),
    );
  }
}

class _ThrottledApiInterceptor extends Interceptor {
  _ThrottledApiInterceptor(this.delay);

  final Duration delay;
  final starts = <DateTime>[];
  final kinds = <String>[];
  var active = 0;
  var maxActive = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final kind = _kind(options);
    starts.add(DateTime.now());
    kinds.add(kind);
    active++;
    if (active > maxActive) maxActive = active;

    Future<void>.delayed(delay).then((_) {
      active--;
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: kind.startsWith('files:')
              ? {'state': true, 'count': 0, 'data': <Object>[]}
              : {'state': false, 'message': 'stop before decrypt'},
        ),
      );
    });
  }

  String _kind(RequestOptions options) {
    final uri = options.uri;
    if (uri.host == 'webapi.115.com' && uri.path == '/files') {
      return 'files:${options.queryParameters['cid']}';
    }
    if (uri.host == 'proapi.115.com' && uri.path == '/app/chrome/downurl') {
      return 'downurl';
    }
    throw StateError('unexpected request $uri');
  }
}

void main() {
  test('maps 115 directory response into remote entries', () {
    final entries = P115Client.mapEntries({
      'state': true,
      'data': [
        {'cid': '10', 'n': 'Folder'},
        {'fid': '20', 'n': 'voice.mp3', 's': '100', 'pc': 'pc-audio'},
        {'fid': '21', 'n': 'movie.mkv', 's': 200, 'pc': 'pc-video'},
        {'fid': '22', 'n': 'archive.zip', 's': 300, 'pc': 'pc-other'},
      ],
    });

    expect(entries[0].kind, RemoteEntryKind.folder);
    expect(entries[1].kind, RemoteEntryKind.other);
    expect(entries[2].kind, RemoteEntryKind.video);
    expect(entries[3].kind, RemoteEntryKind.audio);
    expect(entries[3].pickcode, 'pc-audio');
  });

  test('encrypts app downurl payload like p115cipher', () {
    expect(
      P115Cipher.encryptJson({'pickcode': 'abc123'}),
      'C/K77ytKjE5SY30/UtT17jMnyejh5T37Y+9d81OQjzpnjAOCFf4wcD8rdnb1libQRKTXYIemT2bL+larZoLw5pZeGo5VVhAJZ30kBza7gFvthr+fMoV5JdDakSH1ROiHtPjgzw58owP5qcr/mvbf1WOBGkfJwpiFIM9UFR/xlbo=',
    );
  });

  test('passes redirect cookies to following downurl hops', () async {
    final store = P115CookieStore(backend: _MemoryBackend());
    await store.write(
      const P115Cookie(uid: 'u', cid: 'c', seid: 's', kid: 'k'),
    );
    final interceptor = _DownurlCookieInterceptor();
    final dio = Dio()..interceptors.add(interceptor);
    final client = P115Client(cookieStore: store, dio: dio);

    await expectLater(
      client.resolveVideoUrl('pickcode'),
      throwsA(isA<P115Exception>()),
    );

    expect(interceptor.cookies, hasLength(3));
    expect(interceptor.cookies[0], 'UID=u; CID=c; SEID=s; KID=k');
    expect(interceptor.cookies[1], contains('UID=u'));
    expect(interceptor.cookies[1], contains('acw_tc=first'));
    expect(interceptor.cookies[2], contains('UID=u'));
    expect(interceptor.cookies[2], contains('acw_tc=second'));
    expect(interceptor.cookies[2], contains('dl=token'));
    expect(interceptor.cookies[2], isNot(contains('acw_tc=first')));
  });

  test('serializes list and downurl requests through one p115 gate', () async {
    final store = P115CookieStore(backend: _MemoryBackend());
    await store.write(
      const P115Cookie(uid: 'u', cid: 'c', seid: 's', kid: 'k'),
    );
    final interceptor = _ThrottledApiInterceptor(
      const Duration(milliseconds: 20),
    );
    final dio = Dio()..interceptors.add(interceptor);
    final client = P115Client(
      cookieStore: store,
      dio: dio,
      apiMinInterval: const Duration(milliseconds: 60),
    );

    await Future.wait<void>([
      client.list('root').then<void>((_) {}),
      client.resolveVideoUrl('pickcode').then<void>((_) {}, onError: (_) {}),
    ]);

    expect(interceptor.kinds, ['files:root', 'downurl']);
    expect(interceptor.maxActive, 1);
    expect(
      interceptor.starts[1].difference(interceptor.starts[0]).inMilliseconds,
      greaterThanOrEqualTo(45),
    );
  });
}
