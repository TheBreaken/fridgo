import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:fridgo/domain/product_search.dart';
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

  Future<String?> pickPhoto(PhotoSource source) =>
      ref.read(productImageRepositoryProvider).pickPhoto(source);

  Future<List<Product>> findProducts(String query) async => searchProducts(
    await ref.read(productRepositoryProvider).getProducts(),
    query,
  );

  Future<void> addStockItemWithNewProduct(
    StockItemDraft draft, {
    required String productName,
    String? pickedPhotoPath,
  }) async {
    if (!isValidName(productName)) {
      throw ArgumentError.value(
        productName,
        'productName',
        'must not be blank',
      );
    }
    _checkQuantity(draft);
    final productImages = ref.read(productImageRepositoryProvider);
    final imagePath = pickedPhotoPath == null
        ? null
        : await productImages.store(pickedPhotoPath);
    try {
      await ref
          .read(stockItemRepositoryProvider)
          .addStockItemWithNewProduct(
            draft,
            productName: productName.trim(),
            imagePath: imagePath,
          );
    } on Object {
      if (imagePath != null) await productImages.delete(imagePath);
      rethrow;
    }
  }

  Future<void> addStockItemForProduct(
    String productId,
    StockItemDraft draft,
  ) async {
    _checkQuantity(draft);
    await ref
        .read(stockItemRepositoryProvider)
        .addStockItemForProduct(productId, draft);
  }

  void _checkQuantity(StockItemDraft draft) {
    if (draft.quantity <= 0) {
      throw ArgumentError.value(draft.quantity, 'quantity', 'must be above 0');
    }
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
