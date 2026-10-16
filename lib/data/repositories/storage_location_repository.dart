import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:uuid/uuid.dart';

class StorageLocationRepository {
  new(this._database);

  final AppDatabase _database;

  Future<StorageLocation> createStorageLocation({
    required String homeId,
    required String name,
    required StorageLocationKind kind,
  }) async {
    final storageLocation = StorageLocation(
      id: const Uuid().v4(),
      homeId: homeId,
      name: name,
      kind: kind,
    );
    await _database
        .into(_database.storageLocations)
        .insert(
          StorageLocationsCompanion.insert(
            id: storageLocation.id,
            homeId: storageLocation.homeId,
            name: storageLocation.name,
            kind: storageLocation.kind,
          ),
        );
    return storageLocation;
  }

  Stream<List<StorageLocation>> watchStorageLocations(String homeId) {
    final query = _database.select(_database.storageLocations)
      ..where((storageLocations) => storageLocations.homeId.equals(homeId))
      ..orderBy([
        (storageLocations) =>
            OrderingTerm.asc(storageLocations.name.collate(Collate.noCase)),
      ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          StorageLocation(
            id: row.id,
            homeId: row.homeId,
            name: row.name,
            kind: row.kind,
          ),
      ],
    );
  }
}

final storageLocationRepositoryProvider = Provider<StorageLocationRepository>(
  (ref) => StorageLocationRepository(ref.watch(appDatabaseProvider)),
);
