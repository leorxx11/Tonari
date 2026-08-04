import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/diagnostics/diagnostic_log.dart';
import 'core/files/local_image_path.dart';
import 'core/prefs/shared_prefs_provider.dart';
import 'features/settings/data/backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route video_player through FFmpeg/libmpv so codecs AVPlayer can't decode
  // (10-bit H.264, hev1 HEVC, etc.) still play. iOS tries VideoToolbox first.
  fvp.registerWith();

  // Must run before anything opens the database or resolves image paths.
  await BackupService.applyPendingRestore();

  await LocalImagePath.init();
  final prefs = await SharedPreferences.getInstance();
  await DiagnosticLog.init(prefs);

  final session = await AudioSession.instance;
  await session.configure(
    const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TonariApp(),
    ),
  );
}
