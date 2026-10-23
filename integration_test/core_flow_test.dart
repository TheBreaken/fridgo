import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/app/app.dart';
import 'package:fridgo/data/barcode_scanner.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/last_home_repository.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/data/fake_barcode_scanner.dart';
import '../test/data/repositories/fake_last_home_repository.dart';
import '../test/ui/app_flows.dart';

// The test app replaces the installed app, so the test keeps its own database
// file and never touches fridgo.sqlite or the stored preferences.
Future<File> _createDatabaseFile() async {
  final file = File(
    '${(await getTemporaryDirectory()).path}/core_flow_test.sqlite',
  );
  if (file.existsSync()) await file.delete();
  addTearDown(() async {
    if (file.existsSync()) await file.delete();
  });
  return file;
}

// Not in a background isolate like the app: pumpAndSettle does not wait for
// its answers, so on a slow start the first screen is not built yet.
AppDatabase _openDatabase(File file) => AppDatabase(NativeDatabase(file));

Future<void> _pumpApp(
  WidgetTester tester,
  AppDatabase database,
  FakeLastHomeRepository lastHomes,
) async {
  await tester.pumpWidget(
    ProviderScope(
      // A new key throws the old scope away, like a restart of the app.
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        lastHomeRepositoryProvider.overrideWithValue(lastHomes),
        // The flow adds without barcode; a real camera would only slow it.
        barcodeScannerProvider.overrideWithValue(FakeBarcodeScanner()),
      ],
      child: const FridgoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addMilkToNewHome(WidgetTester tester) async {
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  await addStockItem(tester, name: 'Milch', quantity: '3');
}

Finder _card(String name) => find.widgetWithText(StockItemCard, name);

Future<void> _consume(WidgetTester tester, String buttonLabel) async {
  await tester.tap(
    find.descendant(
      of: _card('Milch'),
      matching: find.byTooltip('Verbrauchen'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, buttonLabel));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a stock item is added, consumed in part and then used up', (
    tester,
  ) async {
    final database = _openDatabase(await _createDatabaseFile());
    addTearDown(database.close);
    await _pumpApp(tester, database, FakeLastHomeRepository());

    await _addMilkToNewHome(tester);
    expect(find.text('3 Stück'), findsOneWidget);

    await _consume(tester, 'Abziehen');
    expect(find.text('2 Stück'), findsOneWidget);

    await _consume(tester, 'Alles verbraucht');
    expect(_card('Milch'), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('the stock is still there after the database is reopened', (
    tester,
  ) async {
    final file = await _createDatabaseFile();
    final lastHomes = FakeLastHomeRepository();
    final database = _openDatabase(file);
    await _pumpApp(tester, database, lastHomes);
    await _addMilkToNewHome(tester);
    await tester.pumpWidget(const SizedBox());
    await database.close();

    final reopenedDatabase = _openDatabase(file);
    addTearDown(reopenedDatabase.close);
    await _pumpApp(tester, reopenedDatabase, lastHomes);

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(_card('Milch'), findsOneWidget);
    expect(find.text('3 Stück'), findsOneWidget);
  });
}
