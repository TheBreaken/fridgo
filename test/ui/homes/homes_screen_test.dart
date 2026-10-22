import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/homes/create_home_sheet.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';

import '../../data/database/test_database.dart';
import '../app_flows.dart';

Future<HomeRepository> _pumpHomesScreen(WidgetTester tester) async {
  final database = createWidgetTestDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return HomeRepository(database);
}

Future<void> _openSheetWithMainAction(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Wohnung anlegen'));
  await tester.pumpAndSettle();
}

Future<void> _submitName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without homes an empty state invites to create one', (
    tester,
  ) async {
    await _pumpHomesScreen(tester);

    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.widgetWithText(FilledButton, 'Wohnung anlegen'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the main action opens the sheet', (tester) async {
    await _pumpHomesScreen(tester);

    await _openSheetWithMainAction(tester);

    expect(find.byType(CreateHomeSheet), findsOneWidget);
  });

  testWidgets('the empty state action opens the sheet', (tester) async {
    await _pumpHomesScreen(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateHomeSheet), findsOneWidget);
  });

  const blankNames = {'an empty name': '', 'a name of spaces': '   '};

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    testWidgets('$description shows an error and stores nothing', (
      tester,
    ) async {
      final repository = await _pumpHomesScreen(tester);
      await _openSheetWithMainAction(tester);

      await _submitName(tester, name);

      expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
      expect(find.byType(CreateHomeSheet), findsOneWidget);
      expect(
        await tester.runAsync(() => repository.watchHomes().first),
        isEmpty,
      );
    });
  }

  testWidgets('a valid name closes the sheet and lists the home', (
    tester,
  ) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);

    await _submitName(tester, 'Berlin');

    expect(find.byType(CreateHomeSheet), findsNothing);
    expect(find.byType(EmptyState), findsNothing);
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('Berlin')),
      findsOneWidget,
    );
  });

  testWidgets('submitting with the keyboard creates the home', (tester) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);

    await tester.enterText(find.byType(TextFormField), 'Hamburg');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(CreateHomeSheet), findsNothing);
    expect(find.text('Hamburg'), findsOneWidget);
  });

  testWidgets('the error disappears once a name is typed', (tester) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);
    await _submitName(tester, '');

    await tester.enterText(find.byType(TextFormField), 'B');
    await tester.pump();

    expect(find.text('Bitte gib einen Namen ein.'), findsNothing);
  });

  testWidgets('every home gets a card, sorted by name', (tester) async {
    await _pumpHomesScreen(tester);

    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Berlin');
    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Aachen');

    expect(find.byType(Card), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Aachen')).dy,
      lessThan(tester.getTopLeft(find.text('Berlin')).dy),
    );
  });

  group('changing homes', _changingHomes);
}

Future<void> _chooseFromMenu(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('Weitere Aktionen'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Finder _cardText(String text) =>
    find.descendant(of: find.byType(Card), matching: find.text(text));

void _changingHomes() {
  testWidgets('renaming starts with the current name', (tester) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Berlin');

    await _chooseFromMenu(tester, 'Umbenennen');

    expect(find.text('Wohnung umbenennen'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'Berlin',
    );
  });

  testWidgets('a renamed home shows its new name', (tester) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Berlin');
    await _chooseFromMenu(tester, 'Umbenennen');

    await tester.enterText(find.byType(TextFormField), '  Hamburg ');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHomeSheet), findsNothing);
    expect(_cardText('Hamburg'), findsOneWidget);
    expect(_cardText('Berlin'), findsNothing);
  });

  testWidgets('renaming to a blank name shows an error and keeps the name', (
    tester,
  ) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Berlin');
    await _chooseFromMenu(tester, 'Umbenennen');

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
    expect(find.byType(CreateHomeSheet), findsOneWidget);
    expect(_cardText('Berlin'), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the home', (tester) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Berlin');
    await _chooseFromMenu(tester, 'Löschen');

    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(_cardText('Berlin'), findsOneWidget);
  });

  testWidgets('deleting a home without stock says so and removes it', (
    tester,
  ) async {
    await _pumpHomesScreen(tester);
    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Berlin');
    await _openSheetWithMainAction(tester);
    await _submitName(tester, 'Hamburg');
    await tester.tap(find.byTooltip('Weitere Aktionen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Berlin löschen?'), findsOneWidget);
    expect(
      find.text(
        'Die Wohnung und ihre Lagerorte werden gelöscht. Bestände liegen '
        'keine darin. Die Produkte bleiben in den Vorschlägen.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(_cardText('Berlin'), findsNothing);
    expect(_cardText('Hamburg'), findsOneWidget);
    expect(find.text('Berlin gelöscht'), findsOneWidget);
  });

  testWidgets('deleting a home names its stock items and leaves the empty '
      'state', (tester) async {
    await pumpApp(tester, now: DateTime(2026, 10, 22, 9));
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');
    await addStockItem(tester, name: 'Milch', quantity: '1');
    await addStockItem(tester, name: 'Butter', quantity: '1');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await _chooseFromMenu(tester, 'Löschen');

    expect(
      find.text(
        'Die Wohnung, ihre Lagerorte und 2 Bestände werden gelöscht. Die '
        'Produkte bleiben in den Vorschlägen.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });
}
