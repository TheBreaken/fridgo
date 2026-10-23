import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';

/// The homes are sorted by name and listed once each.
typedef ProductStock = ({int stockItemCount, List<String> homeNames});

class ProductRepository {
  new(this._database);

  final AppDatabase _database;

  Future<List<Product>> getProducts() async {
    final rows = await _database.select(_database.products).get();
    return [for (final row in rows) productFromRow(row)];
  }

  Future<Product?> getProduct(String id) async {
    final row = await (_database.select(
      _database.products,
    )..where((product) => product.id.equals(id))).getSingleOrNull();
    return row == null ? null : productFromRow(row);
  }

  Future<Product?> findProductByBarcode(String barcode) async {
    final row = await (_database.select(
      _database.products,
    )..where((product) => product.barcode.equals(barcode))).getSingleOrNull();
    return row == null ? null : productFromRow(row);
  }

  Future<ProductStock> getProductStock(String productId) async {
    final stockItems = _database.stockItems;
    final storageLocations = _database.storageLocations;
    final homes = _database.homes;
    final query =
        _database.select(stockItems).join([
            innerJoin(
              storageLocations,
              storageLocations.id.equalsExp(stockItems.storageLocationId),
            ),
            innerJoin(homes, homes.id.equalsExp(storageLocations.homeId)),
          ])
          ..where(stockItems.productId.equals(productId))
          ..orderBy([OrderingTerm.asc(homes.name.collate(Collate.noCase))]);
    final rows = await query.get();
    return (
      stockItemCount: rows.length,
      homeNames: {for (final row in rows) row.readTable(homes).name}.toList(),
    );
  }

  Future<void> updateProduct(Product product) async {
    final updated = await _database
        .update(_database.products)
        .replace(productToCompanion(product));
    if (!updated) {
      throw StateError('No product with id ${product.id} to update');
    }
  }

  /// Deletes the product together with all its stock items in every home.
  Future<void> deleteProduct(String id) => _database.transaction(() async {
    await (_database.delete(
      _database.stockItems,
    )..where((stockItem) => stockItem.productId.equals(id))).go();
    await (_database.delete(
      _database.products,
    )..where((product) => product.id.equals(id))).go();
  });
}

Product productFromRow(ProductRow row) => Product(
  id: row.id,
  name: row.name,
  imagePath: row.imagePath,
  nutritionFacts: {
    Nutrient.energy: ?row.energyKcal,
    Nutrient.fat: ?row.fat,
    Nutrient.saturatedFat: ?row.saturatedFat,
    Nutrient.carbohydrates: ?row.carbohydrates,
    Nutrient.sugars: ?row.sugars,
    Nutrient.protein: ?row.protein,
    Nutrient.salt: ?row.salt,
  },
  barcode: row.barcode,
);

ProductsCompanion productToCompanion(Product product) {
  final nutritionFacts = product.nutritionFacts;
  return ProductsCompanion.insert(
    id: product.id,
    name: product.name,
    imagePath: Value(product.imagePath),
    energyKcal: Value(nutritionFacts[Nutrient.energy]),
    fat: Value(nutritionFacts[Nutrient.fat]),
    saturatedFat: Value(nutritionFacts[Nutrient.saturatedFat]),
    carbohydrates: Value(nutritionFacts[Nutrient.carbohydrates]),
    sugars: Value(nutritionFacts[Nutrient.sugars]),
    protein: Value(nutritionFacts[Nutrient.protein]),
    salt: Value(nutritionFacts[Nutrient.salt]),
    barcode: Value(product.barcode),
  );
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(appDatabaseProvider)),
);
