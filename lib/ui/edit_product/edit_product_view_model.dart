import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/product_photo.dart';

typedef EditableProduct = ({Product product, ProductStock stock});

final FutureProviderFamily<EditableProduct?, String> editableProductProvider =
    FutureProvider.autoDispose.family((ref, productId) async {
      final products = ref.watch(productRepositoryProvider);
      final product = await products.getProduct(productId);
      if (product == null) return null;
      return (
        product: product,
        stock: await products.getProductStock(productId),
      );
    });

class EditProductViewModel {
  new(this._products, this._productImages);

  final ProductRepository _products;
  final ProductImageRepository _productImages;

  bool isValidName(String name) => isValidProductName(name);

  bool isValidNutrient(String input, Nutrient nutrient) =>
      isValidNutrientInput(input, nutrient);

  double? parseNutrient(String input, Nutrient nutrient) =>
      parseNutrientInput(input, nutrient);

  Future<String?> pickPhoto(PhotoSource source) =>
      _productImages.pickPhoto(source);

  /// Saves [product], with [pickedPhotoPath] as its new photo if given, and
  /// deletes the image file the product no longer uses.
  Future<void> save(Product product, {String? pickedPhotoPath}) async {
    if (!isValidName(product.name)) {
      throw ArgumentError.value(product.name, 'name', 'must not be blank');
    }
    checkNutritionFacts(product.nutritionFacts);
    final previousImagePath = (await _products.getProduct(product.id))
        ?.imagePath;
    final storedImagePath = pickedPhotoPath == null
        ? null
        : await _productImages.store(pickedPhotoPath);
    final saved = product.copyWith(
      name: product.name.trim(),
      imagePath: storedImagePath ?? product.imagePath,
    );
    try {
      await _products.updateProduct(saved);
    } on Object {
      if (storedImagePath != null) await _productImages.delete(storedImagePath);
      rethrow;
    }
    if (previousImagePath != null && previousImagePath != saved.imagePath) {
      await _productImages.delete(previousImagePath);
    }
  }

  /// Deletes the product, all its stock items and its image file.
  Future<void> delete(Product product) async {
    await _products.deleteProduct(product.id);
    final imagePath = product.imagePath;
    if (imagePath != null) await _productImages.delete(imagePath);
  }
}

final editProductViewModelProvider = Provider<EditProductViewModel>(
  (ref) => EditProductViewModel(
    ref.watch(productRepositoryProvider),
    ref.watch(productImageRepositoryProvider),
  ),
);
