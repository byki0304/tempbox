import 'package:flutter_test/flutter_test.dart';

import 'package:tempbox/shared/format.dart';

void main() {
  test('remaining time uses days and minutes', () {
    final now = DateTime.utc(2026, 10, 11).millisecondsSinceEpoch;
    final tenDays = remainingLabel(now + 240 * 3600000, now, (d, h) => '$d일 $h시간', (m) => '$m분');
    expect(tenDays, '10일 0시간');
    final minutes = remainingLabel(now + 59 * 60000, now, (d, h) => '$d일 $h시간', (m) => '$m분');
    expect(minutes, '59분');
  });

  test('text file names add a suffix in the same second', () {
    final used = <String>{};
    final now = DateTime.utc(2026, 10, 11, 9);
    final first = textDownloadName(now, used);
    final second = textDownloadName(now, used);
    expect(first, '261011-180000.txt');
    expect(second, '261011-180000-2.txt');
  });

  test('phone keeps 9 to 11 digits and email passwords stay alphanumeric', () {
    expect(normalizePhone('+82', '10-1234-5678'), '+821012345678');
    expect(normalizePhone('+82', '12'), isNull);
    expect(validPassword('abc123'), isTrue);
    expect(validPassword('한글123'), isFalse);
    expect(validNickname('상자'), isTrue);
    expect(displayPairingCode('ab12cd34'), 'AB12-CD34');
    expect(displayPairingCode('ab12-cd34'), 'AB12-CD34');
  });
}
