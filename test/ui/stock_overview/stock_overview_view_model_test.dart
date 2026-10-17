import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/clock.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_view_model.dart';

Future<void> _pumpToday(WidgetTester tester, DateTime Function() clock) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWithValue(clock)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) =>
                Text(ref.watch(todayProvider).toIso8601String()),
          ),
        ),
      ),
    );

void main() {
  testWidgets('today is the day of the clock', (tester) async {
    await _pumpToday(tester, () => DateTime(2026, 10, 16, 9));

    expect(find.text('2026-10-16'), findsOneWidget);
  });

  testWidgets('today moves on at midnight while the screen stays open', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 16, 23, 59);
    await _pumpToday(tester, () => now);

    now = DateTime(2026, 10, 17, 0, 0, 1);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();

    expect(find.text('2026-10-17'), findsOneWidget);
  });

  testWidgets('today stays until midnight has passed', (tester) async {
    var now = DateTime(2026, 10, 16, 23, 59);
    await _pumpToday(tester, () => now);

    now = DateTime(2026, 10, 16, 23, 59, 59);
    await tester.pump(const Duration(seconds: 59));
    await tester.pump();

    expect(find.text('2026-10-16'), findsOneWidget);
  });

  testWidgets('today moves on at midnight when summer time ends', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 25, 23);
    await _pumpToday(tester, () => now);

    now = DateTime(2026, 10, 26);
    await tester.pump(const Duration(hours: 1));
    await tester.pump();

    expect(find.text('2026-10-26'), findsOneWidget);
  });

  testWidgets('today is read again when the app comes back', (tester) async {
    var now = DateTime(2026, 10, 16, 22);
    await _pumpToday(tester, () => now);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

    now = DateTime(2026, 10, 17, 8);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('2026-10-17'), findsOneWidget);
  });
}
