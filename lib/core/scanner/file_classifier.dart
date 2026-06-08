enum FileKind { audio, video, image, subtitle, text, other }

class FileClassifier {
  FileClassifier._();

  static const _audioExts = {
    '.wav',
    '.mp3',
    '.flac',
    '.m4a',
    '.ogg',
    '.opus',
    '.aac',
  };
  static const _videoExts = {'.mp4', '.mkv', '.mov', '.m4v', '.webm', '.ts'};
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'};
  static const _subtitleExts = {'.srt', '.lrc', '.vtt', '.ass', '.ssa'};
  static const _textExts = {'.txt', '.md', '.html', '.htm'};

  static FileKind classify(String fileName) {
    final ext = extOf(fileName);
    if (_audioExts.contains(ext)) return FileKind.audio;
    if (_videoExts.contains(ext)) return FileKind.video;
    if (_imageExts.contains(ext)) return FileKind.image;
    if (_subtitleExts.contains(ext)) return FileKind.subtitle;
    if (_textExts.contains(ext)) return FileKind.text;
    return FileKind.other;
  }

  /// Returns the lowercased extension including the dot (e.g. ".mp3"),
  /// or "" if the file has no extension.
  static String extOf(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i < 0) return '';
    return fileName.substring(i).toLowerCase();
  }
}
