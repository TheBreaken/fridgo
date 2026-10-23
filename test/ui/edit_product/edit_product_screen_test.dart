import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/add_stock_item/selected_product_card.dart';
import 'package:fridgo/ui/edit_product/edit_product_screen.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';

import '../../data/fake_barcode_scanner.dart';
import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

const _editProduct = 'Produkt bearbeiten';

Finder _field(String label) => find.widgetWithText(TextField, label);

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Finder _suggestion(String name) => find.widgetWithText(InkWell, name);

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _addYoghurt(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(tester, now: _today);
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  await addStockItem(tester, name: 'Joghurt', quantity: '2');
}

Future<void> _openFromDetails(WidgetTester tester) async {
  await _addYoghurt(tester);
  await tester.tap(find.text('Joghurt'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(_editProduct));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Speichern'));
}

Future<void> _chooseYoghurtWhenAdding(WidgetTester tester) async {
  await openAddStockItem(tester);
  await tester.enterText(_field('Name'), 'jog');
  await tester.pumpAndSettle();
  await tester.tap(_suggestion('Joghurt'));
  await tester.pumpAndSettle();
}

Future<void> _deleteYoghurtStockItem(WidgetTester tester) async {
  await tester.tap(find.text('Joghurt'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Löschen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the edit screen starts with the stored name', (tester) async {
    await _openFromDetails(tester);

    expect(find.byType(EditProductScreen), findsOneWidget);
    expect(_fieldText(tester, 'Name'), 'Joghurt');
    expect(
      find.text('Änderungen gelten für alle Bestände dieses Produkts.'),
      findsOneWidget,
    );
  });

  testWidgets('stored nutrition facts are shown opened and filled in', (
    tester,
  ) async {
    await _addYoghurt(tester);
    await openAddStockItem(tester);
    await tester.enterText(_field('Name'), 'Quark');
    await _tapAndSettle(tester, find.text('Nährwerte (optional)'));
    await tester.ensureVisible(_field('Fett'));
    await tester.enterText(_field('Fett'), '0,25');
    await tester.pumpAndSettle();
    await _tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Hinzufügen'),
    );
    await tester.tap(find.text('Quark'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_editProduct));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_field('Fett'));
    expect(_fieldText(tester, 'Fett'), '0,25');
    expect(_fieldText(tester, 'Eiweiß'), isEmpty);
  });

  const blankNames = {'an empty name': '', 'a name of spaces': '   '};
  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    testWidgets('$description is rejected, as when adding', (tester) async {
      await _openFromDetails(tester);

      await tester.enterText(_field('Name'), name);
      await _save(tester);

      expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
      expect(find.byType(EditProductScreen), findsOneWidget);
    });
  }

  testWidgets('an invalid nutrient value opens the nutrition facts', (
    tester,
  ) async {
    await _openFromDetails(tester);
    await _tapAndSettle(tester, find.text('Nährwerte (optional)'));
    await tester.ensureVisible(_field('Fett'));
    await tester.enterText(_field('Fett'), '-1');
    await tester.pumpAndSettle();
    await _tapAndSettle(tester, find.text('Nährwerte (optional)'));

    await _save(tester);

    expect(
      find.text(
        'Bitte gib 0 bis 100 g mit höchstens drei Nachkommastellen ein.',
      ),
      findsOneWidget,
    );
    expect(find.byType(EditProductScreen), findsOneWidget);
  });

  testWidgets('a new name shows in details and overview without restart', (
    tester,
  ) async {
    await _openFromDetails(tester);

    await tester.enterText(_field('Name'), 'Naturjoghurt');
    await _save(tester);

    expect(find.byType(StockItemDetailScreen), findsOneWidget);
    expect(find.text('Naturjoghurt'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(StockItemCard),
        matching: find.text('Naturjoghurt'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('deleting from the details warns about the stock and returns '
      'to the overview without it', (tester) async {
    await _openFromDetails(tester);

    await tester.tap(find.byTooltip('Löschen'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Auch 1 Bestand in Berlin wird gelöscht. Das Produkt verschwindet '
        'aus den Vorschlägen, sein Foto wird gelöscht.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.byType(StockItemCard), findsNothing);
    expect(find.text('Joghurt gelöscht'), findsOneWidget);
  });

  testWidgets('the warning names the stock items of all homes', (tester) async {
    await _addYoghurt(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await createHomeAndOpenIt(tester, 'Hamburg');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');
    await _chooseYoghurtWhenAdding(tester);
    await _tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Hinzufügen'),
    );
    await tester.tap(find.text('Joghurt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(_editProduct));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Löschen'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Auch 2 Bestände in Berlin und Hamburg werden '),
      findsOneWidget,
    );
  });

  testWidgets('a chosen product is edited from its card when adding', (
    tester,
  ) async {
    await _addYoghurt(tester);
    await _chooseYoghurtWhenAdding(tester);

    await tester.tap(find.byTooltip(_editProduct));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Name'), 'Naturjoghurt');
    await _save(tester);

    expect(find.byType(AddStockItemScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SelectedProductCard),
        matching: find.text('Naturjoghurt'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a product without stock items is deleted after asking', (
    tester,
  ) async {
    await _addYoghurt(tester);
    await _deleteYoghurtStockItem(tester);
    await _chooseYoghurtWhenAdding(tester);
    await tester.tap(find.byTooltip(_editProduct));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Joghurt löschen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStockItemScreen), findsOneWidget);
    expect(find.byType(SelectedProductCard), findsNothing);
    await tester.enterText(_field('Name'), 'jog');
    await tester.pumpAndSettle();
    expect(_suggestion('Joghurt'), findsNothing);
  });

  testWidgets('cancelling the question keeps the product', (tester) async {
    await _addYoghurt(tester);
    await _deleteYoghurtStockItem(tester);
    await _chooseYoghurtWhenAdding(tester);
    await tester.tap(find.byTooltip(_editProduct));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProductScreen), findsOneWidget);
    expect(_fieldText(tester, 'Name'), 'Joghurt');
  });

  testWidgets('removing the barcode frees it for another product', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final scanner = FakeBarcodeScanner();
    await pumpApp(tester, now: _today, barcodeScanner: scanner);
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');
    await scanBarcode(tester, scanner, '4012345678901');
    await tester.enterText(_field('Name'), 'Joghurt');
    await tester.pumpAndSettle();
    await _tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Hinzufügen'),
    );
    await tester.tap(find.text('Joghurt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(_editProduct));
    await tester.pumpAndSettle();
    expect(find.text('Barcode 4012345678901'), findsOneWidget);

    await _tapAndSettle(tester, find.byTooltip('Barcode entfernen'));
    await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Speichern'));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await scanBarcode(tester, scanner, '4012345678901');
    expect(find.byType(SelectedProductCard), findsNothing);
    expect(find.text('Barcode 4012345678901'), findsOneWidget);
  });
}
