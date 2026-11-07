/// 時刻を持たない暦の日付（目標の期日・タスクの予定日・今日）。
///
/// Firestore には `YYYY-MM-DD` の文字列で保存する（DES-001 3.4）。
final class CalendarDate implements Comparable<CalendarDate> {
  /// 範囲外の値（13月など）は、[DateTime] と同じく繰り上げて正規化する。
  factory CalendarDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    return CalendarDate._(normalized.year, normalized.month, normalized.day);
  }

  const CalendarDate._(this.year, this.month, this.day);

  /// [dateTime] の、そのタイムゾーンでの日付。端末のローカル時刻を渡せば「今日」になる（NFR-006）。
  factory CalendarDate.fromDateTime(DateTime dateTime) =>
      CalendarDate._(dateTime.year, dateTime.month, dateTime.day);

  /// `YYYY-MM-DD` の文字列を読む。形式が正しくない、または存在しない日付なら [FormatException]。
  factory CalendarDate.parse(String value) {
    final match = _isoPattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid date (expected YYYY-MM-DD)', value);
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = CalendarDate(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('Invalid date', value);
    }
    return date;
  }

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// `YYYY-MM-DD`。辞書順が日付順になる。
  String toIso8601() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// ローカル時刻のその日の 0 時。
  DateTime toLocalDateTime() => DateTime(year, month, day);

  CalendarDate addDays(int days) => CalendarDate(year, month, day + days);

  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601();
}
