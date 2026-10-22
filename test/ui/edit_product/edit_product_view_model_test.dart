import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/ui/edit_product/edit_product_view_model.dart';

import '../../data/repositories/fake_product_image_repository.dart';

const _oldImagePath = 'product_images/old.jpg';

({ProviderContainer container, FakeProductImageRepository productImages})
_setUp() {
  final database = AppDatabase(NativeDatabase.memory());
  final productImages = FakeProductImageRepository()
    ..storedImages[_oldImagePath] = '/tmp/picked_earlier.jpg';
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      productImageRepositoryProvider.overrideWithValue(productImages),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return (container: container, productImages: productImages);
}

Future<StockItem> _addMilk(
  ProviderContainer container, {
  String? imagePath = _oldImagePath,
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
  return await container
      .read(stockItemRepositoryProvider)
      .addStockItemWithNewProduct(
        StockItemDraft(
          storageLocationId: fridge.id,
          quantity: 1,
          unit: StockUnit.liter,
        ),
        productName: 'Milch',
        imagePath: imagePath,
        nutritionFacts: const {Nutrient.fat: 3.5},
      );
}

Future<Product?> _stored(ProviderContainer container, String productId) =>
    container.read(productRepositoryProvider).getProduct(productId);

EditProductViewModel _viewModel(ProviderContainer container) =>
    container.read(editProductViewModelProvider);

void main() {
  test('saving writes name and nutrition facts and keeps the photo', () async {
    final (:container, :productImages) = _setUp();
    final milk = await _addMilk(container);

    await _viewModel(container).save(
      Product(
        id: milk.productId,
        name: '  Hafermilch ',
        imagePath: _oldImagePath,
        nutritionFacts: const {Nutrient.sugars: 4.0},
      ),
    );

    expect(
      await _stored(container, milk.productId),
      Product(
        id: milk.productId,
        name: 'Hafermilch',
        imagePath: _oldImagePath,
        nutritionFacts: const {Nutrient.sugars: 4.0},
      ),
    );
    expect(productImages.storedImages.keys, [_oldImagePath]);
  });

  test('replacing the photo stores the new one and deletes the old '
      'file', () async {
    final (:container, :productImages) = _setUp();
    final milk = await _addMilk(container);

    await _viewModel(container).save(
      Product(id: milk.productId, name: 'Milch', imagePath: _oldImagePath),
      pickedPhotoPath: '/tmp/image_picker_2.jpg',
    );

    expect(productImages.storedImages, {
      'product_images/2.jpg': '/tmp/image_picker_2.jpg',
    });
    expect(
      (await _stored(container, milk.productId))?.imagePath,
      'product_images/2.jpg',
    );
  });

  test('removing the photo deletes the old file', () async {
    final (:container, :productImages) = _setUp();
    final milk = await _addMilk(container);

    await _viewModel(container)
        .save(Product(id: milk.productId, name: 'Milch'));

    expect(productImages.storedImages, isEmpty);
    expect((await _stored(container, milk.productId))?.imagePath, isNull);
  });

  test('a product without photo gets the picked one', () async {
    final (:container, :productImages) = _setUp();
    productImages.storedImages.clear();
    final milk = await _addMilk(container, imagePath: null);

    await _viewModel(container).save(
      Product(id: milk.productId, name: 'Milch'),
      pickedPhotoPath: '/tmp/image_picker_1.jpg',
    );

    expect(
      (await _stored(container, milk.productId))?.imagePath,
      'product_images/1.jpg',
    );
  });

  test('saving a product that is gone deletes the picked photo '
      'again', () async {
    final (:container, :productImages) = _setUp();

    await expectLater(
      _viewModel(container).save(
        const Product(id: 'gone', name: 'Milch'),
        pickedPhotoPath: '/tmp/image_picker_2.jpg',
      ),
      throwsStateError,
    );

    expect(productImages.storedImages.keys, [_oldImagePath]);
  });

  const blankNames = {'an empty name': '', 'a name of spaces': '   '};
  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    test('saving $description is rejected and changes nothing', () async {
      final (:container, :productImages) = _setUp();
      final milk = await _addMilk(container);
      final before = await _stored(container, milk.productId);

      await expectLater(
        _viewModel(container).save(
          Product(id: milk.productId, name: name),
          pickedPhotoPath: '/tmp/image_picker_2.jpg',
        ),
        throwsArgumentError,
      );

      expect(await _stored(container, milk.productId), before);
      expect(productImages.storedImages.keys, [_oldImagePath]);
    });
  }

  final rejectedNutritionFacts = {
    'a negative fat value': (Nutrient.fat, -0.1),
    'more than 100 g of sugars': (Nutrient.sugars, 100.5),
    'more than 900 kcal': (Nutrient.energy, 901.0),
  };
  for (final MapEntry(key: description, value: (nutrient, value))
      in rejectedNutritionFacts.entries) {
    test('saving rejects $description and changes nothing', () async {
      final (:container, :productImages) = _setUp();
      final milk = await _addMilk(container);
      final before = await _stored(container, milk.productId);

      await expectLater(
        _viewModel(container).save(
          Product(
            id: milk.productId,
            name: 'Milch',
            nutritionFacts: {nutrient: value},
          ),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', nutrient.name)
              .having((error) => error.invalidValue, 'invalidValue', value),
        ),
      );

      expect(await _stored(container, milk.productId), before);
      expect(productImages.storedImages.keys, [_oldImagePath]);
    });
  }

  test('deleting removes the product, its stock and its image file', () async {
    final (:container, :productImages) = _setUp();
    final milk = await _addMilk(container);
    final product = (await _stored(container, milk.productId))!;

    await _viewModel(container).delete(product);

    expect(await _stored(container, milk.productId), isNull);
    final stock = await container
        .read(productRepositoryProvider)
        .getProductStock(milk.productId);
    expect(stock.stockItemCount, 0);
    expect(productImages.storedImages, isEmpty);
  });

  test('a product is loaded with its stock', () async {
    final (:container, productImages: _) = _setUp();
    final milk = await _addMilk(container);

    final editable = await container.read(
      editableProductProvider(milk.productId).future,
    );

    expect(editable?.product.name, 'Milch');
    expect(editable?.stock.stockItemCount, 1);
    expect(editable?.stock.homeNames, ['Berlin']);
  });

  test('a product whose stock is used up has no stock items', () async {
    final (:container, productImages: _) = _setUp();
    final milk = await _addMilk(container);
    await container.read(stockItemRepositoryProvider).deleteStockItem(milk.id);

    final editable = await container.read(
      editableProductProvider(milk.productId).future,
    );

    expect(editable?.stock.stockItemCount, 0);
    expect(editable?.stock.homeNames, isEmpty);
  });

  test('an unknown product is not editable', () async {
    final (:container, productImages: _) = _setUp();

    expect(
      await container.read(editableProductProvider('gone').future),
      isNull,
    );
  });
}
