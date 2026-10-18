import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/stock_quantity.dart';

class ConsumeStockItemViewModel {
  new(this._stockItems);

  final StockItemRepository _stockItems;

  String initialConsumedInput(StockUnit unit) => switch (unit) {
    StockUnit.piece || StockUnit.package => '1',
    StockUnit.gram ||
    StockUnit.kilogram ||
    StockUnit.milliliter ||
    StockUnit.liter => '',
  };

  bool isValidQuantity(String input) => isValidQuantityInput(input);

  double parseQuantity(String input) => parseQuantityInput(input);

  Future<void> consume(StockItem stockItem, String consumedInput) async {
    final consumed = parseQuantityInput(consumedInput);
    await _stockItems.consumeStockItem(stockItem.id, consumed);
  }

  Future<void> consumeCompletely(StockItem stockItem) =>
      _stockItems.deleteStockItem(stockItem.id);

  Future<void> undo(StockItem previous) =>
      _stockItems.restoreStockItem(previous);
}

final consumeStockItemViewModelProvider = Provider<ConsumeStockItemViewModel>(
  (ref) => ConsumeStockItemViewModel(ref.watch(stockItemRepositoryProvider)),
);
