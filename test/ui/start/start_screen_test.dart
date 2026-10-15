import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/core/image_placeholder.dart';
import 'package:fridgo/ui/start/start_screen.dart';

void main() {
  Future<void> pumpStartScreen(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StartScreen(),
    ),
  );

  testWidgets('shows a card with an image placeholder', (tester) async {
    await pumpStartScreen(tester);

    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.byType(ImagePlaceholder),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows an empty state with its action', (tester) async {
    await pumpStartScreen(tester);

    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.widgetWithText(FilledButton, 'Lebensmittel hinzufügen'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the main action', (tester) async {
    await pumpStartScreen(tester);

    expect(find.byTooltip('Lebensmittel hinzufügen'), findsOneWidget);
  });
}
