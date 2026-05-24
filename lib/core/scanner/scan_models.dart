class ScanResult {
  const ScanResult({
    required this.rootPath,
    required this.works,
    required this.filesScanned,
    required this.unrecognizedDirs,
    this.errors = const [],
  });

  final String rootPath;
  final List<DetectedWork> works;
  final int filesScanned;

  /// Top-level subdirectories under [rootPath] that had no RJ id (neither
  /// in their own name nor in any immediate child directory).
  final List<String> unrecognizedDirs;

  final List<String> errors;
}

class DetectedWork {
  const DetectedWork({
    required this.productId,
    required this.rootPath,
    required this.audios,
    required this.images,
    required this.subtitles,
    required this.textNotes,
  });

  final String productId;
  final String rootPath;
  final List<DetectedAudio> audios;
  final List<DetectedImage> images;
  final List<DetectedSubtitle> subtitles;
  final List<DetectedFile> textNotes;
}

class DetectedAudio {
  const DetectedAudio({
    required this.path,
    required this.fileName,
    required this.format,
    required this.sizeBytes,
    required this.parentDirName,
    this.categoryHint,
  });

  final String path;
  final String fileName;
  final String format;
  final int sizeBytes;
  final String parentDirName;

  /// 'main' / 'free' / null based on keyword inference.
  final String? categoryHint;
}

class DetectedImage {
  const DetectedImage({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
}

class DetectedSubtitle {
  const DetectedSubtitle({
    required this.path,
    required this.fileName,
    required this.format,
  });

  final String path;
  final String fileName;
  final String format;
}

class DetectedFile {
  const DetectedFile({required this.path, required this.fileName});
  final String path;
  final String fileName;
}
