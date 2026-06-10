import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/p115_auth_service.dart';
import '../data/p115_cookie_store.dart';
import 'p115_login_page.dart';

class P115SettingsPage extends ConsumerWidget {
  const P115SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cookie = ref.watch(p115CookieProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('115 网盘')),
      body: cookie.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (c) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(c == null ? '未登录' : '已登录'),
              subtitle: c == null ? null : Text('UID ${c.uid}'),
            ),
            const Divider(height: 0.5),
            if (c == null)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('登录 115'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const P115LoginPage(),
                    ),
                  );
                  ref.invalidate(p115CookieProvider);
                },
              )
            else
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _logout(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出 115 登录'),
        content: const Text('将清除本机保存的 115 登录信息（Cookie）。需要时可重新扫码登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (!(confirm ?? false)) return;
    await ref.read(p115AuthServiceProvider).clearCookie();
    ref.invalidate(p115CookieProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已退出 115 登录')));
    }
  }
}
