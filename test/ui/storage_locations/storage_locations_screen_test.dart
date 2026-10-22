import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';
import 'package:fridgo/ui/storage_locations/create_storage_location_sheet.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_screen.dart';

import '../app_flows.dart';

Future<void> _openStorageLocationsOfNewHome(WidgetTester tester) async {
  await pumpApp(tester, now: DateTime(2026, 10, 16, 9));
  await createHomeAndOpenIt(tester, 'Berlin');
  await tester.tap(find.byTooltip('Lagerorte'));
  await tester.pumpAndSettle();
}

Future<void> _openSheetWithMainAction(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Lagerort anlegen'));
  await tester.pumpAndSettle();
}

Future<void> _submitName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
  await tester.pumpAndSettle();
}

String _nameField(WidgetTester tester) =>
    tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text;

Finder _cardEmoji(String asset) => find.descendant(
  of: find.byType(Card),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is SvgPicture &&
        (widget.bytesLoader as SvgAssetLoader).assetName == asset,
  ),
);

void main() {
  testWidgets('the storage locations action opens them', (tester) async {
    await _openStorageLocationsOfNewHome(tester);

    expect(find.byType(StorageLocationsScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Berlin')),
      findsOneWidget,
    );
  });

  testWidgets(
    'without storage locations an empty state invites to create one',
    (tester) async {
      await _openStorageLocationsOfNewHome(tester);

      expect(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.widgetWithText(FilledButton, 'Lagerort anlegen'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the main action opens the sheet', (tester) async {
    await _openStorageLocationsOfNewHome(tester);

    await _openSheetWithMainAction(tester);

    expect(find.byType(CreateStorageLocationSheet), findsOneWidget);
  });

  testWidgets('the empty state action opens the sheet', (tester) async {
    await _openStorageLocationsOfNewHome(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateStorageLocationSheet), findsOneWidget);
  });

  testWidgets('the sheet starts with the refrigerator and its name', (
    tester,
  ) async {
    await _openStorageLocationsOfNewHome(tester);

    await _openSheetWithMainAction(tester);

    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Kühlschrank')),
      isA<ChoiceChip>().having((chip) => chip.selected, 'selected', isTrue),
    );
    expect(_nameField(tester), 'Kühlschrank');
  });

  testWidgets('choosing a kind replaces the suggested name', (tester) async {
    await _openStorageLocationsOfNewHome(tester);
    await _openSheetWithMainAction(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Gefrierfach'));
    await tester.pump();

    expect(_nameField(tester), 'Gefrierfach');
  });

  testWidgets('choosing a kind keeps a name typed by hand', (tester) async {
    await _openStorageLocationsOfNewHome(tester);
    await _openSheetWithMainAction(tester);
    await tester.enterText(find.byType(TextFormField), 'Getränke');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Keller'));
    await tester.pump();

    expect(_nameField(tester), 'Getränke');
  });

  const blankNames = {'an empty name': '', 'a name of spaces': '   '};

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    testWidgets('$description shows an error and keeps the sheet open', (
      tester,
    ) async {
      await _openStorageLocationsOfNewHome(tester);
      await _openSheetWithMainAction(tester);

      await _submitName(tester, name);

      expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
      expect(find.byType(CreateStorageLocationSheet), findsOneWidget);
    });
  }

  testWidgets('a created storage location gets a card with its kind icon', (
    tester,
  ) async {
    await _openStorageLocationsOfNewHome(tester);
    await _openSheetWithMainAction(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Gefrierfach'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateStorageLocationSheet), findsNothing);
    expect(find.byType(EmptyState), findsNothing);
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('Gefrierfach'),
      ),
      findsOneWidget,
    );
    expect(_cardEmoji(Emoji.iceCube), findsOneWidget);
  });

  testWidgets('a custom name shows the kind below it', (tester) async {
    await _openStorageLocationsOfNewHome(tester);
    await _openSheetWithMainAction(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sonstiges'));
    await tester.pump();

    await _submitName(tester, 'Obstkorb');

    expect(
      find.descendant(of: find.byType(Card), matching: find.text('Obstkorb')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('Sonstiges')),
      findsOneWidget,
    );
    expect(_cardEmoji(Emoji.basket), findsOneWidget);
  });

  testWidgets('back returns to the stock overview', (tester) async {
    await _openStorageLocationsOfNewHome(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.byType(StorageLocationsScreen), findsNothing);
  });

  group('changing storage locations', _changingStorageLocations);
}

Future<void> _chooseFromMenu(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('Weitere Aktionen'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<void> _createFridge(WidgetTester tester) async {
  await _openSheetWithMainAction(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
  await tester.pumpAndSettle();
}

Finder _cardText(String text) =>
    find.descendant(of: find.byType(Card), matching: find.text(text));

void _changingStorageLocations() {
  testWidgets('editing starts with the current kind and name', (tester) async {
    await _openStorageLocationsOfNewHome(tester);
    await _openSheetWithMainAction(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Keller'));
    await tester.pump();
    await _submitName(tester, 'Weinkeller');

    await _chooseFromMenu(tester, 'Bearbeiten');

    expect(find.text('Lagerort bearbeiten'), findsOneWidget);
    expect(_nameField(tester), 'Weinkeller');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Keller'))
          .selected,
      isTrue,
    );
  });

  testWidgets('an edited storage location shows its new kind and name', (
    tester,
  ) async {
    await _openStorageLocationsOfNewHome(tester);
    await _createFridge(tester);
    await _chooseFromMenu(tester, 'Bearbeiten');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Gefrierfach'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateStorageLocationSheet), findsNothing);
    expect(_cardText('Gefrierfach'), findsOneWidget);
    expect(_cardText('Kühlschrank'), findsNothing);
    expect(_cardEmoji(Emoji.iceCube), findsOneWidget);
  });

  testWidgets('editing to a blank name shows an error and keeps the name', (
    tester,
  ) async {
    await _openStorageLocationsOfNewHome(tester);
    await _createFridge(tester);
    await _chooseFromMenu(tester, 'Bearbeiten');

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
    expect(find.byType(CreateStorageLocationSheet), findsOneWidget);
    expect(_cardText('Kühlschrank'), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the storage location', (
    tester,
  ) async {
    await _openStorageLocationsOfNewHome(tester);
    await _createFridge(tester);
    await _chooseFromMenu(tester, 'Löschen');

    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();

    expect(_cardText('Kühlschrank'), findsOneWidget);
  });

  testWidgets('deleting an empty storage location says it holds no stock', (
    tester,
  ) async {
    await _openStorageLocationsOfNewHome(tester);
    await _createFridge(tester);

    await _chooseFromMenu(tester, 'Löschen');

    expect(find.text('Kühlschrank löschen?'), findsOneWidget);
    expect(
      find.text(
        'Bestände liegen keine darin. Die Produkte bleiben in den Vorschlägen.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deleting a storage location names and removes its stock', (
    tester,
  ) async {
    await pumpApp(tester, now: DateTime(2026, 10, 22, 9));
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');
    await addStockItem(tester, name: 'Milch', quantity: '1');
    await tester.tap(find.byTooltip('Lagerorte'));
    await tester.pumpAndSettle();
    await _chooseFromMenu(tester, 'Löschen');

    expect(
      find.text(
        'Auch 1 Bestand darin wird gelöscht. Die Produkte bleiben in den '
        'Vorschlägen.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Kühlschrank gelöscht'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Milch'), findsNothing);
    expect(find.text('Noch kein Lagerort'), findsOneWidget);
  });
}
