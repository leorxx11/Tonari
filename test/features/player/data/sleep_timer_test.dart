import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tonari/features/player/data/playback_controller.dart';
import 'package:tonari/features/player/data/sleep_timer.dart';
import 'package:tonari/features/video/data/video_controller.dart';

class _StubAudioPlayer implements AudioPlayer {
  double _volume = 1;

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

  @override
  VideoPlaybackState build() => const VideoPlaybackState();

  @override
  Future<void> pause() async => pauseCount++;
}

void main() {
  late _FakePlaybackController playback;
  late _FakeVideoController video;
  late ProviderContainer container;

  setUp(() {
    playback = _FakePlaybackController();
    video = _FakeVideoController();
    container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWith(() => playback),
        videoControllerProvider.overrideWith(() => video),
      ],
    );
  });

  tearDown(() => container.dispose());

  SleepTimerController notifier() =>
      container.read(sleepTimerProvider.notifier);
  SleepTimerState state() => container.read(sleepTimerProvider);

  testWidgets('countdown ticks down, fades and pauses at zero', (tester) async {
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
    notifier().start(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(playback.stub.volume, lessThan(1.0));

    notifier().cancel();
    expect(state().isActive, false);
    expect(playback.stub.volume, 1.0);

    await tester.pump(const Duration(seconds: 10));
    expect(playback.pauseCount, 0);
  });

  testWidgets('stop-after-track replaces countdown and is consumed once', (
    tester,
  ) async {
    notifier().start(const Duration(minutes: 30));
    notifier().enableStopAfterTrack();
    expect(state().remaining, isNull);
    expect(state().stopAfterTrack, true);

    await tester.pump(const Duration(seconds: 5));
    expect(state().stopAfterTrack, true);

    expect(notifier().consumeStopAfterTrack(), true);
    expect(state().isActive, false);
    expect(notifier().consumeStopAfterTrack(), false);
  });
}
