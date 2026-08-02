/// Natural-order string compare — digit runs compare numerically so `2_xxx`
/// sorts before `10_xxx`, even when the surrounding separator (e.g. `_`) is
/// ASCII-greater than the digit.
int naturalCompare(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final aDigit = _isDigit(a.codeUnitAt(i));
    final bDigit = _isDigit(b.codeUnitAt(j));
    if (aDigit && bDigit) {
      var ai = i;
      while (ai < a.length && _isDigit(a.codeUnitAt(ai))) {
        ai++;
      }
      var bj = j;
      while (bj < b.length && _isDigit(b.codeUnitAt(bj))) {
        bj++;
      }
      var aStart = i;
      while (aStart < ai - 1 && a.codeUnitAt(aStart) == 0x30) {
        aStart++;
      }
      var bStart = j;
      while (bStart < bj - 1 && b.codeUnitAt(bStart) == 0x30) {
        bStart++;
      }
      final aLen = ai - aStart;
      final bLen = bj - bStart;
      if (aLen != bLen) return aLen - bLen;
      for (var k = 0; k < aLen; k++) {
        final c = a.codeUnitAt(aStart + k) - b.codeUnitAt(bStart + k);
        if (c != 0) return c;
      }
      i = ai;
      j = bj;
    } else {
      final c = a.codeUnitAt(i) - b.codeUnitAt(j);
      if (c != 0) return c;
      i++;
      j++;
    }
  }
  return (a.length - i) - (b.length - j);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
