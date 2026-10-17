import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const factory({
    required String id,
    required String name,

    // Relative to the app directory; the absolute path changes between
    // installs, for example after a restore on another device.
    String? imagePath,
  }) = _Product;
}
