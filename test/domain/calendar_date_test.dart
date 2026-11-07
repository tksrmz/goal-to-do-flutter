import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/domain/calendar_date.dart';

void main() {
  group('CalendarDate', () {
    test('YYYY-MM-DD を読み書きできる', () {
      final date = CalendarDate.parse('2026-11-06');
      expect((date.year, date.month, date.day), (2026, 11, 6));
      expect(date.toIso8601(), '2026-11-06');
      expect(CalendarDate(2026, 1, 2).toIso8601(), '2026-01-02');
    });

    test('形式が正しくない・存在しない日付は FormatException', () {
      for (final value in ['2026/11/06', '2026-1-6', '', '2026-02-30']) {
        expect(
          () => CalendarDate.parse(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('ローカル時刻から日付を取る（AC-014: 日本時間 08:00 は同じ日）', () {
      final date = CalendarDate.fromDateTime(DateTime(2026, 11, 6, 8));
      expect(date, CalendarDate(2026, 11, 6));
    });

    test('比較と日数の加算', () {
      final a = CalendarDate(2026, 11, 6);
      final b = CalendarDate(2026, 11, 7);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.compareTo(CalendarDate(2026, 11, 6)), 0);
      expect(CalendarDate(2026, 12, 31).addDays(1), CalendarDate(2027, 1, 1));
      expect(a.hashCode, CalendarDate(2026, 11, 6).hashCode);
    });
  });
}
