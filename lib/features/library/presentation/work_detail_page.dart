import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../player/presentation/player_page.dart';
import '../data/works_providers.dart';

class WorkDetailPage extends ConsumerWidget {
  const WorkDetailPage({super.key, required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _WorkDetailView(work: work);
  }
}

class _WorkDetailView extends ConsumerStatefulWidget {
  const _WorkDetailView({required this.work});

  final Work work;

  @override
  ConsumerState<_WorkDetailView> createState() => _WorkDetailViewState();
}

class _WorkDetailViewState extends ConsumerState<_WorkDetailView> {
  String? _selectedFolderPath;

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksByWorkProvider(widget.work.productId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.work.title)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _WorkHeader(work: widget.work)),
          tracksAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('加载失败：$e')),
            ),
            data: (tracks) => tracks.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('没有音轨')),
                  )
                : _TrackDirectoryView(
                    work: widget.work,
                    folders: _AudioFolder.fromTracks(widget.work, tracks),
                    selectedFolderPath: _selectedFolderPath,
                    onFolderSelected: (path) {
                      setState(() => _selectedFolderPath = path);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrackDirectoryView extends StatelessWidget {
  const _TrackDirectoryView({
    required this.work,
    required this.folders,
    required this.selectedFolderPath,
    required this.onFolderSelected,
  });

  final Work work;
  final List<_AudioFolder> folders;
  final String? selectedFolderPath;
  final ValueChanged<String> onFolderSelected;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedFolder();
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _FolderSelector(
            folders: folders,
            selectedPath: selected.path,
            onSelected: onFolderSelected,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('章节', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        SliverList.builder(
          itemCount: selected.tracks.length,
          itemBuilder: (context, index) {
            return _TrackTile(
              track: selected.tracks[index],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerPage(
                      work: work,
                      tracks: selected.tracks,
                      initialIndex: index,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  _AudioFolder _selectedFolder() {
    final target = selectedFolderPath;
    if (target != null) {
      for (final folder in folders) {
        if (folder.path == target) return folder;
      }
    }
    return _bestFolder(folders);
  }
}

class _FolderSelector extends StatelessWidget {
  const _FolderSelector({
    required this.folders,
    required this.selectedPath,
    required this.onSelected,
  });

  final List<_AudioFolder> folders;
  final String selectedPath;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目录', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: folders.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ChoiceChip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      folder.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  selected: folder.path == selectedPath,
                  onSelected: (_) => onSelected(folder.path),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkHeader extends StatelessWidget {
  const _WorkHeader({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.album_outlined,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(work.productId, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(work.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  work.localFolderPath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alternates =
        (jsonDecode(track.alternateQualityPathsJson) as Map<String, dynamic>)
            .cast<String, String>();
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.music_note_outlined),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${track.parentDirName} / ${track.fileName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FormatChip(label: '主音质 ${track.fileFormat.toUpperCase()}'),
              for (final format in alternates.keys)
                _FormatChip(label: '备用 ${format.toUpperCase()}'),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: track.categoryHint == null
          ? null
          : Text(
              track.categoryHint!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _AudioFolder {
  const _AudioFolder({
    required this.path,
    required this.label,
    required this.tracks,
  });

  final String path;
  final String label;
  final List<Track> tracks;

  int get qualityRank {
    var best = _formatRank(tracks.first.fileFormat);
    for (final track in tracks.skip(1)) {
      final rank = _formatRank(track.fileFormat);
      if (rank < best) best = rank;
    }
    return best;
  }

  bool get hasEffectSound => _hasEffectSound(path);

  static List<_AudioFolder> fromTracks(Work work, List<Track> tracks) {
    final grouped = <String, List<Track>>{};
    for (final track in tracks) {
      final path = _relativeDirectory(work, track);
      grouped.putIfAbsent(path, () => []).add(track);
    }

    final folders = [
      for (final entry in grouped.entries)
        _AudioFolder(
          path: entry.key,
          label: entry.key == '.' ? work.productId : entry.key,
          tracks: entry.value,
        ),
    ];
    folders.sort((a, b) => a.path.compareTo(b.path));
    return folders;
  }
}

_AudioFolder _bestFolder(List<_AudioFolder> folders) {
  final sorted = [...folders]..sort(_folderSort);
  return sorted.first;
}

int _folderSort(_AudioFolder a, _AudioFolder b) {
  final effect = _boolScore(
    b.hasEffectSound,
  ).compareTo(_boolScore(a.hasEffectSound));
  if (effect != 0) return effect;

  final quality = a.qualityRank.compareTo(b.qualityRank);
  if (quality != 0) return quality;

  return a.path.compareTo(b.path);
}

int _boolScore(bool value) => value ? 1 : 0;

String _relativeDirectory(Work work, Track track) {
  final root = _trimTrailingSlash(work.localFolderPath);
  final dir = track.filePath.substring(0, track.filePath.lastIndexOf('/'));
  if (dir == root) return '.';
  if (dir.startsWith('$root/')) return dir.substring(root.length + 1);
  return track.parentDirName;
}

String _trimTrailingSlash(String value) {
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

int _formatRank(String format) {
  return switch (format.toLowerCase()) {
    'flac' => 0,
    'wav' => 1,
    'mp3' => 2,
    'opus' => 3,
    'aac' => 4,
    'm4a' => 5,
    'ogg' => 6,
    _ => 7,
  };
}

bool _hasEffectSound(String path) {
  final text = path.toLowerCase();
  if (text.contains('効果音なし') ||
      text.contains('効果音無し') ||
      text.contains('効果音無') ||
      text.contains('効果音抜き') ||
      text.contains('效果音なし') ||
      text.contains('音效なし') ||
      text.contains('seなし') ||
      text.contains('se無し') ||
      text.contains('se無') ||
      text.contains('no se') ||
      text.contains('without se') ||
      text.contains('without effect')) {
    return false;
  }
  return text.contains('効果音') ||
      text.contains('效果音') ||
      text.contains('音效') ||
      text.contains('sound effect') ||
      text.contains('sfx') ||
      RegExp(r'(^|[/_\-\s])se($|[/_\-\s])').hasMatch(text);
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: theme.colorScheme.secondaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
