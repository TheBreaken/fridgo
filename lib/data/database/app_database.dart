import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/data/database/app_database.steps.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
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

@DataClassName('ProductRow')
@TableIndex(name: 'products_barcode', columns: {#barcode}, unique: true)
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get imagePath => text().nullable()();
  RealColumn get energyKcal => real().nullable()();
  RealColumn get fat => real().nullable()();
  RealColumn get saturatedFat => real().nullable()();
  RealColumn get carbohydrates => real().nullable()();
  RealColumn get sugars => real().nullable()();
  RealColumn get protein => real().nullable()();
  RealColumn get salt => real().nullable()();
  TextColumn get barcode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StockItemRow')
class StockItems extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get storageLocationId =>
      text().references(StorageLocations, #id)();
  RealColumn get quantity => real()();
  TextColumn get unit => textEnum<StockUnit>()();
  TextColumn get bestBeforeDate =>
      text().nullable().map(const CalendarDateConverter())();
  TextColumn get openedDate =>
      text().nullable().map(const CalendarDateConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// Calendar dates are stored as 'YYYY-MM-DD' text instead of drift's
// timestamps, so the stored day never depends on the device's time zone.
class CalendarDateConverter extends TypeConverter<CalendarDate, String> {
  const new();

  @override
  CalendarDate fromSql(String fromDb) => CalendarDate.parse(fromDb);

  @override
  String toSql(CalendarDate value) => value.toIso8601String();
}

@DriftDatabase(tables: [Homes, StorageLocations, Products, StockItems])
class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) => m.createTable(schema.storageLocations),
      from2To3: (m, schema) async {
        await m.createTable(schema.products);
        await m.createTable(schema.stockItems);
      },
      from3To4: (m, schema) =>
          m.addColumn(schema.products, schema.products.imagePath),
      from4To5: (m, schema) async {
        final products = schema.products;
        for (final column in [
          products.energyKcal,
          products.fat,
          products.saturatedFat,
          products.carbohydrates,
          products.sugars,
          products.protein,
          products.salt,
        ]) {
          await m.addColumn(products, column);
        }
      },
      // SQLite cannot add a UNIQUE column, so the index comes separately.
      from5To6: (m, schema) async {
        await m.addColumn(schema.products, schema.products.barcode);
        await m.createIndex(schema.productsBarcode);
      },
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
