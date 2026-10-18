import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/stock_quantity.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:uuid/uuid.dart';

class StockItemRepository {
  new(this._database);

  final AppDatabase _database;

  Future<StockItem> addStockItemWithNewProduct(
    StockItemDraft draft, {
    required String productName,
    String? imagePath,
  }) => _database.transaction(() async {
    final productId = const Uuid().v4();
    await _database
        .into(_database.products)
        .insert(
          ProductsCompanion.insert(
            id: productId,
            name: productName,
            imagePath: Value(imagePath),
          ),
        );
    return await addStockItemForProduct(productId, draft);
  });

  Future<StockItem> addStockItemForProduct(
    String productId,
    StockItemDraft draft,
  ) async {
    final stockItem = StockItem(
      id: const Uuid().v4(),
      productId: productId,
      storageLocationId: draft.storageLocationId,
      quantity: draft.quantity,
      unit: draft.unit,
      bestBeforeDate: draft.bestBeforeDate,
      openedDate: draft.openedDate,
    );
    await _database.into(_database.stockItems).insert(_toCompanion(stockItem));
    return stockItem;
  }

  /// Lowers the quantity by [consumed]; a stock item used up is deleted.
  Future<void> consumeStockItem(String id, double consumed) =>
      _database.transaction(() async {
        final stockItems = _database.stockItems;
        final row = await (_database.select(
          stockItems,
        )..where((stockItem) => stockItem.id.equals(id))).getSingle();
        final remaining = quantityAfterConsuming(row.quantity, consumed);
        if (remaining == 0) {
          await deleteStockItem(id);
          return;
        }
        await (_database.update(stockItems)
              ..where((stockItem) => stockItem.id.equals(id)))
            .write(StockItemsCompanion(quantity: Value(remaining)));
      });

  Future<void> deleteStockItem(String id) => (_database.delete(
    _database.stockItems,
  )..where((stockItem) => stockItem.id.equals(id))).go();

  /// Writes [stockItem] back as it was, whether it still exists or not.
  Future<void> restoreStockItem(StockItem stockItem) => _database
      .into(_database.stockItems)
      .insertOnConflictUpdate(_toCompanion(stockItem));

  StockItemsCompanion _toCompanion(StockItem stockItem) =>
      StockItemsCompanion.insert(
        id: stockItem.id,
        productId: stockItem.productId,
        storageLocationId: stockItem.storageLocationId,
        quantity: stockItem.quantity,
        unit: stockItem.unit,
        bestBeforeDate: Value(stockItem.bestBeforeDate),
        openedDate: Value(stockItem.openedDate),
      );

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
            OrderingTerm.asc(stockItems.bestBeforeDate, nulls: NullsOrder.last),
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
    product: Product(
      id: product.id,
      name: product.name,
      imagePath: product.imagePath,
    ),
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
