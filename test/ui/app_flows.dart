import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/app/app.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/data/database/app_database.dart';

import '../data/database/test_database.dart';

// Writing through a repository hangs in the FakeAsync zone of widget tests,
// so these flows create data through the screens, as the user would.

Future<void> pumpApp(WidgetTester tester, {required DateTime now}) async {
  final database = createWidgetTestDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => now),
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
