import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/domain/storage_location.dart';

class StorageLocationsViewModel extends StreamNotifier<List<StorageLocation>> {
  new(this.homeId);

  final String homeId;

  @override
  Stream<List<StorageLocation>> build() => ref
      .watch(storageLocationRepositoryProvider)
      .watchStorageLocations(homeId);

  bool isValidName(String name) => name.trim().isNotEmpty;

  Future<void> createStorageLocation(
    String name,
    StorageLocationKind kind,
  ) async {
    if (!isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    await ref
        .read(storageLocationRepositoryProvider)
        .createStorageLocation(homeId: homeId, name: name.trim(), kind: kind);
  }
}

final StreamNotifierProviderFamily<
  StorageLocationsViewModel,
  List<StorageLocation>,
  String
>
storageLocationsViewModelProvider = StreamNotifierProvider.autoDispose.family(
  StorageLocationsViewModel.new,
);

final StreamProviderFamily<Home, String> homeProvider = StreamProvider
    .autoDispose
    .family((ref, id) => ref.watch(homeRepositoryProvider).watchHome(id));
