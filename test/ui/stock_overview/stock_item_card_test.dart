import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';

final _today = CalendarDate(2026, 10, 16);

StockItemDetails _milk({CalendarDate? bestBeforeDate}) => StockItemDetails(
  stockItem: StockItem(
    id: 'stock-item',
    productId: 'product',
    storageLocationId: 'storage-location',
    quantity: 1,
    unit: StockUnit.liter,
    bestBeforeDate: bestBeforeDate,
  ),
  product: const Product(id: 'product', name: 'Milch'),
  storageLocation: const StorageLocation(
    id: 'storage-location',
    homeId: 'home',
    name: 'Kühlschrank',
    kind: StorageLocationKind.refrigerator,
  ),
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required CalendarDate? bestBeforeDate,
  VoidCallback? onConsume,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: StockItemCard(
        details: _milk(bestBeforeDate: bestBeforeDate),
        today: _today,
        onConsume: onConsume ?? () {},
      ),
    ),
  ),
);

void main() {
  final expiryBadges = {
    'expired two days ago': (
      CalendarDate(2026, 10, 14),
      'Seit 2 Tagen abgelaufen',
      Icons.warning_rounded,
    ),
    'expired yesterday': (
      CalendarDate(2026, 10, 15),
      'Gestern abgelaufen',
      Icons.warning_rounded,
    ),
    'expiring today': (
      CalendarDate(2026, 10, 16),
      'Läuft heute ab',
      Icons.schedule_rounded,
    ),
    'expiring tomorrow': (
      CalendarDate(2026, 10, 17),
      'Läuft morgen ab',
      Icons.schedule_rounded,
    ),
    'expiring at the threshold': (
      CalendarDate(2026, 10, 19),
      'Noch 3 Tage',
      Icons.schedule_rounded,
    ),
  };

  for (final MapEntry(key: description, value: (bestBeforeDate, label, icon))
      in expiryBadges.entries) {
    testWidgets('$description shows "$label" with its icon', (tester) async {
      await _pumpCard(tester, bestBeforeDate: bestBeforeDate);

      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
    });
  }

  final withoutBadge = {
    'a fresh stock item': CalendarDate(2026, 10, 20),
    'a stock item without best before date': null,
  };

  for (final MapEntry(key: description, value: bestBeforeDate)
      in withoutBadge.entries) {
    testWidgets('$description shows no expiry badge', (tester) async {
      await _pumpCard(tester, bestBeforeDate: bestBeforeDate);

      expect(find.byIcon(Icons.warning_rounded), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });
  }

  testWidgets('an expired stock item still shows its best before date', (
    tester,
  ) async {
    await _pumpCard(tester, bestBeforeDate: CalendarDate(2026, 10, 14));

    expect(find.text('1 l · MHD 14.10.2026'), findsOneWidget);
  });

  testWidgets('expired and expiring soon differ in colour', (tester) async {
    await _pumpCard(tester, bestBeforeDate: CalendarDate(2026, 10, 14));
    final expiredColour = tester
        .widget<Icon>(find.byIcon(Icons.warning_rounded))
        .color;

    await _pumpCard(tester, bestBeforeDate: CalendarDate(2026, 10, 16));
    final expiringSoonColour = tester
        .widget<Icon>(find.byIcon(Icons.schedule_rounded))
        .color;

    expect(expiredColour, AppTheme.light.colorScheme.onErrorContainer);
    expect(expiringSoonColour, AppTheme.light.colorScheme.onTertiaryContainer);
  });

  testWidgets('the consume button calls back once', (tester) async {
    var calls = 0;
    await _pumpCard(tester, bestBeforeDate: null, onConsume: () => calls++);

    await tester.tap(find.byTooltip('Verbrauchen'));

    expect(calls, 1);
  });
}
