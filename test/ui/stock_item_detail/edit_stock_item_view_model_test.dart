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
import 'package:fridgo/ui/stock_item_detail/edit_stock_item_view_model.dart';

ProviderContainer _createContainer({DateTime Function()? clock}) {
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
  return container;
}

Future<({StockItem stockItem, String homeId})> _addMilk(
  ProviderContainer container,
) async {
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
          quantity: 1,
          unit: StockUnit.liter,
          bestBeforeDate: CalendarDate(2026, 10, 25),
        ),
        productName: 'Milch',
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
  test('saving writes the changed values', () async {
    final container = _createContainer();
    final (:stockItem, :homeId) = await _addMilk(container);
    final changed = stockItem.copyWith(
      quantity: 0.75,
      unit: StockUnit.package,
      bestBeforeDate: null,
      openedDate: CalendarDate(2026, 10, 20),
    );

    await container.read(editStockItemViewModelProvider).save(changed);

    expect(await _stored(container, homeId), [changed]);
  });

  const invalidQuantities = {'zero': 0.0, 'negative': -1.0};

  for (final MapEntry(key: description, value: quantity)
      in invalidQuantities.entries) {
    test('saving a $description quantity is rejected and changes '
        'nothing', () async {
      final container = _createContainer();
      final (:stockItem, :homeId) = await _addMilk(container);

      await expectLater(
        container
            .read(editStockItemViewModelProvider)
            .save(stockItem.copyWith(quantity: quantity)),
        throwsArgumentError,
      );

      expect(await _stored(container, homeId), [stockItem]);
    });
  }

  test('today comes from the clock', () {
    final container = _createContainer(
      clock: () => DateTime(2026, 10, 22, 23, 59),
    );

    expect(
      container.read(editStockItemViewModelProvider).today,
      CalendarDate(2026, 10, 22),
    );
  });
}
