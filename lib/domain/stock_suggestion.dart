import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/storage_location.dart';

/// Days from adding stock to its best-before date, as a product learns them.
///
/// An already expired best-before date teaches nothing, or the next
/// suggestion would lie in the past too.
int? shelfLifeDays(CalendarDate today, CalendarDate? bestBeforeDate) {
  if (bestBeforeDate == null) return null;
  final days = today.daysUntil(bestBeforeDate);
  return days < 0 ? null : days;
}

CalendarDate? suggestBestBeforeDate(Product product, CalendarDate today) =>
    switch (product.shelfLifeDays) {
      final days? => today.addDays(days),
      null => null,
    };

/// The first of [storageLocations] of the kind the product was stored in.
StorageLocation? suggestStorageLocation(
  Product product,
  List<StorageLocation> storageLocations,
) => storageLocations
    .where(
      (storageLocation) => storageLocation.kind == product.storageLocationKind,
    )
    .firstOrNull;
