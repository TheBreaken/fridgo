import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_view_model.dart';

import '../../data/repositories/fake_product_image_repository.dart';

ProviderContainer _createContainer({
  DateTime Function()? clock,
  FakeProductImageRepository? productImages,
}) {
  final database = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      productImageRepositoryProvider.overrideWithValue(
        productImages ?? FakeProductImageRepository(),
      ),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return container;
}

Future<StorageLocation> _createFridge(
  ProviderContainer container, {
  String homeName = 'Berlin',
}) async {
  final home = await container
      .read(homeRepositoryProvider)
      .createHome(homeName);
  return await container
      .read(storageLocationRepositoryProvider)
      .createStorageLocation(
        homeId: home.id,
        name: 'Kühlschrank',
        kind: StorageLocationKind.refrigerator,
      );
}

AddStockItemViewModel _viewModel(ProviderContainer container, String homeId) =>
    container.read(addStockItemViewModelProvider(homeId).notifier);

Future<List<StockItemDetails>> _stored(
  ProviderContainer container,
  String homeId,
) => container.read(stockItemRepositoryProvider).watchStockItems(homeId).first;

StockItemDraft _draft(StorageLocation storageLocation, {double quantity = 1}) =>
    StockItemDraft(
      storageLocationId: storageLocation.id,
      quantity: quantity,
      unit: StockUnit.liter,
    );

void main() {
  const nameCases = {
    'an empty name is invalid': (name: '', isValid: false),
    'a name of spaces is invalid': (name: '   ', isValid: false),
    'a name of tabs and line breaks is invalid': (name: '\t\n', isValid: false),
    'a single character is valid': (name: 'M', isValid: true),
    'a name with umlauts is valid': (name: 'Hähnchenbrust', isValid: true),
    'a name with surrounding spaces is valid': (
      name: '  Milch  ',
      isValid: true,
    ),
  };

  for (final MapEntry(key: description, value: (:name, :isValid))
      in nameCases.entries) {
    test('name validation: $description', () async {
      final container = _createContainer();
      final fridge = await _createFridge(container);

      final result = _viewModel(container, fridge.homeId).isValidName(name);

      expect(result, isValid);
    });
  }

  test('adding stores the product name without surrounding spaces', () async {
    final container = _createContainer();
    final fridge = await _createFridge(container);

    await _viewModel(
      container,
      fridge.homeId,
    ).addStockItemWithNewProduct(_draft(fridge), productName: '  Milch  ');

    final stored = await _stored(container, fridge.homeId);
    expect(stored.single.product.name, 'Milch');
  });

  test('adding with a picked photo stores it at the product', () async {
    final productImages = FakeProductImageRepository();
    final container = _createContainer(productImages: productImages);
    final fridge = await _createFridge(container);

    await _viewModel(container, fridge.homeId).addStockItemWithNewProduct(
      _draft(fridge),
      productName: 'Milch',
      pickedPhotoPath: '/tmp/image_picker_1.jpg',
    );

    final stored = await _stored(container, fridge.homeId);
    expect(productImages.storedImages, {
      'product_images/1.jpg': '/tmp/image_picker_1.jpg',
    });
    expect(stored.single.product.imagePath, 'product_images/1.jpg');
  });

  test('adding without photo stores no image', () async {
    final productImages = FakeProductImageRepository();
    final container = _createContainer(productImages: productImages);
    final fridge = await _createFridge(container);

    await _viewModel(
      container,
      fridge.homeId,
    ).addStockItemWithNewProduct(_draft(fridge), productName: 'Milch');

    final stored = await _stored(container, fridge.homeId);
    expect(productImages.storedImages, isEmpty);
    expect(stored.single.product.imagePath, isNull);
  });

  test('a rejected draft leaves the picked photo unstored', () async {
    final productImages = FakeProductImageRepository();
    final container = _createContainer(productImages: productImages);
    final fridge = await _createFridge(container);

    await expectLater(
      _viewModel(container, fridge.homeId).addStockItemWithNewProduct(
        _draft(fridge),
        productName: '',
        pickedPhotoPath: '/tmp/image_picker_1.jpg',
      ),
      throwsArgumentError,
    );

    expect(productImages.storedImages, isEmpty);
  });

  test('a failed save removes the stored image again', () async {
    final productImages = FakeProductImageRepository();
    final container = _createContainer(productImages: productImages);
    final fridge = await _createFridge(container);
    final draft = _draft(fridge)
        .copyWith(storageLocationId: 'unknown-storage-location');

    await expectLater(
      _viewModel(container, fridge.homeId).addStockItemWithNewProduct(
        draft,
        productName: 'Milch',
        pickedPhotoPath: '/tmp/image_picker_1.jpg',
      ),
      throwsA(isA<Exception>()),
    );

    expect(productImages.storedImages, isEmpty);
    expect(await _stored(container, fridge.homeId), isEmpty);
  });

  test('adding for an existing product stores no second product', () async {
    final container = _createContainer();
    final fridge = await _createFridge(container);
    final viewModel = _viewModel(container, fridge.homeId);
    await viewModel.addStockItemWithNewProduct(
      _draft(fridge),
      productName: 'Milch',
    );
    final milk = (await _stored(container, fridge.homeId)).single.product;

    await viewModel.addStockItemForProduct(milk.id, _draft(fridge));

    final stored = await _stored(container, fridge.homeId);
    expect([for (final details in stored) details.product], [milk, milk]);
  });

  test('adding for an existing product rejects a quantity of 0', () async {
    final container = _createContainer();
    final fridge = await _createFridge(container);
    final viewModel = _viewModel(container, fridge.homeId);
    await viewModel.addStockItemWithNewProduct(
      _draft(fridge),
      productName: 'Milch',
    );
    final milk = (await _stored(container, fridge.homeId)).single.product;

    await expectLater(
      viewModel.addStockItemForProduct(milk.id, _draft(fridge, quantity: 0)),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.invalidValue,
          'invalidValue',
          0,
        ),
      ),
    );

    expect(await _stored(container, fridge.homeId), hasLength(1));
  });

  test('products of other homes are found as well', () async {
    final container = _createContainer();
    final berlinFridge = await _createFridge(container);
    final hamburgFridge = await _createFridge(container, homeName: 'Hamburg');
    await _viewModel(
      container,
      hamburgFridge.homeId,
    ).addStockItemWithNewProduct(_draft(hamburgFridge), productName: 'Äpfel');

    final found = await _viewModel(
      container,
      berlinFridge.homeId,
    ).findProducts('apfel');

    expect([for (final product in found) product.name], ['Äpfel']);
  });

  const blankNames = {
    'an empty name is rejected': '',
    'a name of spaces is rejected': '   ',
  };

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    test('adding: $description and nothing is stored', () async {
      final container = _createContainer();
      final fridge = await _createFridge(container);

      await expectLater(
        _viewModel(
          container,
          fridge.homeId,
        ).addStockItemWithNewProduct(_draft(fridge), productName: name),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            name,
          ),
        ),
      );

      expect(await _stored(container, fridge.homeId), isEmpty);
    });
  }

  const nonPositiveQuantities = {
    'a quantity of 0 is rejected': 0.0,
    'a negative quantity is rejected': -1.0,
  };

  for (final MapEntry(key: description, value: quantity)
      in nonPositiveQuantities.entries) {
    test('adding: $description and nothing is stored', () async {
      final container = _createContainer();
      final fridge = await _createFridge(container);

      await expectLater(
        _viewModel(container, fridge.homeId).addStockItemWithNewProduct(
          _draft(fridge, quantity: quantity),
          productName: 'Milch',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            quantity,
          ),
        ),
      );

      expect(await _stored(container, fridge.homeId), isEmpty);
    });
  }

  final clockTimes = {
    'just after midnight on the day summer time starts': (
      DateTime(2026, 3, 29, 0, 1),
      '2026-03-29',
    ),
    'just before midnight on the day summer time ends': (
      DateTime(2026, 10, 25, 23, 59),
      '2026-10-25',
    ),
  };

  for (final MapEntry(key: description, value: (now, isoDate))
      in clockTimes.entries) {
    test('today comes from the clock: $description', () async {
      final container = _createContainer(clock: () => now);
      final fridge = await _createFridge(container);

      final today = _viewModel(container, fridge.homeId).today;

      expect(today, CalendarDate.parse(isoDate));
    });
  }

  test('the state lists only the storage locations of its home', () async {
    final container = _createContainer();
    final berlinFridge = await _createFridge(container);
    await _createFridge(container, homeName: 'Hamburg');
    final subscription = container.listen(
      addStockItemViewModelProvider(berlinFridge.homeId),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final storageLocations = await container.read(
      addStockItemViewModelProvider(berlinFridge.homeId).future,
    );

    expect(storageLocations, [berlinFridge]);
  });

  test('adding stores the nutrition facts at the new product', () async {
    final container = _createContainer();
    final fridge = await _createFridge(container);

    await _viewModel(container, fridge.homeId).addStockItemWithNewProduct(
      _draft(fridge),
      productName: 'Milch',
      nutritionFacts: const {Nutrient.energy: 64, Nutrient.fat: 0},
    );

    final stored = await _stored(container, fridge.homeId);
    expect(stored.single.product.nutritionFacts, {
      Nutrient.energy: 64.0,
      Nutrient.fat: 0.0,
    });
  });

  final rejectedNutritionFacts = {
    'a negative fat value': (Nutrient.fat, -0.1),
    'more than 100 g of sugars': (Nutrient.sugars, 100.5),
    'more than 900 kcal': (Nutrient.energy, 901.0),
  };
  for (final MapEntry(key: description, value: (nutrient, value))
      in rejectedNutritionFacts.entries) {
    test('adding rejects $description and stores nothing', () async {
      final productImages = FakeProductImageRepository();
      final container = _createContainer(productImages: productImages);
      final fridge = await _createFridge(container);

      await expectLater(
        _viewModel(container, fridge.homeId).addStockItemWithNewProduct(
          _draft(fridge),
          productName: 'Milch',
          pickedPhotoPath: '/tmp/image_picker_1.jpg',
          nutritionFacts: {nutrient: value},
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', nutrient.name)
              .having((error) => error.invalidValue, 'invalidValue', value),
        ),
      );

      expect(productImages.storedImages, isEmpty);
      expect(await _stored(container, fridge.homeId), isEmpty);
    });
  }
}
