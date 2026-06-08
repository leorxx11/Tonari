import 'package:flutter/services.dart';

class FolderBookmark {
  FolderBookmark._();

  static const _channel = MethodChannel('tonari/folder_bookmark');

  static Future<String> create(String url) async {
    final result = await _channel.invokeMethod<String>('create', {'url': url});
    return result!;
  }

  static Future<BookmarkResolution> resolve(String bookmark) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>('resolve', {
      'bookmark': bookmark,
    });
    final map = Map<String, Object?>.from(raw!);
    return BookmarkResolution(
      url: map['url'] as String,
      isStale: map['isStale'] as bool,
    );
  }

  static Future<void> release(String url) async {
    await _channel.invokeMethod('release', {'url': url});
  }
}

class BookmarkResolution {
  const BookmarkResolution({required this.url, required this.isStale});
  final String url;
  final bool isStale;
}
