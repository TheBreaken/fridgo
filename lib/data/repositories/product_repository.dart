import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/domain/product.dart';

class ProductRepository {
  new(this._database);

  final AppDatabase _database;

  Future<List<Product>> getProducts() async {
    final rows = await _database.select(_database.products).get();
    return [
      for (final row in rows)
        Product(id: row.id, name: row.name, imagePath: row.imagePath),
    ];
  }
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(appDatabaseProvider)),
);
