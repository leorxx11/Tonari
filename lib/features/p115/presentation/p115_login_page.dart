import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/p115_auth_service.dart';
import '../data/p115_cookie_store.dart';

class P115LoginPage extends ConsumerStatefulWidget {
  const P115LoginPage({super.key});

  @override
  ConsumerState<P115LoginPage> createState() => _P115LoginPageState();
}

class _P115LoginPageState extends ConsumerState<P115LoginPage> {
  late Future<P115QrToken> _future;
  Timer? _timer;
  String _status = '正在获取二维码…';

  @override
  void initState() {
    super.initState();
    _future = _create();
  }

  Future<P115QrToken> _create() async {
    final token = await ref.read(p115AuthServiceProvider).createQrToken();
    _status = '请用 115 App 扫码';
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_poll(token)),
    );
    return token;
  }

  Future<void> _poll(P115QrToken token) async {
    final status = await ref.read(p115AuthServiceProvider).pollQrStatus(token);
    if (status.waiting) {
      _setStatus('请用 115 App 扫码');
    } else if (status.scanned) {
      _setStatus('已扫码，请在手机上确认');
    } else if (status.confirmed) {
      _timer?.cancel();
      _setStatus('登录成功，正在保存 Cookie…');
      try {
        await ref.read(p115AuthServiceProvider).finishQrLogin(token.uid);
        ref.invalidate(p115CookieProvider);
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        _setStatus('保存 Cookie 失败：$e');
      }
    } else if (status.expired) {
      _timer?.cancel();
      _setStatus('二维码已过期，请刷新');
    } else if (status.canceled) {
      _timer?.cancel();
      _setStatus('已取消登录');
    }
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _timer?.cancel();
    setState(() {
      _status = '正在获取二维码…';
      _future = _create();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录 115')),
      body: FutureBuilder<P115QrToken>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            );
          }
          final token = snapshot.data!;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      token.imageUrl.toString(),
                      width: 240,
                      height: 240,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新二维码'),
                    onPressed: _refresh,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
