import 'package:flutter/foundation.dart';

/// A day as printed on a package, without time of day or time zone.
@immutable
final class CalendarDate {
  factory(int year, int month, int day) {
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError('$year-$month-$day is not a calendar date');
    }
    return CalendarDate._(year, month, day);
  }

  /// Takes the day the device shows for [dateTime], ignoring its time and
  /// offset, so no time zone conversion can move it to a neighbouring day.
  new fromDateTime(DateTime dateTime)
    : this._(dateTime.year, dateTime.month, dateTime.day);

  factory parse(String isoDate) {
    final match = _isoDate.firstMatch(isoDate);
    if (match == null) {
      throw FormatException('Expected a date as YYYY-MM-DD', isoDate);
    }
    return CalendarDate(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  const new _(this.year, this.month, this.day);

  static final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// Local midnight of this day, for widgets such as the date picker.
  DateTime toDateTime() => DateTime(year, month, day);

  String toIso8601String() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  String toString() => toIso8601String();

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
