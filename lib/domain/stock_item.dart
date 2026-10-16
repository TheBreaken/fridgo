import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/storage_location.dart';

part 'stock_item.freezed.dart';

enum StockUnit { piece, gram, kilogram, milliliter, liter, package }

@freezed
abstract class StockItem with _$StockItem {
  const factory({
    required String id,
    required String productId,
    required String storageLocationId,
    required double quantity,
    required StockUnit unit,
    CalendarDate? bestBeforeDate,
    CalendarDate? openedDate,
  }) = _StockItem;
}

/// What the user enters to add a new product as stock.
@freezed
abstract class StockItemDraft with _$StockItemDraft {
  const factory({
    required String productName,
    required String storageLocationId,
    required double quantity,
    required StockUnit unit,
    CalendarDate? bestBeforeDate,
    CalendarDate? openedDate,
  }) = _StockItemDraft;
}

/// A stock item together with its product and storage location.
@freezed
abstract class StockItemDetails with _$StockItemDetails {
  const factory({
    required StockItem stockItem,
    required Product product,
    required StorageLocation storageLocation,
  }) = _StockItemDetails;
}
