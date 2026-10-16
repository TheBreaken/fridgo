import 'package:freezed_annotation/freezed_annotation.dart';

part 'storage_location.freezed.dart';

enum StorageLocationKind { refrigerator, freezer, pantry, cellar, other }

@freezed
abstract class StorageLocation with _$StorageLocation {
  const factory({
    required String id,
    required String homeId,
    required String name,
    required StorageLocationKind kind,
  }) = _StorageLocation;
}
