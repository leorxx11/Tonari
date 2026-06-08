import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/subtitle/subtitle_parser.dart';

void main() {
  group('SubtitleParser.srt', () {
    test('parses basic two cues', () {
      const src = '''
1
00:00:01,000 --> 00:00:03,500
First line

2
00:00:04,000 --> 00:00:06,000
Second line
spans two rows
''';
      final cues = SubtitleParser.parse(src, 'srt');
      expect(cues.length, 2);
      expect(cues[0].startMs, 1000);
      expect(cues[0].endMs, 3500);
      expect(cues[0].text, 'First line');
      expect(cues[1].text, 'Second line\nspans two rows');
    });

    test('strips html-like tags', () {
      const src = '''
1
00:00:01,000 --> 00:00:02,000
<i>Italic</i> and <b>bold</b>
''';
      final cues = SubtitleParser.parse(src, 'srt');
      expect(cues.single.text, 'Italic and bold');
    });

    test('handles CRLF line endings', () {
      const src = '1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n\r\n';
      final cues = SubtitleParser.parse(src, 'srt');
      expect(cues.single.text, 'Hello');
    });
  });

  group('SubtitleParser.vtt', () {
    test('parses WEBVTT with dot millisecond separator', () {
      const src = '''
WEBVTT

00:00:01.000 --> 00:00:03.500
First line

NOTE this is a note block

00:00:04.000 --> 00:00:06.000 align:center
Second line
''';
      final cues = SubtitleParser.parse(src, 'vtt');
      expect(cues.length, 2);
      expect(cues[0].startMs, 1000);
      expect(cues[1].endMs, 6000);
      expect(cues[1].text, 'Second line');
    });

    test('supports MM:SS.mmm (no hour) variant', () {
      const src = '''
WEBVTT

01:00.000 --> 01:02.500
Short form
''';
      final cues = SubtitleParser.parse(src, 'vtt');
      expect(cues.single.startMs, 60000);
      expect(cues.single.endMs, 62500);
    });
  });

  group('SubtitleParser.lrc', () {
    test('parses time tags and infers end from next start', () {
      const src = '''
[ar:Test]
[ti:Hello]
[00:01.00]First line
[00:03.50]Second line
[00:06.00]Third line
''';
      final cues = SubtitleParser.parse(src, 'lrc');
      expect(cues.length, 3);
      expect(cues[0].startMs, 1000);
      expect(cues[0].endMs, 3500);
      expect(cues[1].startMs, 3500);
      expect(cues[1].endMs, 6000);
      expect(cues[2].startMs, 6000);
      expect(cues[2].endMs, 11000);
    });

    test('expands multi-tag line into multiple cues', () {
      const src = '[00:01.00][00:05.00]Chorus\n[00:03.00]Verse';
      final cues = SubtitleParser.parse(src, 'lrc');
      expect(cues.length, 3);
      expect(cues.map((c) => c.startMs).toList(), [1000, 3000, 5000]);
      expect(cues[0].text, 'Chorus');
      expect(cues[1].text, 'Verse');
      expect(cues[2].text, 'Chorus');
    });

    test('accepts millisecond precision (3-digit) fraction', () {
      const src = '[00:01.234]Hi';
      final cues = SubtitleParser.parse(src, 'lrc');
      expect(cues.single.startMs, 1234);
    });
  });

  test('throws on unsupported format', () {
    expect(
      () => SubtitleParser.parse('', 'ass'),
      throwsA(isA<SubtitleParseException>()),
    );
  });
}
