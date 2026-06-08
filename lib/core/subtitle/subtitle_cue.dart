class SubtitleCue {
  const SubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;

  Map<String, dynamic> toJson() => {'s': startMs, 'e': endMs, 't': text};

  factory SubtitleCue.fromJson(Map<String, dynamic> json) => SubtitleCue(
    startMs: json['s'] as int,
    endMs: json['e'] as int,
    text: json['t'] as String,
  );
}
