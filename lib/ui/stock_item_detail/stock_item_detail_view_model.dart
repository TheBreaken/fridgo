import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_view_model.dart';

typedef StockItemKey = ({String homeId, String stockItemId});

// Picked from the overview, which is loaded already: the photo can only fly
// from the card if the details are there in the first frame.
final ProviderFamily<AsyncValue<StockItemDetails?>, StockItemKey>
stockItemDetailsProvider = Provider.autoDispose.family(
  (ref, key) => ref
      .watch(stockOverviewProvider(key.homeId))
      .whenData(
        (stockItems) => stockItems
            .where((details) => details.stockItem.id == key.stockItemId)
            .firstOrNull,
      ),
);

class StockItemDetailViewModel {
  new(this._stockItems, this._clock);

  final StockItemRepository _stockItems;
  final DateTime Function() _clock;

  Future<void> markOpenedToday(StockItem stockItem) =>
      _stockItems.updateStockItem(
        stockItem.copyWith(openedDate: CalendarDate.fromDateTime(_clock())),
      );

  Future<void> delete(StockItem stockItem) =>
      _stockItems.deleteStockItem(stockItem.id);
}

final stockItemDetailViewModelProvider = Provider<StockItemDetailViewModel>(
  (ref) => StockItemDetailViewModel(
    ref.watch(stockItemRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
