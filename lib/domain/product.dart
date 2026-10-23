import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fridgo/domain/nutrient.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const factory({
    required String id,
    required String name,

    // Relative to the app directory; the absolute path changes between
    // installs, for example after a restore on another device.
    String? imagePath,

    // Per 100 g or 100 ml, energy in kcal.
    @Default(<Nutrient, double>{}) Map<Nutrient, double> nutritionFacts,

    // At most one product per barcode.
    String? barcode,
  }) = _Product;
}

bool isValidProductName(String name) => name.trim().isNotEmpty;
