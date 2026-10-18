import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/stock_overview/consume_stock_item_sheet.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';

import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

const _quantityError =
    'Bitte gib eine Menge über 0 mit höchstens drei Nachkommastellen ein.';

Finder _field(String label) => find.widgetWithText(TextField, label);

Finder _card(String name) =>
    find.widgetWithText(StockItemCard, name, skipOffstage: false);

Future<void> _addStockItem(
  WidgetTester tester, {
  required String name,
  required String quantity,
  String unitLabel = 'Stück',
}) async {
  await tester.tap(find.byTooltip('Lebensmittel hinzufügen'));
  await tester.pumpAndSettle();
  await tester.enterText(_field('Name'), name);
  await tester.enterText(_field('Menge'), quantity);
  await tester.tap(find.widgetWithText(ChoiceChip, unitLabel));
  await tester.pump();
  final submit = find.widgetWithText(FilledButton, 'Hinzufügen');
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

Future<void> _openOverviewWithStock(
  WidgetTester tester, {
  required String name,
  required String quantity,
  String unitLabel = 'Stück',
}) async {
  await pumpApp(tester, now: _today);
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  await _addStockItem(
    tester,
    name: name,
    quantity: quantity,
    unitLabel: unitLabel,
  );
}

Future<void> _openSheetOf(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(of: _card(name), matching: find.byTooltip('Verbrauchen')),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Verbrauchen'));
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

void main() {
  testWidgets('the sheet names the product and what is available', (
    tester,
  ) async {
    await _openOverviewWithStock(
      tester,
      name: 'Joghurt',
      quantity: '500',
      unitLabel: 'g',
    );

    await _openSheet(tester);

    expect(find.text('Joghurt verbrauchen'), findsOneWidget);
    expect(find.text('Vorhanden: 500 g'), findsOneWidget);
    expect(_fieldText(tester, 'Verbraucht'), isEmpty);
  });

  testWidgets('consuming a part lowers the quantity on the card', (
    tester,
  ) async {
    await _openOverviewWithStock(
      tester,
      name: 'Joghurt',
      quantity: '500',
      unitLabel: 'g',
    );
    await _openSheet(tester);

    await tester.enterText(_field('Verbraucht'), '150');
    await _tapButton(tester, 'Abziehen');

    expect(find.byType(ConsumeStockItemSheet), findsNothing);
    expect(find.text('350 g'), findsOneWidget);
    expect(find.text('Joghurt: 150 g verbraucht'), findsOneWidget);
  });

  testWidgets('a decimal comma consumes a part of a kilogram', (tester) async {
    await _openOverviewWithStock(
      tester,
      name: 'Mehl',
      quantity: '1,5',
      unitLabel: 'kg',
    );
    await _openSheet(tester);

    await tester.enterText(_field('Verbraucht'), '0,25');
    await _tapButton(tester, 'Abziehen');

    expect(find.text('1,25 kg'), findsOneWidget);
  });

  testWidgets('pieces start with one, so one tap subtracts one', (
    tester,
  ) async {
    await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
    await _openSheet(tester);

    await _tapButton(tester, 'Abziehen');

    expect(find.text('5 Stück'), findsOneWidget);
  });

  const invalidQuantities = {
    'a quantity of 0': '0',
    'an empty quantity': '',
    'a quantity with four decimals': '1,2345',
  };

  for (final MapEntry(key: description, value: quantity)
      in invalidQuantities.entries) {
    testWidgets('$description shows an error and keeps the sheet open', (
      tester,
    ) async {
      await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
      await _openSheet(tester);

      await tester.enterText(_field('Verbraucht'), quantity);
      await _tapButton(tester, 'Abziehen');

      expect(find.text(_quantityError), findsOneWidget);
      expect(find.byType(ConsumeStockItemSheet), findsOneWidget);
      expect(find.text('6 Stück'), findsOneWidget);
    });
  }

  testWidgets('consuming everything removes the card', (tester) async {
    await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
    await _openSheet(tester);

    await _tapButton(tester, 'Alles verbraucht');

    expect(_card('Eier'), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Eier aufgebraucht'), findsOneWidget);
  });

  testWidgets('consuming more than available removes the card', (tester) async {
    await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
    await _openSheet(tester);

    await tester.enterText(_field('Verbraucht'), '7');
    await _tapButton(tester, 'Abziehen');

    expect(_card('Eier'), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('undo brings a used up stock item back', (tester) async {
    await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
    await _openSheet(tester);
    await _tapButton(tester, 'Alles verbraucht');

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();

    expect(_card('Eier'), findsOneWidget);
    expect(find.text('6 Stück'), findsOneWidget);
  });

  testWidgets('undo restores the quantity after consuming a part', (
    tester,
  ) async {
    await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
    await _openSheet(tester);
    await _tapButton(tester, 'Abziehen');

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();

    expect(find.text('6 Stück'), findsOneWidget);
  });

  testWidgets('of two stock items only the chosen one changes', (tester) async {
    await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
    await _addStockItem(tester, name: 'Milch', quantity: '1');

    await _openSheetOf(tester, 'Milch');
    await _tapButton(tester, 'Alles verbraucht');

    expect(_card('Milch'), findsNothing);
    expect(_card('Eier'), findsOneWidget);
    expect(find.text('6 Stück'), findsOneWidget);
  });

  testWidgets('a used up card shrinks away instead of vanishing at once', (
    tester,
  ) async {
    await _openOverviewWithStock(tester, name: 'Eier', quantity: '6');
    await _addStockItem(tester, name: 'Milch', quantity: '1');
    await _openSheetOf(tester, 'Milch');

    await tester.tap(find.widgetWithText(FilledButton, 'Alles verbraucht'));
    await tester.pump();
    await tester.pump(Durations.short4);

    final shrinking = tester.widget<SizeTransition>(
      find.ancestor(of: _card('Milch'), matching: find.byType(SizeTransition)),
    );
    expect(shrinking.sizeFactor.value, inExclusiveRange(0, 1));
  });
}
