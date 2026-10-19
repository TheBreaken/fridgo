import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_view_model.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';

import '../../data/repositories/fake_product_image_repository.dart';
import '../golden.dart';

const _homeId = 'home';
const _photoPath = 'product_images/photo.png';
const ValueKey<String> _goldenKey = ValueKey('golden');

// A green 1×1 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

const _refrigerator = StorageLocation(
  id: 'refrigerator',
  homeId: _homeId,
  name: 'Kühlschrank',
  kind: StorageLocationKind.refrigerator,
);
const _freezer = StorageLocation(
  id: 'freezer',
  homeId: _homeId,
  name: 'Gefrierfach',
  kind: StorageLocationKind.freezer,
);
const _pantry = StorageLocation(
  id: 'pantry',
  homeId: _homeId,
  name: 'Vorrat',
  kind: StorageLocationKind.pantry,
);

StockItemDetails _stockItem(
  String name, {
  required StorageLocation storageLocation,
  required double quantity,
  required StockUnit unit,
  CalendarDate? bestBeforeDate,
  String? imagePath,
}) => StockItemDetails(
  stockItem: StockItem(
    id: name,
    productId: name,
    storageLocationId: storageLocation.id,
    quantity: quantity,
    unit: unit,
    bestBeforeDate: bestBeforeDate,
  ),
  product: Product(id: name, name: name, imagePath: imagePath),
  storageLocation: storageLocation,
);

// In the order the repository sorts them: earliest best before date first.
final List<StockItemDetails> _stock = [
  _stockItem(
    'Joghurt',
    storageLocation: _refrigerator,
    quantity: 2,
    unit: StockUnit.piece,
    bestBeforeDate: CalendarDate(2026, 10, 14),
  ),
  _stockItem(
    'Milch',
    storageLocation: _refrigerator,
    quantity: 1.5,
    unit: StockUnit.liter,
    bestBeforeDate: CalendarDate(2026, 10, 17),
    imagePath: _photoPath,
  ),
  _stockItem(
    'Erbsen',
    storageLocation: _freezer,
    quantity: 450,
    unit: StockUnit.gram,
    bestBeforeDate: CalendarDate(2027, 3, 1),
    imagePath: _photoPath,
  ),
  _stockItem(
    'Reis',
    storageLocation: _pantry,
    quantity: 1,
    unit: StockUnit.package,
  ),
];

class _FixedStorageLocations extends StorageLocationsViewModel {
  new(super.homeId, this._storageLocations);

  final List<StorageLocation> _storageLocations;

  @override
  Stream<List<StorageLocation>> build() => Stream.value(_storageLocations);
}

void main() {
  late Directory appDirectory;

  setUpAll(loadAppFonts);
  setUp(() {
    appDirectory = Directory.systemTemp.createTempSync('fridgo');
    File('${appDirectory.path}/$_photoPath')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_png);
  });
  tearDown(() => appDirectory.deleteSync(recursive: true));

  Future<void> pumpOverview(
    WidgetTester tester,
    List<StockItemDetails> stock,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpAndLoadImages(
      tester,
      ProviderScope(
        overrides: [
          homeProvider.overrideWith(
            (ref, homeId) => Stream.value(Home(id: homeId, name: 'Berlin')),
          ),
          storageLocationsViewModelProvider.overrideWith2(
            (homeId) =>
                _FixedStorageLocations(homeId, [_refrigerator, _freezer]),
          ),
          stockOverviewProvider.overrideWith(
            (ref, homeId) => Stream.value(stock),
          ),
          todayProvider.overrideWithValue(CalendarDate(2026, 10, 16)),
          productImageRepositoryProvider.overrideWithValue(
            FakeProductImageRepository()..appDirectoryPath = appDirectory.path,
          ),
        ],
        child: RepaintBoundary(
          key: _goldenKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Opened on top of a first page, as from the homes, so the back
            // button shows.
            initialRoute: '/overview',
            routes: {
              '/': (context) => const SizedBox.shrink(),
              '/overview': (context) =>
                  const StockOverviewScreen(homeId: _homeId),
            },
          ),
        ),
      ),
    );
  }

  testGolden('the overview with stock looks as approved', (tester) async {
    await pumpOverview(tester, _stock);

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/stock_overview_with_stock.png'),
    );
  });

  testGolden('the overview without stock looks as approved', (tester) async {
    await pumpOverview(tester, []);

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/stock_overview_empty.png'),
    );
  });
}
