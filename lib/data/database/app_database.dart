import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.steps.dart';
import 'package:fridgo/domain/storage_location.dart';

part 'app_database.g.dart';

@DataClassName('HomeRow')
class Homes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StorageLocationRow')
class StorageLocations extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text().references(Homes, #id)();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<StorageLocationKind>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Homes, StorageLocations])
class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) => m.createTable(schema.storageLocations),
    ),
    // SQLite enforces foreign keys only when this is set on each connection.
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(driftDatabase(name: 'fridgo'));
  ref.onDispose(database.close);
  return database;
});
