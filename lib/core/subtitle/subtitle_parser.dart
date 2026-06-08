import 'subtitle_cue.dart';

class SubtitleParseException implements Exception {
  SubtitleParseException(this.message);
  final String message;

  @override
  String toString() => 'SubtitleParseException: $message';
}

class SubtitleParser {
  SubtitleParser._();

  /// Parses [content] of the given [format] ('srt' / 'vtt' / 'lrc').
  /// Returns cues in chronological order. Unparseable cues are skipped
  /// rather than aborting the whole file.
  static List<SubtitleCue> parse(String content, String format) {
    switch (format.toLowerCase()) {
      case 'srt':
        return _parseSrtOrVtt(content);
      case 'vtt':
        return _parseSrtOrVtt(content);
      case 'lrc':
        return _parseLrc(content);
      default:
        throw SubtitleParseException('Unsupported subtitle format: $format');
    }
  }

  // (HH:)? MM:SS [,.] mmm  -->  (HH:)? MM:SS [,.] mmm
  static final _timeLineRegex = RegExp(
    r'(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})[,.](\d{1,3})\s*-->\s*'
    r'(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})[,.](\d{1,3})',
  );

  static List<SubtitleCue> _parseSrtOrVtt(String content) {
    final lines = _splitLines(content);
    final result = <SubtitleCue>[];
    var i = 0;
    while (i < lines.length) {
      final m = _timeLineRegex.firstMatch(lines[i]);
      if (m == null) {
        i++;
        continue;
      }
      final startMs = _hmsToMs(
        m.group(1),
        m.group(2)!,
        m.group(3)!,
        m.group(4)!,
      );
      final endMs = _hmsToMs(m.group(5), m.group(6)!, m.group(7)!, m.group(8)!);

      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        textLines.add(lines[i]);
        i++;
      }
      final text = _cleanText(textLines.join('\n'));
      if (text.isNotEmpty && endMs > startMs) {
        result.add(SubtitleCue(startMs: startMs, endMs: endMs, text: text));
      }
    }
    return result;
  }

  static int _hmsToMs(String? h, String mm, String ss, String mmm) {
    final hh = h == null ? 0 : int.parse(h);
    final minutes = int.parse(mm);
    final seconds = int.parse(ss);
    final padded = mmm.length >= 3 ? mmm.substring(0, 3) : mmm.padRight(3, '0');
    final ms = int.parse(padded);
    return ((hh * 60 + minutes) * 60 + seconds) * 1000 + ms;
  }

  static final _htmlTag = RegExp(r'<[^>]+>');
  static final _assStyleTag = RegExp(r'\{[^}]+\}');

  static String _cleanText(String text) {
    var t = text.replaceAll(_htmlTag, '').replaceAll(_assStyleTag, '');
    return t.trim();
  }

  static final _lrcTimeTag = RegExp(
    r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]',
  );
  static final _lrcMetaTag = RegExp(
    r'^\[(ar|ti|al|au|by|length|offset|re|ve|hash)\s*:',
    caseSensitive: false,
  );

  static List<SubtitleCue> _parseLrc(String content) {
    final lines = _splitLines(content);
    final rows = <_LrcRow>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      if (_lrcMetaTag.hasMatch(line.trim())) continue;
      final matches = _lrcTimeTag.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.substring(matches.last.end).trim();
      for (final m in matches) {
        final minutes = int.parse(m.group(1)!);
        final seconds = int.parse(m.group(2)!);
        final frac = m.group(3);
        final ms = frac == null
            ? 0
            : frac.length == 2
            ? int.parse(frac) * 10
            : int.parse(frac.padRight(3, '0').substring(0, 3));
        rows.add(
          _LrcRow(startMs: (minutes * 60 + seconds) * 1000 + ms, text: text),
        );
      }
    }
    rows.sort((a, b) => a.startMs.compareTo(b.startMs));

    final result = <SubtitleCue>[];
    for (var i = 0; i < rows.length; i++) {
      final cur = rows[i];
      if (cur.text.isEmpty) continue;
      final endMs = i + 1 < rows.length
          ? rows[i + 1].startMs
          : cur.startMs + 5000;
      if (endMs <= cur.startMs) continue;
      result.add(
        SubtitleCue(startMs: cur.startMs, endMs: endMs, text: cur.text),
      );
    }
    return result;
  }

  static List<String> _splitLines(String content) {
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }
}

class _LrcRow {
  const _LrcRow({required this.startMs, required this.text});
  final int startMs;
  final String text;
}
