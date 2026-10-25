import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fridgo/domain/nutrient.dart';

part 'product_lookup.freezed.dart';

/// What a product database knows about a barcode; any part may be missing.
@freezed
abstract class ProductFacts with _$ProductFacts {
  const factory({
    String? name,

    // Per 100 g or 100 ml, energy in kcal.
    @Default(<Nutrient, double>{}) Map<Nutrient, double> nutritionFacts,
  }) = _ProductFacts;
}

sealed class ProductLookupException implements Exception {
  const new(this.barcode);

  final String barcode;
}

class ProductNotFoundException extends ProductLookupException {
  const new(super.barcode);

  @override
  String toString() => 'ProductNotFoundException: no product with $barcode';
}

/// No answer: no network, a timeout or a broken response.
class ProductLookupFailedException extends ProductLookupException {
  const new(super.barcode, this.reason);

  final String reason;

  @override
  String toString() =>
      'ProductLookupFailedException: looking up $barcode failed with $reason';
}
