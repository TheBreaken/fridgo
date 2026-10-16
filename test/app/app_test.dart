import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/app/app.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';

import '../data/database/test_database.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  final database = createWidgetTestDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const FridgoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

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
}
