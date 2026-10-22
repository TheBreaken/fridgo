import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/stock_item_detail/edit_stock_item_screen.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';

import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

const _quantityError =
    'Bitte gib eine Menge über 0 mit höchstens drei Nachkommastellen ein.';

Future<void> _openDetails(
  WidgetTester tester, {
  String quantity = '2',
  String unitLabel = 'Stück',
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(tester, now: _today);
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  await addStockItem(
    tester,
    name: 'Joghurt',
    quantity: quantity,
    unitLabel: unitLabel,
  );
  await tester.tap(find.text('Joghurt'));
  await tester.pumpAndSettle();
}

Future<void> _openEditScreen(
  WidgetTester tester, {
  String quantity = '2',
  String unitLabel = 'Stück',
}) async {
  await _openDetails(tester, quantity: quantity, unitLabel: unitLabel);
  await tester.tap(find.byTooltip('Bearbeiten'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Future<void> _save(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Speichern');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pickDay(WidgetTester tester, String label, String day) async {
  await tester.ensureVisible(_field(label));
  await tester.tap(_field(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(day));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Finder _valueOfRow(String label, String value) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  matching: find.text(value),
);

void main() {
  testWidgets('the edit screen starts with the stored values', (tester) async {
    await _openEditScreen(tester, quantity: '1,5', unitLabel: 'l');

    expect(find.byType(EditStockItemScreen), findsOneWidget);
    expect(_fieldText(tester, 'Menge'), '1,5');
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'l')).selected,
      isTrue,
    );
    expect(_fieldText(tester, 'Mindestens haltbar bis'), isEmpty);
    expect(_fieldText(tester, 'Geöffnet am'), isEmpty);
  });

  const invalidQuantities = {
    'an empty quantity is rejected': '',
    'whitespace is rejected': '  ',
    'zero is rejected': '0',
    'a negative quantity is rejected': '-1',
    'four decimals are rejected': '1,2345',
  };

  for (final MapEntry(key: description, value: quantity)
      in invalidQuantities.entries) {
    testWidgets('$description, as when adding', (tester) async {
      await _openEditScreen(tester);

      await tester.enterText(_field('Menge'), quantity);
      await _save(tester);

      expect(find.text(_quantityError), findsOneWidget);
      expect(find.byType(EditStockItemScreen), findsOneWidget);
    });
  }

  testWidgets('saving shows the change in the details without restart', (
    tester,
  ) async {
    await _openEditScreen(tester);

    await tester.enterText(_field('Menge'), '0,5');
    await tester.tap(find.widgetWithText(ChoiceChip, 'kg'));
    await _pickDay(tester, 'Mindestens haltbar bis', '20');
    await _pickDay(tester, 'Geöffnet am', '15');
    await _save(tester);

    expect(find.byType(StockItemDetailScreen), findsOneWidget);
    expect(_valueOfRow('Menge', '0,5 kg'), findsOneWidget);
    expect(_valueOfRow('MHD', '20.10.2026'), findsOneWidget);
    expect(_valueOfRow('Geöffnet', '15.10.2026'), findsOneWidget);
  });

  testWidgets('saving shows the change in the overview without restart', (
    tester,
  ) async {
    await _openEditScreen(tester);

    await tester.enterText(_field('Menge'), '5');
    await _save(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(StockItemCard),
        matching: find.textContaining('5 Stück'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a removed best before date is saved as none', (tester) async {
    await _openEditScreen(tester);
    await _pickDay(tester, 'Mindestens haltbar bis', '20');
    await _save(tester);
    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Datum entfernen'));
    await tester.pump();
    await _save(tester);

    expect(_valueOfRow('MHD', 'Nicht angegeben'), findsOneWidget);
  });

  testWidgets('back without saving keeps the stored values', (tester) async {
    await _openEditScreen(tester);

    await tester.enterText(_field('Menge'), '7');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(_valueOfRow('Menge', '2 Stück'), findsOneWidget);
  });
}
