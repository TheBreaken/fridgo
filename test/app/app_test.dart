import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/app/app.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/last_home_repository.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';

import '../data/database/test_database.dart';
import '../data/repositories/fake_last_home_repository.dart';
import '../ui/app_flows.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  AppDatabase? database,
  FakeLastHomeRepository? lastHomes,
}) async {
  final usedDatabase = database ?? createWidgetTestDatabase();
  if (database == null) addTearDown(usedDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      // A new key throws the old scope away, like a restart of the app.
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(usedDatabase),
        lastHomeRepositoryProvider.overrideWithValue(
          lastHomes ?? FakeLastHomeRepository(),
        ),
      ],
      child: const FridgoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _appBarTitle(String name) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(name));

void main() {
  testWidgets('starts in the homes screen', (tester) async {
    await _pumpApp(tester);

    expect(find.byType(HomesScreen), findsOneWidget);
  });

  testWidgets('takes the app name from the ARB file', (tester) async {
    await _pumpApp(tester);

    expect(tester.widget<Title>(find.byType(Title)).title, 'Fridgo');
  });

  const brightnesses = {
    'light system setting gives the light theme': Brightness.light,
    'dark system setting gives the dark theme': Brightness.dark,
  };

  for (final MapEntry(key: description, value: brightness)
      in brightnesses.entries) {
    testWidgets(description, (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await _pumpApp(tester);

      final context = tester.element(find.byType(HomesScreen));
      expect(Theme.of(context).brightness, brightness);
    });
  }

  testWidgets('a restart opens the last selected home', (tester) async {
    final database = createWidgetTestDatabase();
    addTearDown(database.close);
    final lastHomes = FakeLastHomeRepository();
    await _pumpApp(tester, database: database, lastHomes: lastHomes);
    await createHomeAndOpenIt(tester, 'Berlin');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await createHomeAndOpenIt(tester, 'Hamburg');

    await _pumpApp(tester, database: database, lastHomes: lastHomes);

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(_appBarTitle('Hamburg'), findsOneWidget);
  });

  testWidgets('a remembered home that is gone opens another home', (
    tester,
  ) async {
    final database = createWidgetTestDatabase();
    addTearDown(database.close);
    await _pumpApp(tester, database: database);
    await createHomeAndOpenIt(tester, 'Berlin');

    await _pumpApp(
      tester,
      database: database,
      lastHomes: FakeLastHomeRepository(lastHomeId: 'deleted'),
    );

    expect(_appBarTitle('Berlin'), findsOneWidget);
  });

  testWidgets('a remembered home without any homes shows the empty state', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      lastHomes: FakeLastHomeRepository(lastHomeId: 'deleted'),
    );

    expect(find.byType(HomesScreen), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });
}
