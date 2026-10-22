import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/stock_quantity.dart';

class EditStockItemViewModel {
  new(this._stockItems, this._clock);

  final StockItemRepository _stockItems;
  final DateTime Function() _clock;

  CalendarDate get today => CalendarDate.fromDateTime(_clock());

  bool isValidQuantity(String quantity) => isValidQuantityInput(quantity);

  double parseQuantity(String quantity) => parseQuantityInput(quantity);

  Future<void> save(StockItem stockItem) async {
    if (stockItem.quantity <= 0) {
      throw ArgumentError.value(
        stockItem.quantity,
        'quantity',
        'must be above 0',
      );
    }
    await _stockItems.updateStockItem(stockItem);
  }
}

final editStockItemViewModelProvider = Provider<EditStockItemViewModel>(
  (ref) => EditStockItemViewModel(
    ref.watch(stockItemRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
