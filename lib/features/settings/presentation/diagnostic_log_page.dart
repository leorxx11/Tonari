import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/ui/app_toast.dart';
import '../../../shared/widgets/library_home_button.dart';

class DiagnosticLogPage extends StatefulWidget {
  const DiagnosticLogPage({super.key});

  @override
  State<DiagnosticLogPage> createState() => _DiagnosticLogPageState();
}

class _DiagnosticLogPageState extends State<DiagnosticLogPage> {
  var _active = DiagnosticLog.enabled;
  var _session = DiagnosticLog.session;
  var _content = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final content = await DiagnosticLog.read();
    if (!mounted) return;
    setState(() {
      _active = DiagnosticLog.enabled;
      _session = DiagnosticLog.session;
      _content = content;
    });
  }

  Future<void> _stop() async {
    await DiagnosticLog.stopSession();
    await _refresh();
  }

  Future<void> _resume() async {
    await DiagnosticLog.resumeSession();
    await _refresh();
  }

  Future<void> _startNew() async {
    await DiagnosticLog.startSession();
    await _refresh();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (!mounted) return;
    showAppToast('日志已复制');
  }

  Future<void> _export() async {
    final path = await DiagnosticLog.exportTxt();
    if (!mounted) return;
    if (path == null) {
      showAppToast('暂无日志');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: '诊断日志'),
    );
  }

  Future<void> _clear() async {
    await DiagnosticLog.clear();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: const Text('诊断日志'),
        actions: const [LibraryHomeButton()],
      ),
      body: ListView(
        children: [
          if (_active)
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text('停止采集'),
              subtitle: Text('会话 $_session'),
              onTap: _stop,
            )
          else ...[
            if (_session.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('继续采集'),
                subtitle: Text('沿用会话 $_session，不清空日志'),
                onTap: _resume,
              ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('开始新会话'),
              subtitle: const Text('清空旧日志并开始新的诊断会话'),
              onTap: _startNew,
            ),
          ],
          const Divider(height: 0.5),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('复制日志'),
            enabled: _content.isNotEmpty,
            onTap: _content.isEmpty ? null : _copy,
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('导出 txt'),
            enabled: _content.isNotEmpty,
            onTap: _content.isEmpty ? null : _export,
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('刷新'),
            onTap: _refresh,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清空'),
            enabled: _content.isNotEmpty,
            onTap: _content.isEmpty ? null : _clear,
          ),
          const Divider(height: 0.5),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _content.isEmpty ? '暂无日志' : _content,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _content.isEmpty ? secondary : null,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
