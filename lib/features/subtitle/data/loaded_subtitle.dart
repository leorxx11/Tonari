import '../../../core/subtitle/subtitle_cue.dart';

class LoadedSubtitle {
  const LoadedSubtitle({
    required this.subtitleId,
    required this.trackId,
    required this.cues,
    required this.timeOffsetMs,
  });

  final String subtitleId;
  final String trackId;
  final List<SubtitleCue> cues;
  final int timeOffsetMs;
}
