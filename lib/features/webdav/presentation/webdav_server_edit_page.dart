import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../data/webdav_client.dart';
import '../data/webdav_server_repository.dart';

class WebdavServerEditPage extends ConsumerStatefulWidget {
  const WebdavServerEditPage({super.key, this.server});

  final WebdavServer? server;

  @override
  ConsumerState<WebdavServerEditPage> createState() =>
      _WebdavServerEditPageState();
}

class _WebdavServerEditPageState extends ConsumerState<WebdavServerEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _basePath;
  late final TextEditingController _username;
  late final TextEditingController _password;
  String _scheme = 'https';
  bool _obscurePassword = true;
  bool _testing = false;
  bool _saving = false;
  String? _passwordHint;

  bool get _isEdit => widget.server != null;

  @override
  void initState() {
    super.initState();
    final s = widget.server;
    _name = TextEditingController(text: s?.name ?? '');
    _host = TextEditingController(text: s?.host ?? '');
    _port = TextEditingController(text: s?.port?.toString() ?? '');
    _basePath = TextEditingController(text: s?.basePath ?? '');
    _username = TextEditingController(text: s?.username ?? '');
    _password = TextEditingController();
    _scheme = s?.scheme ?? 'https';
    if (s != null) _loadPasswordHint(s.id);
  }

  Future<void> _loadPasswordHint(String serverId) async {
    final pw = await ref
        .read(webdavServerRepositoryProvider)
        .readPassword(serverId);
    if (!mounted) return;
    if (pw != null && pw.isNotEmpty) {
      setState(() => _passwordHint = '已保存（留空保留原值）');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _basePath.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _host.text.trim().isNotEmpty;

  int? _parsedPort() {
    final t = _port.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  WebdavConfig _config(String? password) {
    return WebdavConfig(
      scheme: _scheme,
      host: _host.text.trim(),
      port: _parsedPort(),
      basePath: _basePath.text.trim().isEmpty ? null : _basePath.text.trim(),
      username: _username.text.trim().isEmpty ? null : _username.text.trim(),
      password: password,
    );
  }

  Future<void> _testConnection() async {
    if (_host.text.trim().isEmpty) {
      _snack('请先填写主机地址');
      return;
    }
    if (_port.text.trim().isNotEmpty && _parsedPort() == null) {
      _snack('端口必须是数字');
      return;
    }
    String? password = _password.text.isEmpty ? null : _password.text;
    if (password == null && _isEdit) {
      password = await ref
          .read(webdavServerRepositoryProvider)
          .readPassword(widget.server!.id);
    }
    setState(() => _testing = true);
    try {
      await ref.read(webdavClientProvider).testConnection(_config(password));
      if (!mounted) return;
      _snack('连接成功');
    } catch (e) {
      if (!mounted) return;
      _snack('连接失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    if (_port.text.trim().isNotEmpty && _parsedPort() == null) {
      _snack('端口必须是数字');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(webdavServerRepositoryProvider);
      final password = _password.text.isEmpty ? null : _password.text;
      final basePath =
          _basePath.text.trim().isEmpty ? null : _basePath.text.trim();
      final username =
          _username.text.trim().isEmpty ? null : _username.text.trim();
      if (_isEdit) {
        await repo.update(
          id: widget.server!.id,
          name: _name.text.trim(),
          scheme: _scheme,
          host: _host.text.trim(),
          port: _parsedPort(),
          basePath: basePath,
          username: username,
          password: password,
        );
      } else {
        await repo.create(
          name: _name.text.trim(),
          scheme: _scheme,
          host: _host.text.trim(),
          port: _parsedPort(),
          basePath: basePath,
          username: username,
          password: password,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _snack('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑 WebDAV' : '添加 WebDAV'),
        actions: [
          TextButton(
            onPressed: _canSave && !_saving ? _save : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '例如 家里的 Alist',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'https', label: Text('https')),
              ButtonSegment(value: 'http', label: Text('http')),
            ],
            selected: {_scheme},
            onSelectionChanged: (s) => setState(() => _scheme = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _host,
                  decoration: const InputDecoration(
                    labelText: '主机地址',
                    hintText: '192.168.1.10 或 dav.example.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _port,
                  decoration: const InputDecoration(
                    labelText: '端口',
                    hintText: '5244',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _basePath,
            decoration: const InputDecoration(
              labelText: '路径（可选）',
              hintText: '/dav',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: '用户名（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: _isEdit ? '密码（留空保留原值）' : '密码',
              hintText: _passwordHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: const Text('测试连接'),
            onPressed: _testing ? null : _testConnection,
          ),
        ],
      ),
    );
  }
}
