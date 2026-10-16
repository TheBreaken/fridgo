import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/domain/stock_item.dart';

final StreamProviderFamily<List<StockItemDetails>, String>
stockOverviewProvider = StreamProvider.autoDispose.family(
  (ref, homeId) =>
      ref.watch(stockItemRepositoryProvider).watchStockItems(homeId),
);
