import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/calendar_date.dart';

void main() {
  test('the tests run in a time zone with daylight saving time', () {
    expect(
      DateTime(2026, 3, 30).timeZoneOffset,
      isNot(DateTime(2026, 3, 28).timeZoneOffset),
      reason:
          'make test sets TZ=Europe/Berlin; without it the daylight '
          'saving time tests below prove nothing',
    );
  });

  const validIsoDates = {
    'an ordinary day': ('2026-10-25', (2026, 10, 25)),
    'the first day of the year': ('2026-01-01', (2026, 1, 1)),
    'the last day of the year': ('2026-12-31', (2026, 12, 31)),
    'a leap day in a leap year': ('2028-02-29', (2028, 2, 29)),
    'a year below 1000': ('0999-05-01', (999, 5, 1)),
  };

  for (final MapEntry(key: description, value: (isoDate, (year, month, day)))
      in validIsoDates.entries) {
    test('parsing $description gives its year, month and day', () {
      final date = CalendarDate.parse(isoDate);

      expect((date.year, date.month, date.day), (year, month, day));
    });

    test('$description is written back as $isoDate', () {
      expect(CalendarDate(year, month, day).toIso8601String(), isoDate);
    });
  }

  const malformedIsoDates = {
    'an empty string is rejected': '',
    'a German date is rejected': '25.10.2026',
    'a missing leading zero is rejected': '2026-1-05',
    'a date with time is rejected': '2026-10-25T00:00:00',
    'surrounding spaces are rejected': ' 2026-10-25 ',
    'a two-digit year is rejected': '26-10-25',
  };

  for (final MapEntry(key: description, value: isoDate)
      in malformedIsoDates.entries) {
    test('parsing: $description', () {
      expect(() => CalendarDate.parse(isoDate), throwsFormatException);
    });
  }

  const impossibleDays = {
    'the 30th of February is rejected': (2026, 2, 30),
    'a leap day outside a leap year is rejected': (2026, 2, 29),
    'month 13 is rejected': (2026, 13, 1),
    'month 0 is rejected': (2026, 0, 1),
    'day 0 is rejected': (2026, 10, 0),
    'the 31st of April is rejected': (2026, 4, 31),
  };

  for (final MapEntry(key: description, value: (year, month, day))
      in impossibleDays.entries) {
    test('creating: $description', () {
      expect(() => CalendarDate(year, month, day), throwsArgumentError);
    });
  }

  test('parsing an impossible day is rejected', () {
    expect(() => CalendarDate.parse('2026-02-30'), throwsArgumentError);
  });

  final deviceTimes = {
    'midnight when summer time starts': (DateTime(2026, 3, 29), '2026-03-29'),
    'the last minute of the day summer time starts': (
      DateTime(2026, 3, 29, 23, 59),
      '2026-03-29',
    ),
    'midnight when summer time ends': (DateTime(2026, 10, 25), '2026-10-25'),
    'the last minute of the day summer time ends': (
      DateTime(2026, 10, 25, 23, 59),
      '2026-10-25',
    ),
    'shortly after midnight in winter': (
      DateTime(2026, 1, 15, 0, 1),
      '2026-01-15',
    ),
    'a UTC time is taken as its UTC day': (
      DateTime.utc(2026, 3, 28, 23, 30),
      '2026-03-28',
    ),
  };

  for (final MapEntry(key: description, value: (dateTime, isoDate))
      in deviceTimes.entries) {
    test('from a device time: $description keeps the shown day', () {
      expect(CalendarDate.fromDateTime(dateTime).toIso8601String(), isoDate);
    });
  }

  const daylightSavingDays = {
    'the day summer time starts': '2026-03-29',
    'the day summer time ends': '2026-10-25',
  };

  for (final MapEntry(key: description, value: isoDate)
      in daylightSavingDays.entries) {
    test('$description survives the way through a local date time', () {
      final date = CalendarDate.parse(isoDate);

      expect(CalendarDate.fromDateTime(date.toDateTime()), date);
    });
  }

  test('the local date time is midnight of that day', () {
    expect(CalendarDate(2026, 3, 29).toDateTime(), DateTime(2026, 3, 29));
  });

  test('two dates of the same day are equal', () {
    expect(CalendarDate(2026, 10, 25), CalendarDate.parse('2026-10-25'));
    expect(
      CalendarDate(2026, 10, 25).hashCode,
      CalendarDate.parse('2026-10-25').hashCode,
    );
  });

  test('neighbouring days are not equal', () {
    expect(CalendarDate(2026, 10, 25), isNot(CalendarDate(2026, 10, 26)));
  });
}
