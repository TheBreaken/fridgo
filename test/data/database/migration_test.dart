import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/domain/storage_location.dart';

import 'generated/schema.dart';

const _homeId = '6f1c2a4e-1b7d-4c8e-9a3f-2d5e8b7c1a90';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('a new database matches the stored schema version 3', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 3);
  });

  for (final version in [1, 2]) {
    test(
      'upgrading from version $version gives the stored schema version 3',
      () async {
        final schema = await verifier.schemaAt(version);
        final database = AppDatabase(schema.newConnection());
        addTearDown(database.close);

        await verifier.migrateAndValidate(database, 3);
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

    await verifier.migrateAndValidate(database, 3);

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
          ['0b8e5d2c-7a41-4f3e-b6c9-1d2e3f4a5b6c', _homeId, 'Vorrat', 'pantry'],
        );
      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);

      await verifier.migrateAndValidate(database, 3);

      expect(
        await StorageLocationRepository(database)
            .watchStorageLocations(_homeId)
            .first,
        [
          const StorageLocation(
            id: '0b8e5d2c-7a41-4f3e-b6c9-1d2e3f4a5b6c',
            homeId: _homeId,
            name: 'Vorrat',
            kind: StorageLocationKind.pantry,
          ),
        ],
      );
    },
  );
}
