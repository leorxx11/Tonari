import 'dart:async';

import '../../../core/scanner/file_classifier.dart';

enum RemoteEntryKind { folder, audio, video, image, subtitle, text, other }

enum RemoteSourceKind { local, webdav, p115 }

class RemoteEntry {
  const RemoteEntry({
    required this.id,
    required this.path,
    required this.name,
    required this.kind,
    required this.sourceId,
    this.size,
    this.pickcode,
  });

  final String id;
  final String path;
  final String name;
  final RemoteEntryKind kind;
  final int? size;
  final String? pickcode;
  final String sourceId;

  bool get isFolder => kind == RemoteEntryKind.folder;
  bool get isAudio => kind == RemoteEntryKind.audio;
  bool get isVideo => kind == RemoteEntryKind.video;
}

class ResolvedMediaUrl {
  const ResolvedMediaUrl({required this.url, this.headers, this.release});

  final Uri url;
  final Map<String, String>? headers;
  final FutureOr<void> Function()? release;
}

typedef PlayableResolver = Future<ResolvedMediaUrl> Function();

class PlayableItem {
  const PlayableItem({
    required this.id,
    required this.sourceKind,
    required this.sourceId,
    required this.sourceName,
    required this.path,
    required this.fileName,
    required this.kind,
    required this.resolve,
    this.size,
    this.pickcode,
    String? title,
  }) : title = title ?? fileName;

  final String id;
  final RemoteSourceKind sourceKind;
  final String sourceId;
  final String sourceName;
  final String path;
  final String fileName;
  final String title;
  final RemoteEntryKind kind;
  final int? size;
  final String? pickcode;
  final PlayableResolver resolve;

  bool get isAudio => kind == RemoteEntryKind.audio;
  bool get isVideo => kind == RemoteEntryKind.video;
}

class BrowseQueue {
  const BrowseQueue({required this.items, required this.currentIndex});

  final List<PlayableItem> items;
  final int currentIndex;

  PlayableItem? get currentItem {
    if (currentIndex < 0 || currentIndex >= items.length) return null;
    return items[currentIndex];
  }

  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex >= 0 && currentIndex + 1 < items.length;
}

RemoteEntryKind remoteEntryKindFromFileKind(FileKind kind) {
  return switch (kind) {
    FileKind.audio => RemoteEntryKind.audio,
    FileKind.video => RemoteEntryKind.video,
    FileKind.image => RemoteEntryKind.image,
    FileKind.subtitle => RemoteEntryKind.subtitle,
    FileKind.text => RemoteEntryKind.text,
    FileKind.other => RemoteEntryKind.other,
  };
}
