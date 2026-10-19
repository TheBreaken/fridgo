import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';

import '../../data/repositories/fake_product_image_repository.dart';
import '../golden.dart';

final CalendarDate _today = CalendarDate(2026, 10, 16);
const _photoPath = 'product_images/milk.png';
const ValueKey<String> _goldenKey = ValueKey('golden');

// A green 1×1 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

StockItemDetails _milk({
  required CalendarDate bestBeforeDate,
  required String? imagePath,
}) => StockItemDetails(
  stockItem: StockItem(
    id: 'stock-item',
    productId: 'product',
    storageLocationId: 'storage-location',
    quantity: 1.5,
    unit: StockUnit.liter,
    bestBeforeDate: bestBeforeDate,
  ),
  product: Product(id: 'product', name: 'Milch', imagePath: imagePath),
  storageLocation: const StorageLocation(
    id: 'storage-location',
    homeId: 'home',
    name: 'Kühlschrank',
    kind: StorageLocationKind.refrigerator,
  ),
);

void main() {
  late Directory appDirectory;

  setUpAll(setUpGoldens);
  setUp(() {
    appDirectory = Directory.systemTemp.createTempSync('fridgo');
    File('${appDirectory.path}/$_photoPath')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_png);
  });
  tearDown(() => appDirectory.deleteSync(recursive: true));

  Future<void> pumpCard(WidgetTester tester, StockItemDetails details) =>
      pumpAndLoadImages(
        tester,
        ProviderScope(
          overrides: [
            productImageRepositoryProvider.overrideWithValue(
              FakeProductImageRepository()
                ..appDirectoryPath = appDirectory.path,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // Scrolls like the overview, so the card takes only its height.
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _goldenKey,
                  child: ColoredBox(
                    color: AppTheme.light.colorScheme.surfaceDim,
                    child: SizedBox(
                      width: 360,
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.l),
                        child: StockItemCard(
                          details: details,
                          today: _today,
                          onConsume: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  final cards = {
    'fresh': _milk(
      bestBeforeDate: CalendarDate(2026, 10, 24),
      imagePath: _photoPath,
    ),
    'expiring_soon': _milk(
      bestBeforeDate: CalendarDate(2026, 10, 17),
      imagePath: _photoPath,
    ),
    'expired': _milk(
      bestBeforeDate: CalendarDate(2026, 10, 14),
      imagePath: _photoPath,
    ),
    'without_photo': _milk(
      bestBeforeDate: CalendarDate(2026, 10, 24),
      imagePath: null,
    ),
  };

  for (final MapEntry(key: state, value: details) in cards.entries) {
    testGolden('a $state product card looks as approved', (tester) async {
      await pumpCard(tester, details);

      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/stock_item_card_$state.png'),
      );
    });
  }
}
