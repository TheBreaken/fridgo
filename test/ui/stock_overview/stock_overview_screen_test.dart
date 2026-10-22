import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/homes/homes_screen.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';
import 'package:fridgo/ui/stock_overview/switch_home_sheet.dart';
import 'package:fridgo/ui/storage_locations/create_storage_location_sheet.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_screen.dart';

import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

Finder _emptyStateEmoji(String asset) => find.descendant(
  of: find.byType(EmptyState),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is SvgPicture &&
        (widget.bytesLoader as SvgAssetLoader).assetName == asset,
  ),
);

void main() {
  testWidgets('tapping a home opens its stock overview', (tester) async {
    await pumpApp(tester, now: _today);

    await createHomeAndOpenIt(tester, 'Berlin');

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Berlin')),
      findsOneWidget,
    );
  });

  testWidgets(
    'without storage locations an empty state invites to create one first',
    (tester) async {
      await pumpApp(tester, now: _today);

      await createHomeAndOpenIt(tester, 'Berlin');

      expect(_emptyStateEmoji(Emoji.jar), findsOneWidget);
      expect(find.text('Noch kein Lagerort'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets('the empty state action opens the storage location sheet', (
    tester,
  ) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');

    await tester.tap(find.widgetWithText(FilledButton, 'Lagerort anlegen'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateStorageLocationSheet), findsOneWidget);
  });

  testWidgets('a storage location created there invites to add food', (
    tester,
  ) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');
    await tester.tap(find.widgetWithText(FilledButton, 'Lagerort anlegen'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    await tester.pumpAndSettle();

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(_emptyStateEmoji(Emoji.carrot), findsOneWidget);
  });

  testWidgets('back from the storage locations returns to the stock', (
    tester,
  ) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');

    await createStorageLocationAndReturn(tester, 'Kühlschrank');

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.byType(StorageLocationsScreen), findsNothing);
  });

  testWidgets(
    'with a storage location but no stock an empty state invites to add food',
    (tester) async {
      await pumpApp(tester, now: _today);
      await createHomeAndOpenIt(tester, 'Berlin');

      await createStorageLocationAndReturn(tester, 'Kühlschrank');

      expect(_emptyStateEmoji(Emoji.carrot), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.widgetWithText(
            FilledButton,
            'Lebensmittel hinzufügen',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Lebensmittel hinzufügen'), findsOneWidget);
    },
  );

  testWidgets('the main action opens the add screen', (tester) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');

    await tester.tap(find.byTooltip('Lebensmittel hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStockItemScreen), findsOneWidget);
  });

  testWidgets('the empty state action opens the add screen', (tester) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');

    await tester.tap(
      find.widgetWithText(FilledButton, 'Lebensmittel hinzufügen'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AddStockItemScreen), findsOneWidget);
  });

  testWidgets('back returns to the homes', (tester) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(HomesScreen), findsOneWidget);
  });

  testWidgets('two taps on the title switch to another home', (tester) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await createHomeAndOpenIt(tester, 'Hamburg');

    await tester.tap(find.byTooltip('Wohnung wechseln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berlin'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Berlin')),
      findsOneWidget,
    );
    expect(find.text('Hamburg'), findsNothing);
    expect(_emptyStateEmoji(Emoji.carrot), findsOneWidget);
  });

  testWidgets('the home switcher marks the current home', (tester) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');

    await tester.tap(find.byTooltip('Wohnung wechseln'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SwitchHomeSheet),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('back after switching homes returns to the homes', (
    tester,
  ) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await createHomeAndOpenIt(tester, 'Hamburg');
    await tester.tap(find.byTooltip('Wohnung wechseln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berlin'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(HomesScreen), findsOneWidget);
  });

  testWidgets('tapping a card opens its details, and the photo flies along', (
    tester,
  ) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');
    await addStockItem(tester, name: 'Joghurt', quantity: '2');
    final cardPhoto = tester.widget<Hero>(
      find.descendant(
        of: find.byType(StockItemCard),
        matching: find.byType(Hero),
      ),
    );

    await tester.tap(find.text('Joghurt'));
    await tester.pumpAndSettle();

    expect(find.byType(StockItemDetailScreen), findsOneWidget);
    final detailPhoto = tester.widget<Hero>(
      find.descendant(
        of: find.byType(StockItemDetailScreen),
        matching: find.byType(Hero),
      ),
    );
    expect(detailPhoto.tag, cardPhoto.tag);
  });

  testWidgets('back from the details returns to the stock', (tester) async {
    await pumpApp(tester, now: _today);
    await createHomeAndOpenIt(tester, 'Berlin');
    await createStorageLocationAndReturn(tester, 'Kühlschrank');
    await addStockItem(tester, name: 'Joghurt', quantity: '2');
    await tester.tap(find.text('Joghurt'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(StockItemDetailScreen), findsNothing);
    expect(find.byType(StockItemCard), findsOneWidget);
  });
}
