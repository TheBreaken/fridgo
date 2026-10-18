import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';

Future<StockItem> _addToNewHome(
  AppDatabase database, {
  required String homeName,
  required String productName,
  String? imagePath,
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
  );
}

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
}
