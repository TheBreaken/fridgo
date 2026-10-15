import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';

import 'generated/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('a new database matches the stored schema version 1', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 1);
  });
}
