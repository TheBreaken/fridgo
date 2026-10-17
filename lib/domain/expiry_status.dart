import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fridgo/domain/calendar_date.dart';

part 'expiry_status.freezed.dart';

/// How close a best before date is, seen from today. The opened date does not
/// count.
@freezed
sealed class ExpiryStatus with _$ExpiryStatus {
  const factory expired({required int daysAgo}) = Expired;

  const factory expiringSoon({required int daysLeft}) = ExpiringSoon;

  const factory fresh() = Fresh;

  const factory noBestBeforeDate() = NoBestBeforeDate;

  factory of(CalendarDate? bestBeforeDate, {required CalendarDate today}) {
    if (bestBeforeDate == null) return const ExpiryStatus.noBestBeforeDate();
    final daysLeft = today.daysUntil(bestBeforeDate);
    if (daysLeft < 0) return ExpiryStatus.expired(daysAgo: -daysLeft);
    if (daysLeft <= expiringSoonDays) {
      return ExpiryStatus.expiringSoon(daysLeft: daysLeft);
    }
    return const ExpiryStatus.fresh();
  }

  /// Today and this many following days count as expiring soon.
  static const expiringSoonDays = 3;
}
