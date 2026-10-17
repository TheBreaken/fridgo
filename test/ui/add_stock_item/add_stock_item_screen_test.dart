import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';

import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

const _quantityError =
    'Bitte gib eine Menge über 0 mit höchstens drei Nachkommastellen ein.';

Future<void> _openAddScreen(WidgetTester tester) async {
  await pumpApp(tester, now: _today);
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  await createStorageLocationAndReturn(tester, 'Gefrierfach');
  await tester.tap(find.byTooltip('Lebensmittel hinzufügen'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _enter(WidgetTester tester, String label, String text) =>
    tester.enterText(_field(label), text);

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Hinzufügen');
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

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

bool _isSelected(WidgetTester tester, String chipLabel) => tester
    .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, chipLabel))
    .selected;

void main() {
  testWidgets('the form starts with one piece in the first storage location', (
    tester,
  ) async {
    await _openAddScreen(tester);

    expect(_isSelected(tester, 'Gefrierfach'), isTrue);
    expect(_isSelected(tester, 'Kühlschrank'), isFalse);
    expect(_isSelected(tester, 'Stück'), isTrue);
    expect(_fieldText(tester, 'Menge'), '1');
    expect(_fieldText(tester, 'Mindestens haltbar bis'), isEmpty);
    expect(_fieldText(tester, 'Geöffnet am'), isEmpty);
  });

  const blankNames = {'an empty name': '', 'a name of spaces': '   '};

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    testWidgets('$description shows an error and keeps the form open', (
      tester,
    ) async {
      await _openAddScreen(tester);
      await _enter(tester, 'Name', name);

      await _submit(tester);

      expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
      expect(find.byType(AddStockItemScreen), findsOneWidget);
    });
  }

  const invalidQuantities = {
    'a quantity of 0': '0',
    'a negative quantity': '-1',
    'an empty quantity': '',
    'a quantity with four decimals': '1,2345',
  };

  for (final MapEntry(key: description, value: quantity)
      in invalidQuantities.entries) {
    testWidgets('$description shows an error and keeps the form open', (
      tester,
    ) async {
      await _openAddScreen(tester);
      await _enter(tester, 'Name', 'Milch');
      await _enter(tester, 'Menge', quantity);

      await _submit(tester);

      expect(find.text(_quantityError), findsOneWidget);
      expect(find.byType(AddStockItemScreen), findsOneWidget);
    });
  }

  testWidgets('a picked best before date is shown as a German date', (
    tester,
  ) async {
    await _openAddScreen(tester);

    await _pickDay(tester, 'Mindestens haltbar bis', '25');

    expect(_fieldText(tester, 'Mindestens haltbar bis'), '25.10.2026');
  });

  testWidgets('a picked date can be removed again', (tester) async {
    await _openAddScreen(tester);
    await _pickDay(tester, 'Mindestens haltbar bis', '25');

    await tester.tap(find.byTooltip('Datum entfernen'));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'Mindestens haltbar bis'), isEmpty);
    expect(find.byTooltip('Datum entfernen'), findsNothing);
  });

  testWidgets('the opened date cannot lie after today', (tester) async {
    await _openAddScreen(tester);
    await tester.ensureVisible(_field('Geöffnet am'));

    await tester.tap(_field('Geöffnet am'));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, DateTime(2026, 10, 16));
  });

  testWidgets('the best before date may lie in the past', (tester) async {
    await _openAddScreen(tester);
    await tester.ensureVisible(_field('Mindestens haltbar bis'));

    await tester.tap(_field('Mindestens haltbar bis'));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate.isBefore(DateTime(2025, 10, 16)), isTrue);
  });

  testWidgets('a saved stock item is shown in the home', (tester) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Milch');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kühlschrank'));
    await _enter(tester, 'Menge', '1,5');
    await tester.tap(find.widgetWithText(ChoiceChip, 'l'));
    await _pickDay(tester, 'Mindestens haltbar bis', '25');

    await _submit(tester);

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    final card = find.ancestor(
      of: find.text('Milch'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: card, matching: find.text('1,5 l · MHD 25.10.2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Kühlschrank')),
      findsOneWidget,
    );
  });

  testWidgets('a saved stock item shows its expiry as of the clock', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Milch');
    await _pickDay(tester, 'Mindestens haltbar bis', '18');

    await _submit(tester);

    expect(find.text('Noch 2 Tage'), findsOneWidget);
  });

  testWidgets('a stock item without best before date shows only its quantity', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Äpfel');
    await _enter(tester, 'Menge', '6');

    await _submit(tester);

    expect(find.text('6 Stück'), findsOneWidget);
  });

  testWidgets('back without saving keeps the stock empty', (tester) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Milch');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.text('Noch keine Lebensmittel'), findsOneWidget);
  });
}
