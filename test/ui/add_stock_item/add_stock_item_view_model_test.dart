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

StockItemDraft _draft(
  StorageLocation storageLocation, {
  String productName = 'Milch',
  double quantity = 1,
}) => StockItemDraft(
  productName: productName,
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

  const quantityCases = {
    'a whole number is valid': (quantity: '1', isValid: true),
    'a decimal comma is valid': (quantity: '1,5', isValid: true),
    'a decimal point is valid': (quantity: '1.5', isValid: true),
    'three decimals are valid': (quantity: '0,001', isValid: true),
    'a leading decimal comma is valid': (quantity: ',5', isValid: true),
    'surrounding spaces are valid': (quantity: ' 2 ', isValid: true),
    'a large number is valid': (quantity: '100000', isValid: true),
    'zero is invalid': (quantity: '0', isValid: false),
    'zero with decimals is invalid': (quantity: '0,000', isValid: false),
    'a negative number is invalid': (quantity: '-1', isValid: false),
    'four decimals are invalid': (quantity: '1,2345', isValid: false),
    'a trailing decimal comma is invalid': (quantity: '1,', isValid: false),
    'two decimal separators are invalid': (quantity: '1,5,5', isValid: false),
    'an exponent is invalid': (quantity: '1e3', isValid: false),
    'letters are invalid': (quantity: 'zwei', isValid: false),
    'an empty quantity is invalid': (quantity: '', isValid: false),
    'a quantity of spaces is invalid': (quantity: '   ', isValid: false),
    'a lone decimal comma is invalid': (quantity: ',', isValid: false),
  };

  for (final MapEntry(key: description, value: (:quantity, :isValid))
      in quantityCases.entries) {
    test('quantity validation: $description', () async {
      final container = _createContainer();
      final fridge = await _createFridge(container);

      final result = _viewModel(
        container,
        fridge.homeId,
      ).isValidQuantity(quantity);

      expect(result, isValid);
    });
  }

  const parsedQuantities = {
    'a decimal comma is read as decimal separator': ('1,5', 1.5),
    'a decimal point is read as decimal separator': ('1.5', 1.5),
    'three decimals are kept': ('0,001', 0.001),
    'a leading decimal comma means zero point': (',5', 0.5),
    'surrounding spaces are ignored': (' 2 ', 2.0),
  };

  for (final MapEntry(key: description, value: (quantity, expected))
      in parsedQuantities.entries) {
    test('parsing the quantity: $description', () async {
      final container = _createContainer();
      final fridge = await _createFridge(container);

      final result = _viewModel(
        container,
        fridge.homeId,
      ).parseQuantity(quantity);

      expect(result, expected);
    });
  }

  test('parsing an invalid quantity is rejected', () async {
    final container = _createContainer();
    final fridge = await _createFridge(container);

    expect(
      () => _viewModel(container, fridge.homeId).parseQuantity('0'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.invalidValue,
          'invalidValue',
          '0',
        ),
      ),
    );
  });

  test('adding stores the product name without surrounding spaces', () async {
    final container = _createContainer();
    final fridge = await _createFridge(container);

    await _viewModel(
      container,
      fridge.homeId,
    ).addStockItem(_draft(fridge, productName: '  Milch  '));

    final stored = await _stored(container, fridge.homeId);
    expect(stored.single.product.name, 'Milch');
  });

  test('adding with a picked photo stores it at the product', () async {
    final productImages = FakeProductImageRepository();
    final container = _createContainer(productImages: productImages);
    final fridge = await _createFridge(container);

    await _viewModel(
      container,
      fridge.homeId,
    ).addStockItem(_draft(fridge), pickedPhotoPath: '/tmp/image_picker_1.jpg');

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

    await _viewModel(container, fridge.homeId).addStockItem(_draft(fridge));

    final stored = await _stored(container, fridge.homeId);
    expect(productImages.storedImages, isEmpty);
    expect(stored.single.product.imagePath, isNull);
  });

  test('a rejected draft leaves the picked photo unstored', () async {
    final productImages = FakeProductImageRepository();
    final container = _createContainer(productImages: productImages);
    final fridge = await _createFridge(container);

    await expectLater(
      _viewModel(container, fridge.homeId).addStockItem(
        _draft(fridge, productName: ''),
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
      _viewModel(
        container,
        fridge.homeId,
      ).addStockItem(draft, pickedPhotoPath: '/tmp/image_picker_1.jpg'),
      throwsA(isA<Exception>()),
    );

    expect(productImages.storedImages, isEmpty);
    expect(await _stored(container, fridge.homeId), isEmpty);
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
        ).addStockItem(_draft(fridge, productName: name)),
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
        _viewModel(
          container,
          fridge.homeId,
        ).addStockItem(_draft(fridge, quantity: quantity)),
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
}
