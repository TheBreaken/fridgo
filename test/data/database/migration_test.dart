import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/storage_location.dart';

import 'generated/schema.dart';

const _homeId = '6f1c2a4e-1b7d-4c8e-9a3f-2d5e8b7c1a90';
const _storageLocationId = '0b8e5d2c-7a41-4f3e-b6c9-1d2e3f4a5b6c';
const _productId = '3a2b1c0d-9e8f-4a7b-b6c5-d4e3f2a1b0c9';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('a new database matches the stored schema version 4', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
  });

  for (final version in [1, 2, 3]) {
    test(
      'upgrading from version $version gives the stored schema version 4',
      () async {
        final schema = await verifier.schemaAt(version);
        final database = AppDatabase(schema.newConnection());
        addTearDown(database.close);

        await verifier.migrateAndValidate(database, 4);
      },
    );
  }

  test('upgrading from version 1 keeps the existing homes', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute('INSERT INTO homes (id, name) VALUES (?, ?)', [
      _homeId,
      'Berlin',
    ]);
    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);

    expect(await HomeRepository(database).watchHomes().first, [
      const Home(id: _homeId, name: 'Berlin'),
    ]);
  });

  test(
    'upgrading from version 2 keeps the existing storage locations',
    () async {
      final schema = await verifier.schemaAt(2);
      schema.rawDatabase
        ..execute('INSERT INTO homes (id, name) VALUES (?, ?)', [
          _homeId,
          'Berlin',
        ])
        ..execute(
          'INSERT INTO storage_locations (id, home_id, name, kind) '
          'VALUES (?, ?, ?, ?)',
          [_storageLocationId, _homeId, 'Vorrat', 'pantry'],
        );
      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);

      await verifier.migrateAndValidate(database, 4);

      expect(
        await StorageLocationRepository(database)
            .watchStorageLocations(_homeId)
            .first,
        [
          const StorageLocation(
            id: _storageLocationId,
            homeId: _homeId,
            name: 'Vorrat',
            kind: StorageLocationKind.pantry,
          ),
        ],
      );
    },
  );

  test(
    'upgrading from version 3 keeps the products without image path',
    () async {
      final schema = await verifier.schemaAt(3);
      schema.rawDatabase
        ..execute('INSERT INTO homes (id, name) VALUES (?, ?)', [
          _homeId,
          'Berlin',
        ])
        ..execute(
          'INSERT INTO storage_locations (id, home_id, name, kind) '
          'VALUES (?, ?, ?, ?)',
          [_storageLocationId, _homeId, 'Vorrat', 'pantry'],
        )
        ..execute('INSERT INTO products (id, name) VALUES (?, ?)', [
          _productId,
          'Nudeln',
        ])
        ..execute(
          'INSERT INTO stock_items '
          '(id, product_id, storage_location_id, quantity, unit) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            '9d4c3b2a-1e0f-4a5b-8c7d-6e5f4a3b2c1d',
            _productId,
            _storageLocationId,
            500.0,
            'gram',
          ],
        );
      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);

      await verifier.migrateAndValidate(database, 4);

      final listed = await StockItemRepository(database)
          .watchStockItems(_homeId)
          .first;
      expect(
        listed.single.product,
        const Product(id: _productId, name: 'Nudeln'),
      );
      expect(listed.single.stockItem.quantity, 500);
    },
  );
}
