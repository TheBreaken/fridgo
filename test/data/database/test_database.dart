import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fridgo/data/database/app_database.dart';

// Widget tests run in FakeAsync. Without synchronous closing, drift cleans up
// stream queries with a zero-duration timer that outlives the widget tree.
AppDatabase createWidgetTestDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
