import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/features/settings/data/backup_controller.dart';
import 'package:tonari/features/settings/data/backup_service.dart';

class _FakeDocs extends PathProviderPlatform {
  _FakeDocs(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late TonariDatabase db;
  late ProviderContainer container;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tonari_backup_ctrl');
    PathProviderPlatform.instance = _FakeDocs(
      (Directory(p.join(tmp.path, 'docs'))..createSync()).path,
    );
    SharedPreferences.setMockInitialValues({});
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupServiceProvider.overrideWithValue(
          BackupService(db, readSecrets: () async => {}),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('a finished export posts an info message and goes idle', () async {
    final target = Directory(p.join(tmp.path, 'out'))..createSync();
    final controller = container.read(backupControllerProvider.notifier);

    final running = controller.export(target.path, const {});
    expect(container.read(backupControllerProvider), isNotNull);
    await running;

    expect(container.read(backupControllerProvider), isNull);
    final events = await db.select(db.appEvents).get();
    expect(events.single.severity, 'info');
    expect(events.single.title, '备份完成');
    expect(
      target.listSync().single.path,
      p.join(target.path, events.single.detail),
    );
  });

  test('a failed export posts an error message', () async {
    final missing = p.join(tmp.path, 'file-not-dir');
    File(missing).writeAsStringSync('');

    await container
        .read(backupControllerProvider.notifier)
        .export(missing, const {});

    expect(container.read(backupControllerProvider), isNull);
    final events = await db.select(db.appEvents).get();
    expect(events.single.severity, 'error');
    expect(events.single.title, '备份失败');
  });
}
