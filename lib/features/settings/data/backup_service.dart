import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

/// [done] and [total] are bytes for file copies, 0/1 for the small stages.
typedef BackupProgress = void Function(String stage, int done, int total);

/// Documents subdirectories a backup can carry. Everything else the app keeps
/// in Documents is either the database itself or disposable.
enum BackupDir {
  images('images', '图片'),
  videoCovers('video_covers', '视频封面');

  const BackupDir(this.dirName, this.label);

  final String dirName;
  final String label;
}

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.dirs,
    required this.includesSecrets,
  });

  final int formatVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final Set<BackupDir> dirs;
  final bool includesSecrets;

  static const currentFormat = 2;

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'dirs': [for (final d in dirs) d.name],
    'includesSecrets': includesSecrets,
  };

  static BackupManifest fromJson(Map<String, Object?> json) {
    final formatVersion = json['formatVersion'] as int;
    return BackupManifest(
      formatVersion: formatVersion,
      schemaVersion: json['schemaVersion'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dirs: formatVersion < 2
          ? {if (json['includesImages'] == true) BackupDir.images}
          : {
              for (final name in json['dirs'] as List)
                ?BackupDir.values.asNameMap()[name],
            },
      includesSecrets: json['includesSecrets'] as bool,
    );
  }
}

/// Typed SharedPreferences dump. Types are tagged so restore writes each key
/// back with the same setter ('s'tring, 'b'ool, 'i'nt, 'd'ouble, string 'l'ist).
Map<String, Object?> encodePrefs(SharedPreferences prefs) {
  final out = <String, Object?>{};
  for (final key in prefs.getKeys()) {
    final v = prefs.get(key);
    out[key] = switch (v) {
      String s => {'t': 's', 'v': s},
      bool b => {'t': 'b', 'v': b},
      int i => {'t': 'i', 'v': i},
      double d => {'t': 'd', 'v': d},
      List<Object?> l => {'t': 'l', 'v': l.cast<String>()},
      _ => null,
    };
  }
  out.removeWhere((_, v) => v == null);
  return out;
}

Future<void> applyPrefs(
  SharedPreferences prefs,
  Map<String, Object?> encoded,
) async {
  for (final e in encoded.entries) {
    final m = e.value as Map<String, Object?>;
    final v = m['v'];
    switch (m['t']) {
      case 's':
        await prefs.setString(e.key, v as String);
      case 'b':
        await prefs.setBool(e.key, v as bool);
      case 'i':
        await prefs.setInt(e.key, v as int);
      case 'd':
        await prefs.setDouble(e.key, (v as num).toDouble());
      case 'l':
        await prefs.setStringList(e.key, (v as List).cast<String>());
    }
  }
}

/// Must mirror the IOSOptions used by the three key stores
/// (p115_cookie_store / webdav_password_store / provider_key_store) so
/// readAll sees their entries.
const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class BackupService {
  BackupService(this._db, {Future<Map<String, String>> Function()? readSecrets})
    : _readSecrets = readSecrets ?? _secureStorage.readAll;

  final TonariDatabase _db;
  final Future<Map<String, String>> Function() _readSecrets;

  static const manifestName = 'tonari_backup.json';
  static const _dbSnapshotName = 'tonari.sqlite';
  static const _pendingDirName = 'restore_pending';

  static Future<Directory> _docsDir() => getApplicationDocumentsDirectory();

  Future<int> dirSizeBytes(BackupDir dir) async {
    final docs = await _docsDir();
    final files = await _filesUnder(Directory(p.join(docs.path, dir.dirName)));
    return files.fold<int>(0, (sum, f) => sum + f.lengthSync());
  }

  /// Writes `Tonari备份_.../` under [targetDir] (an already security-scoped
  /// writable path). The manifest is written LAST as the completion marker,
  /// so a half-copied folder is never mistaken for a valid backup.
  Future<String> export({
    required String targetDir,
    required Set<BackupDir> dirs,
    BackupProgress? onProgress,
  }) async {
    final docs = await _docsDir();
    final now = DateTime.now();
    final stamp =
        '${now.year}-${_two(now.month)}-${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}';
    final out = Directory(p.join(targetDir, 'Tonari备份_$stamp'));
    out.createSync(recursive: true);

    onProgress?.call('导出数据库', 0, 1);
    final tmpDb = File(p.join(docs.path, 'backup_snapshot.sqlite'));
    if (tmpDb.existsSync()) tmpDb.deleteSync();
    await _db.customStatement('VACUUM INTO ?', [tmpDb.path]);
    tmpDb.copySync(p.join(out.path, _dbSnapshotName));
    tmpDb.deleteSync();
    onProgress?.call('导出数据库', 1, 1);

    for (final dir in dirs) {
      await _copyTree(
        Directory(p.join(docs.path, dir.dirName)),
        Directory(p.join(out.path, dir.dirName)),
        (done, total) => onProgress?.call('导出${dir.label}', done, total),
      );
    }

    onProgress?.call('导出设置', 0, 1);
    final prefs = await SharedPreferences.getInstance();
    File(
      p.join(out.path, 'prefs.json'),
    ).writeAsStringSync(jsonEncode(encodePrefs(prefs)));

    final secrets = await _readSecrets();
    File(
      p.join(out.path, 'secrets.json'),
    ).writeAsStringSync(jsonEncode(secrets));

    final manifest = BackupManifest(
      formatVersion: BackupManifest.currentFormat,
      schemaVersion: _db.schemaVersion,
      createdAt: now,
      dirs: dirs,
      includesSecrets: true,
    );
    File(
      p.join(out.path, manifestName),
    ).writeAsStringSync(jsonEncode(manifest.toJson()));
    onProgress?.call('完成', 1, 1);
    return out.path;
  }

  /// Reads and validates the manifest of a picked backup folder.
  /// Throws [BackupIncompatible] when the backup is newer than this app.
  Future<BackupManifest> inspect(String backupDir) async {
    final f = File(p.join(backupDir, manifestName));
    if (!f.existsSync()) {
      throw const BackupInvalid('不是有效的 Tonari 备份文件夹（缺少 manifest）');
    }
    final manifest = BackupManifest.fromJson(
      jsonDecode(f.readAsStringSync()) as Map<String, Object?>,
    );
    if (manifest.formatVersion > BackupManifest.currentFormat ||
        manifest.schemaVersion > _db.schemaVersion) {
      throw const BackupIncompatible('备份来自更新版本的 Tonari，请先升级 App 再恢复');
    }
    return manifest;
  }

  /// Copies the backup into Documents/restore_pending; [applyPendingRestore]
  /// swaps it in on next launch, before the database opens.
  Future<void> stageRestore(
    String backupDir, {
    BackupProgress? onProgress,
  }) async {
    await inspect(backupDir);
    final docs = await _docsDir();
    final pending = Directory(p.join(docs.path, _pendingDirName));
    if (pending.existsSync()) pending.deleteSync(recursive: true);
    // Manifest last: it is what marks the staged copy as complete.
    await _copyTree(
      Directory(backupDir),
      pending,
      (done, total) => onProgress?.call('复制备份', done, total),
      exclude: manifestName,
    );
    File(
      p.join(backupDir, manifestName),
    ).copySync(p.join(pending.path, manifestName));
  }

  static Future<void> applyPendingRestore() async {
    final docs = await _docsDir();
    await applyPendingRestoreIn(
      docs,
      applySecrets: (secrets) async {
        for (final e in secrets.entries) {
          await _secureStorage.write(key: e.key, value: e.value);
        }
      },
    );
  }

  /// Testable core of [applyPendingRestore]: everything is path-based except
  /// the Keychain writes, injected via [applySecrets].
  static Future<void> applyPendingRestoreIn(
    Directory docs, {
    required Future<void> Function(Map<String, String>) applySecrets,
  }) async {
    final pending = Directory(p.join(docs.path, _pendingDirName));
    final manifestFile = File(p.join(pending.path, manifestName));
    if (!manifestFile.existsSync()) return;

    final prefsFile = File(p.join(pending.path, 'prefs.json'));
    if (prefsFile.existsSync()) {
      final prefs = await SharedPreferences.getInstance();
      await applyPrefs(
        prefs,
        jsonDecode(prefsFile.readAsStringSync()) as Map<String, Object?>,
      );
    }

    final secretsFile = File(p.join(pending.path, 'secrets.json'));
    if (secretsFile.existsSync()) {
      final raw = jsonDecode(secretsFile.readAsStringSync());
      await applySecrets(Map<String, String>.from(raw as Map));
    }

    // A directory the backup left out keeps its live copy.
    for (final dir in BackupDir.values) {
      final staged = Directory(p.join(pending.path, dir.dirName));
      if (!staged.existsSync()) continue;
      final live = Directory(p.join(docs.path, dir.dirName));
      if (live.existsSync()) live.deleteSync(recursive: true);
      staged.renameSync(live.path);
    }

    final pendingDb = File(p.join(pending.path, _dbSnapshotName));
    if (pendingDb.existsSync()) {
      for (final suffix in const ['', '-wal', '-shm']) {
        final f = File(p.join(docs.path, '$_dbSnapshotName$suffix'));
        if (f.existsSync()) f.deleteSync();
      }
      pendingDb.renameSync(p.join(docs.path, _dbSnapshotName));
    }

    pending.deleteSync(recursive: true);
  }

  static Future<List<File>> _filesUnder(Directory dir) async {
    if (!dir.existsSync()) return const [];
    return [
      await for (final f in dir.list(recursive: true, followLinks: false))
        if (f is File) f,
    ];
  }

  /// Async copies so big image caches don't freeze the progress dialog.
  static Future<void> _copyTree(
    Directory from,
    Directory to,
    void Function(int doneBytes, int totalBytes) onProgress, {
    String? exclude,
  }) async {
    final files = [
      for (final f in await _filesUnder(from))
        if (p.relative(f.path, from: from.path) != exclude) f,
    ];
    final total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    var done = 0;
    onProgress(0, total);
    for (final f in files) {
      final rel = p.relative(f.path, from: from.path);
      final target = File(p.join(to.path, rel));
      await target.parent.create(recursive: true);
      final length = f.lengthSync();
      await f.copy(target.path);
      done += length;
      onProgress(done, total);
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class BackupInvalid implements Exception {
  const BackupInvalid(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupIncompatible implements Exception {
  const BackupIncompatible(this.message);
  final String message;
  @override
  String toString() => message;
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
