import 'package:flutter_test/flutter_test.dart';
import 'package:tempbox/app/i18n.dart';
import 'package:tempbox/shared/format.dart';

void main() {
  test('japanese covers every screen string', () {
    expect(L10n.complete('en'), isTrue);
    expect(L10n.complete('ja'), isTrue);
    final ja = L10n('ja');
    expect(ja.tr('login'), 'ログイン');
    expect(ja.tr('guestOpen'), 'アカウントなしでボックスを開く');
    expect(ja.tr('cloudCap'), 'ファイル1つの上限');
    expect(ja.tr('helpHoursBody'), contains('240'));
    expect(ja.tr('helpHoursBody'), contains('24'));
    expect(ja.tr('korean'), '한국어');
    expect(ja.tr('english'), 'English');
    expect(ja.tr('japanese'), '日本語');
    expect(ja.tr('missing-key'), 'missing-key');
  });

  test('day labels follow the selected language', () {
    final now = DateTime.utc(2026, 10, 14, 3).millisecondsSinceEpoch;
    final sameDay = DateTime.utc(2026, 10, 14, 1).millisecondsSinceEpoch;
    expect(chatDayLabel(sameDay, now, locale: 'ko'), '10월 14일');
    expect(chatDayLabel(sameDay, now, locale: 'en'), '10/14');
    expect(chatDayLabel(sameDay, now, locale: 'ja'), '10月14日');
    final older = DateTime.utc(2025, 1, 2, 1).millisecondsSinceEpoch;
    expect(chatDayLabel(older, now, locale: 'ja'), '2025年1月2日');
  });
}
