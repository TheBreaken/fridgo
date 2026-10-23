import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/barcode_scan.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/add_stock_item/selected_product_card.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';

import '../../data/fake_barcode_scanner.dart';
import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

const _milkBarcode = '4012345678901';
const _otherBarcode = '4098765432109';

Future<FakeBarcodeScanner> _openFridge(WidgetTester tester) async {
  final scanner = FakeBarcodeScanner();
  await pumpApp(tester, now: _today, barcodeScanner: scanner);
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  return scanner;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Finder _selectedProduct(String name) =>
    find.widgetWithText(SelectedProductCard, name);

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Hinzufügen');
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _addScanned(
  WidgetTester tester,
  FakeBarcodeScanner scanner, {
  required String barcode,
  required String name,
}) async {
  await scanBarcode(tester, scanner, barcode);
  await tester.enterText(_field('Name'), name);
  await _submit(tester);
}

Future<void> _chooseSuggestion(WidgetTester tester, String name) async {
  await tester.enterText(_field('Name'), name.substring(0, 3).toLowerCase());
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(InkWell, name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unknown barcode opens the empty form showing the barcode', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);

    await scanBarcode(tester, scanner, _milkBarcode);

    expect(find.byType(AddStockItemScreen), findsOneWidget);
    expect(find.text('Barcode $_milkBarcode'), findsOneWidget);
    expect(find.byType(SelectedProductCard), findsNothing);
  });

  testWidgets('a known barcode selects its product', (tester) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');

    await scanBarcode(tester, scanner, _milkBarcode);

    expect(_selectedProduct('Milch'), findsOneWidget);
  });

  testWidgets('a known product is stored in 2 taps from the overview', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');

    // Tap 1: the camera button. Scanning needs no tap.
    await scanBarcode(tester, scanner, _milkBarcode);
    // Tap 2: add.
    await _submit(tester);

    expect(find.widgetWithText(StockItemCard, 'Milch'), findsNWidgets(2));
  });

  testWidgets('a scanned barcode is given to the chosen existing product', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await addStockItem(tester, name: 'Milch', quantity: '1');
    await scanBarcode(tester, scanner, _milkBarcode);
    await _chooseSuggestion(tester, 'Milch');
    await _submit(tester);

    await scanBarcode(tester, scanner, _milkBarcode);

    expect(_selectedProduct('Milch'), findsOneWidget);
  });

  testWidgets('a product with another barcode keeps it, and the form says so', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');
    await scanBarcode(tester, scanner, _otherBarcode);

    await _chooseSuggestion(tester, 'Milch');

    expect(
      find.text(
        'Das Produkt hat schon einen anderen Barcode, '
        'der gescannte wird nicht übernommen.',
      ),
      findsOneWidget,
    );
    await _submit(tester);
    await scanBarcode(tester, scanner, _otherBarcode);
    expect(find.byType(SelectedProductCard), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await scanBarcode(tester, scanner, _milkBarcode);
    expect(_selectedProduct('Milch'), findsOneWidget);
  });

  testWidgets('clearing the product of a known barcode drops the barcode', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');
    await scanBarcode(tester, scanner, _milkBarcode);

    await tester.tap(find.byTooltip('Anderes Produkt eintragen'));
    await tester.pumpAndSettle();

    expect(find.text('Barcode $_milkBarcode'), findsNothing);
    await tester.enterText(_field('Name'), 'Hafermilch');
    await _submit(tester);
    expect(find.widgetWithText(StockItemCard, 'Hafermilch'), findsOneWidget);
  });

  testWidgets('adding without barcode opens the empty form', (tester) async {
    await _openFridge(tester);

    await openAddStockItem(tester);

    expect(find.byType(AddStockItemScreen), findsOneWidget);
    expect(find.textContaining('Barcode'), findsNothing);
  });

  final cameraErrorCases = {
    'a denied camera leads to the form with a hint': (
      error: const CameraAccessDeniedException(),
      hint:
          'Fridgo darf die Kamera nicht benutzen. Du kannst das in den '
          'Einstellungen erlauben. Bis dahin trägst du das Lebensmittel hier '
          'ein.',
    ),
    'a missing camera leads to the form with a hint': (
      error: const CameraUnavailableException('unsupported'),
      hint:
          'Die Kamera ist gerade nicht verfügbar. '
          'Trag das Lebensmittel hier ein.',
    ),
  };
  for (final MapEntry(key: description, value: (:error, :hint))
      in cameraErrorCases.entries) {
    testWidgets(description, (tester) async {
      final scanner = await _openFridge(tester);
      scanner.startError = error;

      await tester.tap(find.byTooltip('Lebensmittel scannen'));
      await tester.pumpAndSettle();

      expect(find.byType(AddStockItemScreen), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
    });
  }
}
