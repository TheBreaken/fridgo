import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/app/app.dart';
import 'package:fridgo/data/barcode_scanner.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/last_home_repository.dart';
import 'package:fridgo/data/repositories/open_food_facts_repository.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../data/database/test_database.dart';
import '../data/fake_barcode_scanner.dart';
import '../data/repositories/fake_last_home_repository.dart';
import '../data/repositories/fake_product_image_repository.dart';

// Writing through a repository hangs in the FakeAsync zone of widget tests,
// so these flows create data through the screens, as the user would.

Future<void> pumpApp(
  WidgetTester tester, {
  required DateTime now,
  FakeProductImageRepository? productImages,
  FakeBarcodeScanner? barcodeScanner,
  OpenFoodFactsRepository? openFoodFacts,
}) async {
  final database = createWidgetTestDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => now),
        lastHomeRepositoryProvider.overrideWithValue(FakeLastHomeRepository()),
        productImageRepositoryProvider.overrideWithValue(
          productImages ?? FakeProductImageRepository(),
        ),
        barcodeScannerProvider.overrideWithValue(
          barcodeScanner ?? FakeBarcodeScanner(),
        ),
        // Never the real network; by default no product is known there.
        openFoodFactsRepositoryProvider.overrideWithValue(
          openFoodFacts ??
              OpenFoodFactsRepository(
                MockClient((_) async => http.Response('', HttpStatus.notFound)),
              ),
        ),
      ],
      child: const FridgoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> createHomeAndOpenIt(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Wohnung anlegen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> createStorageLocationAndReturn(
  WidgetTester tester,
  String kindLabel,
) async {
  await tester.tap(find.byTooltip('Lagerorte'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Lagerort anlegen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, kindLabel));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// Opens the add screen through the scanner, without a barcode.
Future<void> openAddStockItem(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Lebensmittel scannen'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ohne Barcode'));
  await tester.pumpAndSettle();
}

Future<void> scanBarcode(
  WidgetTester tester,
  FakeBarcodeScanner scanner,
  String barcode,
) async {
  await tester.tap(find.byTooltip('Lebensmittel scannen'));
  await tester.pumpAndSettle();
  scanner.show(barcode);
  await tester.pumpAndSettle();
}

Future<void> addStockItem(
  WidgetTester tester, {
  required String name,
  required String quantity,
  String unitLabel = 'Stück',
}) async {
  await openAddStockItem(tester);
  await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
  await tester.enterText(find.widgetWithText(TextField, 'Menge'), quantity);
  // A focused field scrolls back to its caret after typing; let it finish.
  await tester.pumpAndSettle();
  final unit = find.widgetWithText(ChoiceChip, unitLabel);
  await tester.ensureVisible(unit);
  await tester.pumpAndSettle();
  await tester.tap(unit);
  await tester.pump();
  final submit = find.widgetWithText(FilledButton, 'Hinzufügen');
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}
