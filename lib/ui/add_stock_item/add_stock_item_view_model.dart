import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';

class AddStockItemViewModel extends StreamNotifier<List<StorageLocation>> {
  new(this.homeId);

  final String homeId;

  static final _quantityPattern = RegExp(r'^(\d+|\d*[.,]\d{1,3})$');

  @override
  Stream<List<StorageLocation>> build() => ref
      .watch(storageLocationRepositoryProvider)
      .watchStorageLocations(homeId);

  CalendarDate get today =>
      CalendarDate.fromDateTime(ref.read(clockProvider)());

  bool isValidName(String name) => name.trim().isNotEmpty;

  bool isValidQuantity(String quantity) =>
      _quantityPattern.hasMatch(quantity.trim()) && _toDouble(quantity) > 0;

  double parseQuantity(String quantity) {
    if (!isValidQuantity(quantity)) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'must be above 0 with at most three decimals',
      );
    }
    return _toDouble(quantity);
  }

  Future<void> addStockItem(StockItemDraft draft) async {
    if (!isValidName(draft.productName)) {
      throw ArgumentError.value(
        draft.productName,
        'productName',
        'must not be blank',
      );
    }
    if (draft.quantity <= 0) {
      throw ArgumentError.value(draft.quantity, 'quantity', 'must be above 0');
    }
    await ref
        .read(stockItemRepositoryProvider)
        .addStockItemWithNewProduct(
          draft.copyWith(productName: draft.productName.trim()),
        );
  }

  double _toDouble(String quantity) =>
      double.parse(quantity.trim().replaceFirst(',', '.'));
}

final StreamNotifierProviderFamily<
  AddStockItemViewModel,
  List<StorageLocation>,
  String
>
addStockItemViewModelProvider = StreamNotifierProvider.autoDispose.family(
  AddStockItemViewModel.new,
);
