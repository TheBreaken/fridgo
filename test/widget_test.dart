import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/main.dart';

void main() {
  testWidgets('shows the app name on launch', (tester) async {
    await tester.pumpWidget(const FridgoApp());

    expect(find.text('Fridgo'), findsOneWidget);
  });
}
