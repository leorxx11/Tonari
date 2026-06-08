import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'p115_client.dart';
import 'p115_cookie_store.dart';

class P115QrToken {
  const P115QrToken({
    required this.uid,
    required this.time,
    required this.sign,
  });

  final String uid;
  final int time;
  final String sign;

  Uri get imageUrl =>
      Uri.https('qrcodeapi.115.com', '/api/1.0/tv/1.0/qrcode', {'uid': uid});
}

class P115QrStatus {
  const P115QrStatus(this.status);

  final int status;

  bool get waiting => status == 0;
  bool get scanned => status == 1;
  bool get confirmed => status == 2;
  bool get expired => status == -1;
  bool get canceled => status == -2;
}

class P115AuthService {
  P115AuthService({required this.cookieStore, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final P115CookieStore cookieStore;
  final Dio _dio;

  Future<P115QrToken> createQrToken() async {
    final res = await _dio.get<dynamic>(
      'https://qrcodeapi.115.com/api/1.0/tv/1.0/token/',
    );
    final data = _data(res.data);
    return P115QrToken(
      uid: '${data['uid']}',
      time: int.parse('${data['time']}'),
      sign: '${data['sign']}',
    );
  }

  Future<P115QrStatus> pollQrStatus(P115QrToken token) async {
    final res = await _dio.get<dynamic>(
      'https://qrcodeapi.115.com/get/status/',
      queryParameters: {
        'uid': token.uid,
        'time': token.time,
        'sign': token.sign,
        '_': DateTime.now().millisecondsSinceEpoch,
      },
    );
    final data = _data(res.data);
    return P115QrStatus(int.parse('${data['status']}'));
  }

  Future<P115Cookie> finishQrLogin(String uid) async {
    final res = await _dio.post<dynamic>(
      'https://qrcodeapi.115.com/app/1.0/tv/1.0/login/qrcode/',
      data: {'account': uid},
      options: Options(
        headers: {'User-Agent': 'Mozilla/5.0 115Browser/30.4.0'},
      ),
    );
    final data = _data(res.data);
    final cookieRaw = data['cookie'];
    final cookie = cookieRaw is Map
        ? P115Cookie.fromApiCookie(Map<String, dynamic>.from(cookieRaw))
        : P115Cookie.parse('$cookieRaw');
    await cookieStore.write(cookie);
    return cookie;
  }

  Future<void> clearCookie() => cookieStore.clear();

  Map<String, dynamic> _data(dynamic body) {
    final json = _asJson(body);
    final state = json['state'];
    if (state != true && state != 1) {
      throw P115Exception('${json['error'] ?? json['message'] ?? '115 登录失败'}');
    }
    return Map<String, dynamic>.from(json['data'] as Map);
  }

  Map<String, dynamic> _asJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(jsonDecode('$data') as Map);
  }
}

final p115AuthServiceProvider = Provider<P115AuthService>((ref) {
  return P115AuthService(cookieStore: ref.watch(p115CookieStoreProvider));
});
