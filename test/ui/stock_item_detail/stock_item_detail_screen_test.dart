import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/expiry_badge.dart';
import 'package:fridgo/ui/core/image_placeholder.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_view_model.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';

import '../../data/repositories/fake_product_image_repository.dart';

const _homeId = 'home';
const _stockItemId = 'yoghurt';
final _today = CalendarDate(2026, 10, 16);

StockItemDetails _yoghurt({
  double quantity = 2,
  StockUnit unit = StockUnit.piece,
  CalendarDate? bestBeforeDate,
  CalendarDate? openedDate,
  String? imagePath,
}) => StockItemDetails(
  stockItem: StockItem(
    id: _stockItemId,
    productId: 'product',
    storageLocationId: 'refrigerator',
    quantity: quantity,
    unit: unit,
    bestBeforeDate: bestBeforeDate,
    openedDate: openedDate,
  ),
  product: Product(id: 'product', name: 'Joghurt', imagePath: imagePath),
  storageLocation: const StorageLocation(
    id: 'refrigerator',
    homeId: _homeId,
    name: 'Kühlschrank oben',
    kind: StorageLocationKind.refrigerator,
  ),
);

Widget _detailApp(List<StockItemDetails> stock) => ProviderScope(
  overrides: [
    homeProvider.overrideWith(
      (ref, homeId) => Stream.value(Home(id: homeId, name: 'Berlin')),
    ),
    stockOverviewProvider.overrideWith((ref, homeId) => Stream.value(stock)),
    todayProvider.overrideWithValue(_today),
    productImageRepositoryProvider.overrideWithValue(
      FakeProductImageRepository(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const StockItemDetailScreen(
      homeId: _homeId,
      stockItemId: _stockItemId,
    ),
  ),
);

/// A phone screen: on the default test screen the photo leaves no room.
void _usePhoneScreen(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpDetails(WidgetTester tester, StockItemDetails details) async {
  _usePhoneScreen(tester);
  await tester.pumpWidget(_detailApp([details]));
  await tester.pumpAndSettle();
}

Finder _valueOfRow(String label, String value) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  matching: find.text(value),
);

void main() {
  final shownValues = <String, (StockItemDetails, String, String)>{
    'quantity with unit': (
      _yoghurt(quantity: 1.5, unit: StockUnit.liter),
      'Menge',
      '1,5 l',
    ),
    'best before date': (
      _yoghurt(bestBeforeDate: CalendarDate(2026, 10, 25)),
      'MHD',
      '25.10.2026',
    ),
    'missing best before date': (_yoghurt(), 'MHD', 'Nicht angegeben'),
    'opened date': (
      _yoghurt(openedDate: CalendarDate(2026, 10, 14)),
      'Geöffnet',
      '14.10.2026',
    ),
    'not opened': (_yoghurt(), 'Geöffnet', 'Noch nicht'),
    'storage location': (_yoghurt(), 'Lagerort', 'Kühlschrank oben'),
    'home': (_yoghurt(), 'Wohnung', 'Berlin'),
  };
  for (final MapEntry(key: description, value: (details, label, value))
      in shownValues.entries) {
    testWidgets('shows the $description', (tester) async {
      await _pumpDetails(tester, details);

      expect(_valueOfRow(label, value), findsOneWidget);
    });
  }

  testWidgets('shows the product name', (tester) async {
    await _pumpDetails(tester, _yoghurt());

    expect(find.text('Joghurt'), findsOneWidget);
  });

  testWidgets('warns when the best before date is close', (tester) async {
    await _pumpDetails(
      tester,
      _yoghurt(bestBeforeDate: CalendarDate(2026, 10, 17)),
    );

    expect(find.byType(ExpiryBadge), findsOneWidget);
    expect(find.text('Läuft morgen ab'), findsOneWidget);
  });

  testWidgets('shows no warning for fresh stock', (tester) async {
    await _pumpDetails(
      tester,
      _yoghurt(bestBeforeDate: CalendarDate(2026, 11, 30)),
    );

    expect(find.byType(ExpiryBadge), findsNothing);
  });

  testWidgets('a product without photo shows the placeholder', (tester) async {
    await _pumpDetails(tester, _yoghurt());

    expect(find.byType(ImagePlaceholder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'a product whose image file is missing shows the placeholder without error',
    (tester) async {
      // Reading the file needs real asynchronous file access.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _detailApp([_yoghurt(imagePath: 'product_images/missing.jpg')]),
        );
        await tester.pump();
        await tester.pump();
        // The thumbnail lies under the larger photo; both load the file.
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
            onError: (_, _) {},
          );
        }
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImagePlaceholder), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a stock item that no longer exists shows nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_detailApp([]));
    await tester.pumpAndSettle();

    expect(find.text('Joghurt'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
