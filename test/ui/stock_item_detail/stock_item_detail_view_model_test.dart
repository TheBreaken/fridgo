import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_view_model.dart';

({ProviderContainer container, AppDatabase database}) _createContainer({
  DateTime Function()? clock,
}) {
  final database = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return (container: container, database: database);
}

Future<({StockItem stockItem, String homeId})> _addYoghurt(
  ProviderContainer container, {
  CalendarDate? openedDate,
}) async {
  final home = await container
      .read(homeRepositoryProvider)
      .createHome('Berlin');
  final fridge = await container
      .read(storageLocationRepositoryProvider)
      .createStorageLocation(
        homeId: home.id,
        name: 'Kühlschrank',
        kind: StorageLocationKind.refrigerator,
      );
  final stockItem = await container
      .read(stockItemRepositoryProvider)
      .addStockItemWithNewProduct(
        StockItemDraft(
          storageLocationId: fridge.id,
          quantity: 2,
          unit: StockUnit.piece,
          bestBeforeDate: CalendarDate(2026, 10, 30),
          openedDate: openedDate,
        ),
        productName: 'Joghurt',
      );
  return (stockItem: stockItem, homeId: home.id);
}

Future<List<StockItem>> _stored(
  ProviderContainer container,
  String homeId,
) async => [
  for (final details
      in await container
          .read(stockItemRepositoryProvider)
          .watchStockItems(homeId)
          .first)
    details.stockItem,
];

void main() {
  final openedToday = <String, (DateTime, CalendarDate)>{
    'at midday it is that day': (
      DateTime(2026, 10, 22, 12),
      CalendarDate(2026, 10, 22),
    ),
    'just before midnight it is still that day': (
      DateTime(2026, 10, 22, 23, 59),
      CalendarDate(2026, 10, 22),
    ),
    'just after midnight it is the next day': (
      DateTime(2026, 10, 23, 0, 1),
      CalendarDate(2026, 10, 23),
    ),
    'on the night the clocks go back it is that day': (
      DateTime(2026, 10, 25, 2, 30),
      CalendarDate(2026, 10, 25),
    ),
  };

  for (final MapEntry(key: description, value: (now, expected))
      in openedToday.entries) {
    test('marking as opened today: $description', () async {
      final (:container, database: _) = _createContainer(clock: () => now);
      final (:stockItem, :homeId) = await _addYoghurt(container);

      await container
          .read(stockItemDetailViewModelProvider)
          .markOpenedToday(stockItem);

      expect(await _stored(container, homeId), [
        stockItem.copyWith(openedDate: expected),
      ]);
    });
  }

  test('marking as opened today replaces an earlier opened date', () async {
    final (:container, database: _) = _createContainer(
      clock: () => DateTime(2026, 10, 22, 9),
    );
    final (:stockItem, :homeId) = await _addYoghurt(
      container,
      openedDate: CalendarDate(2026, 10, 1),
    );

    await container
        .read(stockItemDetailViewModelProvider)
        .markOpenedToday(stockItem);

    expect(
      (await _stored(container, homeId)).single.openedDate,
      CalendarDate(2026, 10, 22),
    );
  });

  test('deleting removes the stock item and keeps the product', () async {
    final (:container, :database) = _createContainer();
    final (:stockItem, :homeId) = await _addYoghurt(container);

    await container.read(stockItemDetailViewModelProvider).delete(stockItem);

    expect(await _stored(container, homeId), isEmpty);
    expect(await database.select(database.products).get(), hasLength(1));
  });
}
