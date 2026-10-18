import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/ui/stock_overview/consume_stock_item_view_model.dart';

ProviderContainer _createContainer() {
  final database = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return container;
}

Future<({StockItem stockItem, String homeId})> _addYoghurt(
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
          quantity: 500,
          unit: StockUnit.gram,
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
  const initialInputs = {
    'pieces start with one': (StockUnit.piece, '1'),
    'packages start with one': (StockUnit.package, '1'),
    'grams start empty': (StockUnit.gram, ''),
    'kilograms start empty': (StockUnit.kilogram, ''),
    'millilitres start empty': (StockUnit.milliliter, ''),
    'litres start empty': (StockUnit.liter, ''),
  };

  for (final MapEntry(key: description, value: (unit, expected))
      in initialInputs.entries) {
    test('the consumed quantity input: $description', () {
      final viewModel = _createContainer().read(
        consumeStockItemViewModelProvider,
      );

      expect(viewModel.initialConsumedInput(unit), expected);
    });
  }

  test('consuming lowers the stored quantity', () async {
    final container = _createContainer();
    final (:stockItem, :homeId) = await _addYoghurt(container);

    await container
        .read(consumeStockItemViewModelProvider)
        .consume(stockItem, '150');

    expect(await _stored(container, homeId), [
      stockItem.copyWith(quantity: 350),
    ]);
  });

  const invalidInputs = {
    'a quantity of 0': '0',
    'an empty quantity': '',
    'a quantity with four decimals': '1,2345',
  };

  for (final MapEntry(key: description, value: input)
      in invalidInputs.entries) {
    test('consuming $description is rejected and nothing changes', () async {
      final container = _createContainer();
      final (:stockItem, :homeId) = await _addYoghurt(container);

      await expectLater(
        container
            .read(consumeStockItemViewModelProvider)
            .consume(stockItem, input),
        throwsArgumentError,
      );

      expect(await _stored(container, homeId), [stockItem]);
    });
  }

  test('consuming completely removes the stock item', () async {
    final container = _createContainer();
    final (:stockItem, :homeId) = await _addYoghurt(container);

    await container
        .read(consumeStockItemViewModelProvider)
        .consumeCompletely(stockItem);

    expect(await _stored(container, homeId), isEmpty);
  });

  test('undo after consuming completely brings the stock item back', () async {
    final container = _createContainer();
    final (:stockItem, :homeId) = await _addYoghurt(container);
    final viewModel = container.read(consumeStockItemViewModelProvider);
    await viewModel.consumeCompletely(stockItem);

    await viewModel.undo(stockItem);

    expect(await _stored(container, homeId), [stockItem]);
  });
}
