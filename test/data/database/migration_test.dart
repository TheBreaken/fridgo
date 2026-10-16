import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/domain/home.dart';

import 'generated/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('a new database matches the stored schema version 2', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);
  });

  test('upgrading from version 1 gives the stored schema version 2', () async {
    final schema = await verifier.schemaAt(1);
    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);
  });

  test('upgrading from version 1 keeps the existing homes', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute('INSERT INTO homes (id, name) VALUES (?, ?)', [
      '6f1c2a4e-1b7d-4c8e-9a3f-2d5e8b7c1a90',
      'Berlin',
    ]);
    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);

    expect(await HomeRepository(database).watchHomes().first, [
      const Home(id: '6f1c2a4e-1b7d-4c8e-9a3f-2d5e8b7c1a90', name: 'Berlin'),
    ]);
  });
}
