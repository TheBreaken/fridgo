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

  Stream<List<Home>> watchHomes() {
    final query = _database.select(_database.homes)
      ..orderBy([
        (homes) => OrderingTerm.asc(homes.name.collate(Collate.noCase)),
      ]);
    return query.watch().map(
      (rows) => [for (final row in rows) Home(id: row.id, name: row.name)],
    );
  }
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(appDatabaseProvider)),
);
