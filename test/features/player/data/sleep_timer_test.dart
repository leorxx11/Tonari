import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/features/player/data/playback_controller.dart';
import 'package:tonari/features/player/data/sleep_timer.dart';
import 'package:tonari/features/video/data/video_controller.dart';
import 'package:video_player/video_player.dart';

class _StubAudioPlayer implements AudioPlayer {
  double _volume = 1;
  bool playingValue = true;

  @override
  bool get playing => playingValue;

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async => _volume = volume;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePlaybackController extends PlaybackController {
  final stub = _StubAudioPlayer();
  int pauseCount = 0;

  @override
  AudioPlayer get player => stub;

  @override
  PlaybackState build() => PlaybackState.empty;

  @override
  Future<void> pause() async => pauseCount++;
}

class _FakeVideoController extends VideoController {
  int pauseCount = 0;

  /// Never initialized, so setVolume just tracks value — enough to observe
  /// the fade target.
  VideoPlayerController? stub;

  @override
  VideoPlaybackState build() => VideoPlaybackState(controller: stub);

  @override
  Future<void> pause() async => pauseCount++;
}

void main() {
  late _FakePlaybackController playback;
  late _FakeVideoController video;
  late ProviderContainer container;

  Future<void> init({bool finishTrack = false}) async {
    SharedPreferences.setMockInitialValues({
      if (finishTrack) 'player.sleepFinishCurrentTrack': true,
    });
    final prefs = await SharedPreferences.getInstance();
    playback = _FakePlaybackController();
    video = _FakeVideoController();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playbackControllerProvider.overrideWith(() => playback),
        videoControllerProvider.overrideWith(() => video),
      ],
    );
  }

  tearDown(() => container.dispose());

  SleepTimerController notifier() =>
      container.read(sleepTimerProvider.notifier);
  SleepTimerState state() => container.read(sleepTimerProvider);

  testWidgets('countdown ticks down, fades and pauses at zero', (tester) async {
    await init();
    notifier().start(const Duration(seconds: 3));
    expect(state().remaining, const Duration(seconds: 3));

    await tester.pump(const Duration(seconds: 1));
    expect(state().remaining, const Duration(seconds: 2));
    expect(playback.stub.volume, closeTo(0.2, 0.001));

    await tester.pump(const Duration(seconds: 2));
    expect(playback.pauseCount, 1);
    expect(video.pauseCount, 0);
    expect(state().isActive, false);
    expect(playback.stub.volume, 1.0);
  });

  testWidgets('cancel stops ticking and restores volume', (tester) async {
    await init();
    notifier().start(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(playback.stub.volume, lessThan(1.0));

    notifier().cancel();
    expect(state().isActive, false);
    expect(playback.stub.volume, 1.0);

    await tester.pump(const Duration(seconds: 10));
    expect(playback.pauseCount, 0);
  });

  testWidgets('stop-after-tracks replaces countdown and decrements per track', (
    tester,
  ) async {
    await init();
    notifier().start(const Duration(minutes: 30));
    notifier().stopAfterTracks(3);
    expect(state().remaining, isNull);
    expect(state().remainingTracks, 3);

    await tester.pump(const Duration(seconds: 5));
    expect(state().remainingTracks, 3);

    expect(notifier().onTrackCompleted(), false);
    expect(state().remainingTracks, 2);
    expect(notifier().onTrackCompleted(), false);
    expect(notifier().onTrackCompleted(), true);
    expect(state().isActive, false);
    expect(notifier().onTrackCompleted(), false);
  });

  testWidgets('time-up with finish-track on waits for track end, no fade', (
    tester,
  ) async {
    await init(finishTrack: true);
    notifier().start(const Duration(seconds: 2));

    await tester.pump(const Duration(seconds: 1));
    expect(playback.stub.volume, 1.0);

    await tester.pump(const Duration(seconds: 1));
    expect(state().waitingTrackEnd, true);
    expect(state().isActive, true);
    expect(playback.pauseCount, 0);

    expect(notifier().onTrackCompleted(), true);
    expect(state().isActive, false);
  });

  testWidgets('time-up with finish-track on but nothing playing stops now', (
    tester,
  ) async {
    await init(finishTrack: true);
    playback.stub.playingValue = false;
    notifier().start(const Duration(seconds: 1));

    await tester.pump(const Duration(seconds: 1));
    expect(state().isActive, false);
    expect(playback.pauseCount, 1);
  });

  testWidgets('fade targets the video player when a video is active', (
    tester,
  ) async {
    await init();
    final vpc = VideoPlayerController.networkUrl(
      Uri.parse('https://example.com/v.mp4'),
    );
    video.stub = vpc;

    notifier().start(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(vpc.value.volume, closeTo(0.2, 0.001));
    expect(playback.stub.volume, 1.0);

    notifier().cancel();
    expect(vpc.value.volume, 1.0);
  });
}
