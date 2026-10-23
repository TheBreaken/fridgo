import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';

Future<StockItem> _addToNewHome(
  AppDatabase database, {
  required String homeName,
  required String productName,
  String? imagePath,
  Map<Nutrient, double> nutritionFacts = const {},
}) async {
  final home = await HomeRepository(database).createHome(homeName);
  final storageLocation = await StorageLocationRepository(database)
      .createStorageLocation(
        homeId: home.id,
        name: 'Kühlschrank',
        kind: StorageLocationKind.refrigerator,
      );
  return await StockItemRepository(database).addStockItemWithNewProduct(
    StockItemDraft(
      storageLocationId: storageLocation.id,
      quantity: 1,
      unit: StockUnit.piece,
    ),
    productName: productName,
    imagePath: imagePath,
    nutritionFacts: nutritionFacts,
  );
}

Future<String> _createFridge(
  AppDatabase database, {
  required String homeName,
}) async {
  final home = await HomeRepository(database).createHome(homeName);
  final storageLocation = await StorageLocationRepository(database)
      .createStorageLocation(
        homeId: home.id,
        name: 'Kühlschrank',
        kind: StorageLocationKind.refrigerator,
      );
  return storageLocation.id;
}

StockItemDraft _draft(String storageLocationId) => StockItemDraft(
  storageLocationId: storageLocationId,
  quantity: 1,
  unit: StockUnit.piece,
);

void main() {
  late AppDatabase database;
  late ProductRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    repository = ProductRepository(database);
  });

  test('an empty database has no products', () async {
    expect(await repository.getProducts(), isEmpty);
  });

  test('products of all homes are returned with name and image', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
      imagePath: 'product_images/milk.jpg',
    );
    final butter = await _addToNewHome(
      database,
      homeName: 'Hamburg',
      productName: 'Butter',
    );

    final products = await repository.getProducts();

    expect(
      products,
      unorderedEquals([
        Product(
          id: milk.productId,
          name: 'Milch',
          imagePath: 'product_images/milk.jpg',
        ),
        Product(id: butter.productId, name: 'Butter'),
      ]),
    );
  });

  test('a barcode finds the product that has it', () async {
    final home = await HomeRepository(database).createHome('Berlin');
    final fridge = await StorageLocationRepository(database)
        .createStorageLocation(
          homeId: home.id,
          name: 'Kühlschrank',
          kind: StorageLocationKind.refrigerator,
        );
    final stockItems = StockItemRepository(database);
    await stockItems.addStockItemWithNewProduct(
      _draft(fridge.id),
      productName: 'Butter',
      barcode: '4098765432109',
    );
    final milk = await stockItems.addStockItemWithNewProduct(
      _draft(fridge.id),
      productName: 'Milch',
      barcode: '4012345678901',
    );

    expect(
      await repository.findProductByBarcode('4012345678901'),
      Product(id: milk.productId, name: 'Milch', barcode: '4012345678901'),
    );
  });

  test('an unknown barcode finds no product', () async {
    await _addToNewHome(database, homeName: 'Berlin', productName: 'Milch');

    expect(await repository.findProductByBarcode('4012345678901'), isNull);
  });

  test('a product keeps exactly the nutrition facts it was given', () async {
    const nutritionFacts = {
      Nutrient.energy: 64.0,
      Nutrient.fat: 3.5,
      Nutrient.sugars: 0.0,
      Nutrient.salt: 0.125,
    };
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
      nutritionFacts: nutritionFacts,
    );

    final products = await repository.getProducts();

    expect(products.single.nutritionFacts, nutritionFacts);
    expect(products.single.id, milk.productId);
  });

  test('every nutrient is stored in its own column', () async {
    const nutritionFacts = {
      Nutrient.energy: 1.0,
      Nutrient.fat: 2.0,
      Nutrient.saturatedFat: 3.0,
      Nutrient.carbohydrates: 4.0,
      Nutrient.sugars: 5.0,
      Nutrient.protein: 6.0,
      Nutrient.salt: 7.0,
    };
    await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Müsli',
      nutritionFacts: nutritionFacts,
    );

    final products = await repository.getProducts();

    expect(products.single.nutritionFacts, nutritionFacts);
  });

  test('getting a product returns it with all its fields', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
      imagePath: 'product_images/milk.jpg',
      nutritionFacts: {Nutrient.fat: 3.5},
    );

    final product = await repository.getProduct(milk.productId);

    expect(
      product,
      Product(
        id: milk.productId,
        name: 'Milch',
        imagePath: 'product_images/milk.jpg',
        nutritionFacts: {Nutrient.fat: 3.5},
      ),
    );
  });

  test('getting an unknown product returns null', () async {
    expect(await repository.getProduct('unknown'), isNull);
  });

  test('an update replaces name, image and nutrition facts', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
      imagePath: 'product_images/milk.jpg',
      nutritionFacts: {Nutrient.fat: 3.5, Nutrient.sugars: 4.8},
    );
    final updated = Product(
      id: milk.productId,
      name: 'Hafermilch',
      imagePath: 'product_images/oat_milk.jpg',
      nutritionFacts: {Nutrient.fat: 1.5},
    );

    await repository.updateProduct(updated);

    expect(await repository.getProduct(milk.productId), updated);
  });

  test('an update can remove the image', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
      imagePath: 'product_images/milk.jpg',
    );

    await repository.updateProduct(Product(id: milk.productId, name: 'Milch'));

    final product = await repository.getProduct(milk.productId);
    expect(product?.imagePath, isNull);
  });

  test('updating an unknown product fails', () async {
    await expectLater(
      repository.updateProduct(const Product(id: 'unknown', name: 'Milch')),
      throwsStateError,
    );
  });

  test('the stock of a product counts its stock items and names their '
      'homes once each, sorted', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Hamburg',
      productName: 'Milch',
    );
    final hamburgFridge = milk.storageLocationId;
    final stockItems = StockItemRepository(database);
    await stockItems.addStockItemForProduct(
      milk.productId,
      _draft(hamburgFridge),
    );
    final berlinFridge = await _createFridge(database, homeName: 'berlin');
    await stockItems.addStockItemForProduct(
      milk.productId,
      _draft(berlinFridge),
    );

    final stock = await repository.getProductStock(milk.productId);

    expect(stock.stockItemCount, 3);
    expect(stock.homeNames, ['berlin', 'Hamburg']);
  });

  test('a product whose stock items are gone has no stock', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
    );
    await StockItemRepository(database).deleteStockItem(milk.id);

    final stock = await repository.getProductStock(milk.productId);

    expect(stock.stockItemCount, 0);
    expect(stock.homeNames, isEmpty);
  });

  test('deleting a product removes its stock items in every home', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
    );
    final hamburgFridge = await _createFridge(database, homeName: 'Hamburg');
    final stockItems = StockItemRepository(database);
    await stockItems.addStockItemForProduct(
      milk.productId,
      _draft(hamburgFridge),
    );
    final butter = await _addToNewHome(
      database,
      homeName: 'München',
      productName: 'Butter',
    );

    await repository.deleteProduct(milk.productId);

    expect(await repository.getProduct(milk.productId), isNull);
    expect(await database.select(database.stockItems).get(), [
      isA<StockItemRow>().having((row) => row.id, 'id', butter.id),
    ]);
    expect(await repository.getProducts(), [
      Product(id: butter.productId, name: 'Butter'),
    ]);
  });

  test('a product without stock items can be deleted', () async {
    final milk = await _addToNewHome(
      database,
      homeName: 'Berlin',
      productName: 'Milch',
    );
    await StockItemRepository(database).deleteStockItem(milk.id);

    await repository.deleteProduct(milk.productId);

    expect(await repository.getProducts(), isEmpty);
  });
}
