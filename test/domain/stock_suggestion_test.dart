import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_suggestion.dart';
import 'package:fridgo/domain/storage_location.dart';

void main() {
  final today = CalendarDate(2026, 10, 24);

  final learnedDays = {
    'without best-before date nothing is learned': (null, null),
    'a best-before date today is zero days': (CalendarDate(2026, 10, 24), 0),
    'a best-before date tomorrow is one day': (CalendarDate(2026, 10, 25), 1),
    'across the end of summer time the days stay whole': (
      CalendarDate(2026, 10, 31),
      7,
    ),
    'an expired best-before date teaches nothing': (
      CalendarDate(2026, 10, 23),
      null,
    ),
  };

  for (final MapEntry(key: description, value: (bestBeforeDate, days))
      in learnedDays.entries) {
    test('shelf life: $description', () {
      expect(shelfLifeDays(today, bestBeforeDate), days);
    });
  }

  test('a product without shelf life suggests no best-before date', () {
    const product = Product(id: 'milk', name: 'Milch');

    expect(suggestBestBeforeDate(product, today), isNull);
  });

  test('the suggested best-before date is today plus the shelf life, '
      'across the end of summer time', () {
    const product = Product(id: 'milk', name: 'Milch', shelfLifeDays: 2);

    expect(suggestBestBeforeDate(product, today), CalendarDate(2026, 10, 26));
  });

  const freezer = StorageLocation(
    id: 'freezer',
    homeId: 'home',
    name: 'Gefrierfach',
    kind: StorageLocationKind.freezer,
  );
  const refrigerator = StorageLocation(
    id: 'refrigerator',
    homeId: 'home',
    name: 'Kühlschrank',
    kind: StorageLocationKind.refrigerator,
  );
  const secondRefrigerator = StorageLocation(
    id: 'second-refrigerator',
    homeId: 'home',
    name: 'Kühlschrank Keller',
    kind: StorageLocationKind.refrigerator,
  );

  const suggestedStorageLocations = {
    'the storage location of the learned kind is suggested': (
      StorageLocationKind.refrigerator,
      [freezer, refrigerator],
      refrigerator,
    ),
    'of two of the learned kind the first is suggested': (
      StorageLocationKind.refrigerator,
      [freezer, refrigerator, secondRefrigerator],
      refrigerator,
    ),
    'without one of the learned kind nothing is suggested': (
      StorageLocationKind.pantry,
      [freezer, refrigerator],
      null,
    ),
    'without a learned kind nothing is suggested': (
      null,
      [freezer, refrigerator],
      null,
    ),
    'a home without storage locations gets no suggestion': (
      StorageLocationKind.refrigerator,
      <StorageLocation>[],
      null,
    ),
  };

  for (final MapEntry(
        key: description,
        value: (kind, storageLocations, suggested),
      )
      in suggestedStorageLocations.entries) {
    test('storage location: $description', () {
      final product = Product(
        id: 'milk',
        name: 'Milch',
        storageLocationKind: kind,
      );

      expect(suggestStorageLocation(product, storageLocations), suggested);
    });
  }
}
