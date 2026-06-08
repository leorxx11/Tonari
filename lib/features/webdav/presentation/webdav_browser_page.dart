import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/scanner/file_classifier.dart';
import '../data/webdav_client.dart';
import '../data/webdav_import_flow.dart';

/// Browse-and-import view for a WebDAV server. Opened as a CupertinoSheetRoute
/// (drag down to dismiss the whole thing). Drill-down is a single page with an
/// internal path stack + breadcrumbs — not a stack of pushed routes — so the
/// user never has to pop level-by-level. Playback happens through the library.
class WebdavBrowserPage extends ConsumerStatefulWidget {
  const WebdavBrowserPage({
    super.key,
    required this.server,
    required this.config,
  });

  final WebdavServer server;
  final WebdavConfig config;

  @override
  ConsumerState<WebdavBrowserPage> createState() => _WebdavBrowserPageState();
}

class _WebdavBrowserPageState extends ConsumerState<WebdavBrowserPage> {
  late List<String> _stack; // absolute server paths; last == current dir
  late Future<List<WebdavEntry>> _future;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _stack = [widget.config.normalizedBasePath];
    _future = _list();
  }

  Future<List<WebdavEntry>> _list() =>
      ref.read(webdavClientProvider).list(widget.config, _stack.last);

  String get _currentPath => _stack.last;

  void _enter(WebdavEntry e) {
    setState(() {
      _stack.add(e.path);
      _future = _list();
    });
  }

  void _jumpTo(int index) {
    if (index >= _stack.length - 1) return;
    setState(() {
      _stack = _stack.sublist(0, index + 1);
      _future = _list();
    });
  }

  void _onBack() {
    if (_stack.length > 1) {
      setState(() {
        _stack.removeLast();
        _future = _list();
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _reload() => setState(() => _future = _list());

  String _nameOf(String path) {
    if (path == widget.config.normalizedBasePath) return widget.server.name;
    final p = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = p.lastIndexOf('/');
    return i < 0 ? p : p.substring(i + 1);
  }

  Future<void> _importHere() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入到媒体库'),
        content: Text('扫描「${_nameOf(_currentPath)}」下的所有 RJ 作品并导入媒体库？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (!(confirm ?? false) || !mounted) return;

    final progress = ValueNotifier<String>('准备扫描…');
    setState(() => _importing = true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: progress,
                  builder: (_, msg, _) => Text(msg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final summary = await ref
          .read(webdavImportFlowProvider)
          .importFolder(
            server: widget.server,
            config: widget.config,
            remotePath: _currentPath,
            onProgress: (n, cur) => progress.value = '已扫描 $n 个作品\n$cur',
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：${summary.worksInserted} 新增 / ${summary.worksUpdated} 更新，'
            '共 ${summary.tracksTotal} 音轨。封面和元数据后台补全中。',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    } finally {
      progress.dispose();
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _onBack),
        title: Text(
          _nameOf(_currentPath),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '导入此目录到媒体库',
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.library_add_outlined),
            onPressed: _importing ? null : _importHere,
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          _Breadcrumbs(
            serverName: widget.server.name,
            stack: _stack,
            onTap: _jumpTo,
          ),
          const Divider(height: 0.5),
          Expanded(
            child: FutureBuilder<List<WebdavEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(message: '${snap.error}', onRetry: _reload);
                }
                final entries = snap.data ?? const <WebdavEntry>[];
                if (entries.isEmpty) {
                  return const Center(child: Text('此目录为空'));
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 0.5, indent: 56),
                  itemBuilder: (_, i) =>
                      _EntryRow(entry: entries[i], onOpenDir: _enter),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({
    required this.serverName,
    required this.stack,
    required this.onTap,
  });

  final String serverName;
  final List<String> stack;
  final void Function(int index) onTap;

  String _seg(int i) {
    if (i == 0) return serverName;
    final p = stack[i];
    final c = p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    final idx = c.lastIndexOf('/');
    return idx < 0 ? c : c.substring(idx + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iosBlue = CupertinoColors.systemBlue.resolveFrom(context);
    final iosLabel = CupertinoColors.label.resolveFrom(context);
    final iosTertiary = CupertinoColors.tertiaryLabel.resolveFrom(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < stack.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '/',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: iosTertiary,
                  ),
                ),
              ),
            InkWell(
              onTap: i == stack.length - 1 ? null : () => onTap(i),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  _seg(i),
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: i == stack.length - 1 ? iosLabel : iosBlue,
                    fontWeight: i == stack.length - 1
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onOpenDir});

  final WebdavEntry entry;
  final void Function(WebdavEntry) onOpenDir;

  @override
  Widget build(BuildContext context) {
    final iosBlue = CupertinoColors.systemBlue.resolveFrom(context);
    final iosSecondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    if (entry.isDir) {
      return ListTile(
        leading: Icon(Icons.folder_rounded, color: iosBlue, size: 40),
        title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Icon(
          CupertinoIcons.chevron_right,
          size: 14,
          color: iosSecondary,
        ),
        onTap: () => onOpenDir(entry),
      );
    }
    // Files are display-only; playback is through the library.
    final isAudio = FileClassifier.classify(entry.name) == FileKind.audio;
    return ListTile(
      leading: Icon(
        isAudio ? CupertinoIcons.music_note : CupertinoIcons.doc_fill,
        color: iosSecondary,
        size: 34,
      ),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: entry.size == null ? null : Text(_fmtBytes(entry.size!)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
