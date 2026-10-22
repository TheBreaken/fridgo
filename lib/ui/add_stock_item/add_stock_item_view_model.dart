import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:fridgo/domain/product_search.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/stock_quantity.dart';
import 'package:fridgo/domain/storage_location.dart';

class AddStockItemViewModel extends StreamNotifier<List<StorageLocation>> {
  new(this.homeId);

  final String homeId;

  @override
  Stream<List<StorageLocation>> build() => ref
      .watch(storageLocationRepositoryProvider)
      .watchStorageLocations(homeId);

  CalendarDate get today =>
      CalendarDate.fromDateTime(ref.read(clockProvider)());

  bool isValidName(String name) => isValidProductName(name);

  bool isValidQuantity(String quantity) => isValidQuantityInput(quantity);

  double parseQuantity(String quantity) => parseQuantityInput(quantity);

  bool isValidNutrient(String input, Nutrient nutrient) =>
      isValidNutrientInput(input, nutrient);

  double? parseNutrient(String input, Nutrient nutrient) =>
      parseNutrientInput(input, nutrient);

  Future<String?> pickPhoto(PhotoSource source) =>
      ref.read(productImageRepositoryProvider).pickPhoto(source);

  Future<List<Product>> findProducts(String query) async => searchProducts(
    await ref.read(productRepositoryProvider).getProducts(),
    query,
  );

  Future<Product?> getProduct(String id) =>
      ref.read(productRepositoryProvider).getProduct(id);

  Future<void> addStockItemWithNewProduct(
    StockItemDraft draft, {
    required String productName,
    String? pickedPhotoPath,
    Map<Nutrient, double> nutritionFacts = const {},
  }) async {
    if (!isValidName(productName)) {
      throw ArgumentError.value(
        productName,
        'productName',
        'must not be blank',
      );
    }
    _checkQuantity(draft);
    checkNutritionFacts(nutritionFacts);
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
            nutritionFacts: nutritionFacts,
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
}

final StreamNotifierProviderFamily<
  AddStockItemViewModel,
  List<StorageLocation>,
  String
>
addStockItemViewModelProvider = StreamNotifierProvider.autoDispose.family(
  AddStockItemViewModel.new,
);
