import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/empty_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows title and message', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EmptyState(
          emoji: Emoji.house,
          title: 'Leer',
          message: 'Noch nichts da',
        ),
      ),
    );

    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Noch nichts da'), findsOneWidget);
  });

  testWidgets('shows the given emoji', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EmptyState(
          emoji: Emoji.house,
          title: 'Leer',
          message: 'Noch nichts da',
        ),
      ),
    );

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((picture.bytesLoader as SvgAssetLoader).assetName, Emoji.house);
  });

  testWidgets('shows no button without an action', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EmptyState(
          emoji: Emoji.house,
          title: 'Leer',
          message: 'Noch nichts da',
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('shows the given action', (tester) async {
    await tester.pumpWidget(
      wrap(
        EmptyState(
          emoji: Emoji.house,
          title: 'Leer',
          message: 'Noch nichts da',
          action: FilledButton(onPressed: () {}, child: const Text('Anlegen')),
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Anlegen'), findsOneWidget);
  });
}
