import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/domain/home.dart';
import 'package:uuid/uuid.dart';

class HomeRepository {
  new(this._database);

  final AppDatabase _database;

  Future<Home> createHome(String name) async {
    final home = Home(id: const Uuid().v4(), name: name);
    await _database
        .into(_database.homes)
        .insert(HomesCompanion.insert(id: home.id, name: home.name));
    return home;
  }

  Future<List<Home>> getHomes() async => _toHomes(await _homesQuery().get());

  Stream<List<Home>> watchHomes() => _homesQuery().watch().map(_toHomes);

  SimpleSelectStatement<$HomesTable, HomeRow> _homesQuery() => _database.select(
    _database.homes,
  )..orderBy([(homes) => OrderingTerm.asc(homes.name.collate(Collate.noCase))]);

  List<Home> _toHomes(List<HomeRow> rows) => [
    for (final row in rows) Home(id: row.id, name: row.name),
  ];

  Stream<Home> watchHome(String id) {
    final query = _database.select(_database.homes)
      ..where((homes) => homes.id.equals(id));
    return query.watchSingle().map((row) => Home(id: row.id, name: row.name));
  }

  Future<void> updateHome(Home home) async {
    final updated = await _database
        .update(_database.homes)
        .replace(HomesCompanion.insert(id: home.id, name: home.name));
    if (!updated) {
      throw StateError('No home with id ${home.id} to update');
    }
  }

  Future<int> countStockItems(String homeId) async {
    final stockItems = _database.stockItems;
    final storageLocations = _database.storageLocations;
    final count = stockItems.id.count();
    final query =
        _database.selectOnly(stockItems).join([
            innerJoin(
              storageLocations,
              storageLocations.id.equalsExp(stockItems.storageLocationId),
              useColumns: false,
            ),
          ])
          ..addColumns([count])
          ..where(storageLocations.homeId.equals(homeId));
    final row = await query.getSingle();
    return row.read<int>(count)!;
  }

  /// Deletes the home with its storage locations and their stock items. The
  /// products stay.
  Future<void> deleteHome(String id) => _database.transaction(() async {
    final storageLocations = _database.storageLocations;
    final storageLocationIds = _database.selectOnly(storageLocations)
      ..addColumns([storageLocations.id])
      ..where(storageLocations.homeId.equals(id));
    await (_database.delete(_database.stockItems)..where(
          (stockItem) =>
              stockItem.storageLocationId.isInQuery(storageLocationIds),
        ))
        .go();
    await (_database.delete(
      storageLocations,
    )..where((storageLocation) => storageLocation.homeId.equals(id))).go();
    await (_database.delete(
      _database.homes,
    )..where((home) => home.id.equals(id))).go();
  });
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(appDatabaseProvider)),
);
