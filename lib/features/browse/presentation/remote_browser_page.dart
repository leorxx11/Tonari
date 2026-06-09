import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/data/playback_controller.dart';
import '../../video/data/video_controller.dart';
import '../data/browse_location_store.dart';
import '../data/remote_models.dart';

typedef RemoteFolderLoader =
    Future<List<RemoteEntry>> Function(RemoteEntry folder);
typedef RemoteFileResolver =
    Future<ResolvedMediaUrl> Function(RemoteEntry file);
typedef RemoteFolderAction =
    Future<void> Function(BuildContext context, RemoteEntry folder);

class RemoteBrowserPage extends ConsumerStatefulWidget {
  const RemoteBrowserPage({
    super.key,
    required this.sourceKind,
    required this.sourceId,
    required this.sourceName,
    required this.root,
    required this.loadFolder,
    required this.resolveFile,
    this.importFolder,
  });

  final RemoteSourceKind sourceKind;
  final String sourceId;
  final String sourceName;
  final RemoteEntry root;
  final RemoteFolderLoader loadFolder;
  final RemoteFileResolver resolveFile;
  final RemoteFolderAction? importFolder;

  @override
  ConsumerState<RemoteBrowserPage> createState() => _RemoteBrowserPageState();
}

class _RemoteBrowserPageState extends ConsumerState<RemoteBrowserPage> {
  late List<RemoteEntry> _stack;
  late Future<List<RemoteEntry>> _future;
  BrowseLocationStore? _locationStore;

  @override
  void initState() {
    super.initState();
    // Restore the last folder stack for this source (best effort — degrade to
    // the root if prefs are unavailable, e.g. in tests).
    try {
      _locationStore = ref.read(browseLocationStoreProvider);
    } catch (_) {
      _locationStore = null;
    }
    final saved = _locationStore?.read(widget.sourceId);
    _stack = (saved != null && saved.isNotEmpty) ? saved : [widget.root];
    _future = _list();
  }

  void _saveLocation() {
    _locationStore?.write(widget.sourceId, _stack);
  }

  RemoteEntry get _current => _stack.last;

  Future<List<RemoteEntry>> _list() => widget.loadFolder(_current);

  void _reload() => setState(() => _future = _list());

  void _enter(RemoteEntry folder) {
    setState(() {
      _stack.add(folder);
      _future = _list();
    });
    _saveLocation();
  }

  void _jumpTo(int index) {
    if (index >= _stack.length - 1) return;
    setState(() {
      _stack = _stack.sublist(0, index + 1);
      _future = _list();
    });
    _saveLocation();
  }

  void _onBack() {
    if (_stack.length > 1) {
      setState(() {
        _stack.removeLast();
        _future = _list();
      });
      _saveLocation();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _importHere() async {
    final importFolder = widget.importFolder;
    if (importFolder == null) return;
    await importFolder(context, _current);
  }

  Future<void> _playAudio(RemoteEntry entry, List<RemoteEntry> entries) async {
    final audioEntries = entries.where((e) => e.isAudio).toList();
    final items = audioEntries.map(_toPlayable).toList();
    final index = audioEntries.indexWhere((e) => e.id == entry.id);
    await ref
        .read(playbackControllerProvider.notifier)
        .startBrowseQueue(items: items, initialIndex: index);
  }

  void _openVideo(RemoteEntry entry) {
    // Start playback in the mini player (like audio); tap the mini bar to open
    // the full-screen view. No auto-push.
    ref.read(videoControllerProvider.notifier).open(_toPlayable(entry));
  }

  PlayableItem _toPlayable(RemoteEntry entry) {
    return PlayableItem(
      id: '${widget.sourceId}:${entry.id}',
      sourceKind: widget.sourceKind,
      sourceId: widget.sourceId,
      sourceName: widget.sourceName,
      path: entry.path,
      fileName: entry.name,
      kind: entry.kind,
      size: entry.size,
      pickcode: entry.pickcode,
      resolve: () => widget.resolveFile(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _onBack),
        title: Text(
          _current.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.importFolder != null)
            IconButton(
              tooltip: '导入此目录到媒体库',
              icon: const Icon(Icons.library_add_outlined),
              onPressed: _importHere,
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
          _Breadcrumbs(stack: _stack, onTap: _jumpTo),
          const Divider(height: 0.5),
          Expanded(
            child: FutureBuilder<List<RemoteEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(message: '${snap.error}', onRetry: _reload);
                }
                final entries = snap.data ?? const <RemoteEntry>[];
                if (entries.isEmpty) {
                  return const Center(child: Text('此目录为空'));
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 0.5, indent: 56),
                  itemBuilder: (_, i) => _EntryRow(
                    entry: entries[i],
                    onOpenDir: _enter,
                    onPlayAudio: (entry) => _playAudio(entry, entries),
                    onOpenVideo: _openVideo,
                  ),
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
  const _Breadcrumbs({required this.stack, required this.onTap});

  final List<RemoteEntry> stack;
  final void Function(int index) onTap;

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
                  stack[i].name,
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
  const _EntryRow({
    required this.entry,
    required this.onOpenDir,
    required this.onPlayAudio,
    required this.onOpenVideo,
  });

  final RemoteEntry entry;
  final void Function(RemoteEntry) onOpenDir;
  final void Function(RemoteEntry) onPlayAudio;
  final void Function(RemoteEntry) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final iosBlue = CupertinoColors.systemBlue.resolveFrom(context);
    final iosSecondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    if (entry.isFolder) {
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
    return ListTile(
      leading: Icon(_iconFor(entry.kind), color: iosSecondary, size: 34),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: entry.size == null ? null : Text(_fmtBytes(entry.size!)),
      onTap: entry.isAudio
          ? () => onPlayAudio(entry)
          : entry.isVideo
          ? () => onOpenVideo(entry)
          : null,
    );
  }

  IconData _iconFor(RemoteEntryKind kind) => switch (kind) {
    RemoteEntryKind.folder => Icons.folder_rounded,
    RemoteEntryKind.audio => CupertinoIcons.music_note,
    RemoteEntryKind.video => CupertinoIcons.videocam_fill,
    RemoteEntryKind.image => CupertinoIcons.photo_fill,
    RemoteEntryKind.subtitle => Icons.subtitles_outlined,
    RemoteEntryKind.text => CupertinoIcons.doc_text_fill,
    RemoteEntryKind.other => CupertinoIcons.doc_fill,
  };
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
