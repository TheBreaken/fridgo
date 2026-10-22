import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';

class ProductRepository {
  new(this._database);

  final AppDatabase _database;

  Future<List<Product>> getProducts() async {
    final rows = await _database.select(_database.products).get();
    return [for (final row in rows) productFromRow(row)];
  }
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
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(appDatabaseProvider)),
);
