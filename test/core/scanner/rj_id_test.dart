import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/scanner/rj_id.dart';

void main() {
  group('RjId.extract', () {
    test('extracts plain 8-digit id', () {
      expect(RjId.extract('RJ01560714'), 'RJ01560714');
    });

    test('extracts 6-digit id', () {
      expect(RjId.extract('RJ123456'), 'RJ123456');
    });

    test('extracts id surrounded by other text', () {
      expect(
        RjId.extract('[social-group] RJ789012 作品タイトル'),
        'RJ789012',
      );
    });

    test('uppercases lowercase rj prefix', () {
      expect(RjId.extract('rj234567'), 'RJ234567');
    });

    test('returns null for fewer than 6 digits', () {
      expect(RjId.extract('RJ12345'), isNull);
    });

    test('returns null when no RJ pattern', () {
      expect(RjId.extract('just_some_folder'), isNull);
    });

    test('first match wins when multiple RJs present', () {
      expect(RjId.extract('RJ111111_and_RJ222222'), 'RJ111111');
    });
  });

  group('RjId.contains', () {
    test('true when present', () {
      expect(RjId.contains('foo RJ123456 bar'), isTrue);
    });
    test('false when absent', () {
      expect(RjId.contains('hello world'), isFalse);
    });
  });
}
