import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/expiry_status.dart';

void main() {
  final today = CalendarDate(2026, 10, 16);

  final statuses = {
    'without best before date there is no status': (
      null,
      const ExpiryStatus.noBestBeforeDate(),
    ),
    'expiring today is expiring soon': (
      CalendarDate(2026, 10, 16),
      const ExpiryStatus.expiringSoon(daysLeft: 0),
    ),
    'expiring tomorrow is expiring soon': (
      CalendarDate(2026, 10, 17),
      const ExpiryStatus.expiringSoon(daysLeft: 1),
    ),
    'expiring exactly at the threshold is expiring soon': (
      CalendarDate(2026, 10, 19),
      const ExpiryStatus.expiringSoon(daysLeft: 3),
    ),
    'one day past the threshold is fresh': (
      CalendarDate(2026, 10, 20),
      const ExpiryStatus.fresh(),
    ),
    'next year is fresh': (
      CalendarDate(2027, 10, 16),
      const ExpiryStatus.fresh(),
    ),
    'expired yesterday is expired one day ago': (
      CalendarDate(2026, 10, 15),
      const ExpiryStatus.expired(daysAgo: 1),
    ),
    'expired last month counts the days': (
      CalendarDate(2026, 9, 16),
      const ExpiryStatus.expired(daysAgo: 30),
    ),
  };

  for (final MapEntry(key: description, value: (bestBeforeDate, expected))
      in statuses.entries) {
    test(description, () {
      expect(ExpiryStatus.of(bestBeforeDate, today: today), expected);
    });
  }

  final aroundDaylightSavingTime = {
    'summer time ends': (
      CalendarDate(2026, 10, 24),
      CalendarDate(2026, 10, 27),
      const ExpiryStatus.expiringSoon(daysLeft: 3),
    ),
    'summer time starts': (
      CalendarDate(2026, 3, 28),
      CalendarDate(2026, 3, 31),
      const ExpiryStatus.expiringSoon(daysLeft: 3),
    ),
    'summer time ends, one day past the threshold': (
      CalendarDate(2026, 10, 24),
      CalendarDate(2026, 10, 28),
      const ExpiryStatus.fresh(),
    ),
    'summer time starts, expired the day before': (
      CalendarDate(2026, 3, 30),
      CalendarDate(2026, 3, 29),
      const ExpiryStatus.expired(daysAgo: 1),
    ),
  };

  for (final MapEntry(key: description, value: (today, bestBeforeDate, status))
      in aroundDaylightSavingTime.entries) {
    test('the threshold holds when $description', () {
      expect(ExpiryStatus.of(bestBeforeDate, today: today), status);
    });
  }
}
