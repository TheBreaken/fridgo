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
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(appDatabaseProvider)),
);
