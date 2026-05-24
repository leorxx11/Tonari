final _rjPattern = RegExp(r'RJ(\d{6,8})', caseSensitive: false);

class RjId {
  RjId._();

  /// Extracts the first RJ id from [text]. Returns canonical uppercase form
  /// (e.g. "RJ01560714"), or null if no RJ-id pattern present.
  static String? extract(String text) {
    final match = _rjPattern.firstMatch(text);
    if (match == null) return null;
    return 'RJ${match.group(1)}';
  }

  static bool contains(String text) => _rjPattern.hasMatch(text);
}
