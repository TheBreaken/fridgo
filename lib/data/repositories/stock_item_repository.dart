import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:uuid/uuid.dart';

class StockItemRepository {
  new(this._database);

  final AppDatabase _database;

  Future<StockItem> addStockItemWithNewProduct(StockItemDraft draft) {
    final product = Product(id: const Uuid().v4(), name: draft.productName);
    final stockItem = StockItem(
      id: const Uuid().v4(),
      productId: product.id,
      storageLocationId: draft.storageLocationId,
      quantity: draft.quantity,
      unit: draft.unit,
      bestBeforeDate: draft.bestBeforeDate,
      openedDate: draft.openedDate,
    );
    return _database.transaction(() async {
      await _database
          .into(_database.products)
          .insert(ProductsCompanion.insert(id: product.id, name: product.name));
      await _database
          .into(_database.stockItems)
          .insert(
            StockItemsCompanion.insert(
              id: stockItem.id,
              productId: stockItem.productId,
              storageLocationId: stockItem.storageLocationId,
              quantity: stockItem.quantity,
              unit: stockItem.unit,
              bestBeforeDate: Value(stockItem.bestBeforeDate),
              openedDate: Value(stockItem.openedDate),
            ),
          );
      return stockItem;
    });
  }

  Stream<List<StockItemDetails>> watchStockItems(String homeId) {
    final stockItems = _database.stockItems;
    final products = _database.products;
    final storageLocations = _database.storageLocations;
    final query =
        _database.select(stockItems).join([
            innerJoin(products, products.id.equalsExp(stockItems.productId)),
            innerJoin(
              storageLocations,
              storageLocations.id.equalsExp(stockItems.storageLocationId),
            ),
          ])
          ..where(storageLocations.homeId.equals(homeId))
          ..orderBy([
            OrderingTerm.asc(products.name.collate(Collate.noCase)),
            OrderingTerm.asc(stockItems.id),
          ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          _toDetails(
            row.readTable(stockItems),
            row.readTable(products),
            row.readTable(storageLocations),
          ),
      ],
    );
  }

  StockItemDetails _toDetails(
    StockItemRow stockItem,
    ProductRow product,
    StorageLocationRow storageLocation,
  ) => StockItemDetails(
    stockItem: StockItem(
      id: stockItem.id,
      productId: stockItem.productId,
      storageLocationId: stockItem.storageLocationId,
      quantity: stockItem.quantity,
      unit: stockItem.unit,
      bestBeforeDate: stockItem.bestBeforeDate,
      openedDate: stockItem.openedDate,
    ),
    product: Product(id: product.id, name: product.name),
    storageLocation: StorageLocation(
      id: storageLocation.id,
      homeId: storageLocation.homeId,
      name: storageLocation.name,
      kind: storageLocation.kind,
    ),
  );
}

final stockItemRepositoryProvider = Provider<StockItemRepository>(
  (ref) => StockItemRepository(ref.watch(appDatabaseProvider)),
);
