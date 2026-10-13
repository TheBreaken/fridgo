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
}
