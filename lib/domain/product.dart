import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const factory({required String id, required String name}) = _Product;
}
