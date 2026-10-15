import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/app/app.dart';
import 'package:fridgo/ui/start/start_screen.dart';

void main() {
  testWidgets('starts in the start screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FridgoApp()));
    await tester.pumpAndSettle();

    expect(find.byType(StartScreen), findsOneWidget);
  });

  testWidgets('shows the app name from the ARB file', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FridgoApp()));
    await tester.pumpAndSettle();

    expect(find.text('Fridgo'), findsOneWidget);
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

      await tester.pumpWidget(const ProviderScope(child: FridgoApp()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(StartScreen));
      expect(Theme.of(context).brightness, brightness);
    });
  }
}
