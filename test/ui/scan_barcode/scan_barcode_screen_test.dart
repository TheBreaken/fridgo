import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/repositories/open_food_facts_repository.dart';
import 'package:fridgo/domain/barcode_scan.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/add_stock_item/selected_product_card.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../data/fake_barcode_scanner.dart';
import '../../data/repositories/fake_product_image_repository.dart';
import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

const _milkBarcode = '4012345678901';
const _otherBarcode = '4098765432109';

const _lookupFoundHint =
    'Name und Nährwerte von Open Food Facts (ODbL). Bitte prüfen.';
const _lookupFoundWithImageHint =
    'Name, Nährwerte und Bild von Open Food Facts (ODbL, Bild CC BY-SA). '
    'Bitte prüfen.';

const _imageUrl =
    'https://images.openfoodfacts.org/images/products/401/234/567/8901/front_de.3.400.jpg';
const _fullImageUrl =
    'https://images.openfoodfacts.org/images/products/401/234/567/8901/front_de.3.full.jpg';

Future<FakeBarcodeScanner> _openFridge(
  WidgetTester tester, {
  OpenFoodFactsRepository? openFoodFacts,
  FakeProductImageRepository? productImages,
}) async {
  final scanner = FakeBarcodeScanner();
  await pumpApp(
    tester,
    now: _today,
    barcodeScanner: scanner,
    openFoodFacts: openFoodFacts,
    productImages: productImages,
  );
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  return scanner;
}

OpenFoodFactsRepository _openFoodFactsAnswering(
  Future<http.Response> Function() answer,
) => OpenFoodFactsRepository(MockClient((_) => answer()));

Future<http.Response> _productFound(Map<String, Object?> product) async =>
    http.Response.bytes(
      utf8.encode(jsonEncode({'product': product})),
      HttpStatus.ok,
    );

/// Finds milk with an image and answers the image request with [image].
OpenFoodFactsRepository _openFoodFactsWithImage(
  Future<http.Response> Function() image,
) => OpenFoodFactsRepository(
  MockClient(
    (request) => request.url.toString() == _fullImageUrl
        ? image()
        : _productFound({
            'product_name_de': 'Bio-Vollmilch',
            'image_front_url': _imageUrl,
          }),
  ),
);

Future<http.Response> _jpeg() async =>
    http.Response.bytes([0xFF, 0xD8, 0xFF], HttpStatus.ok);

/// Scans without settling, which the spinner of the lookup would prevent.
Future<void> _scanWhileLookingUp(
  WidgetTester tester,
  FakeBarcodeScanner scanner,
  String barcode,
) async {
  await tester.tap(find.byTooltip('Lebensmittel scannen'));
  await tester.pumpAndSettle();
  scanner.show(barcode);
  // The hit animation, the page transition and the database lookup.
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _field(String label) => find.widgetWithText(TextField, label);

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Finder _selectedProduct(String name) =>
    find.widgetWithText(SelectedProductCard, name);

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Hinzufügen');
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _addScanned(
  WidgetTester tester,
  FakeBarcodeScanner scanner, {
  required String barcode,
  required String name,
}) async {
  await scanBarcode(tester, scanner, barcode);
  await tester.enterText(_field('Name'), name);
  await _submit(tester);
}

Future<void> _chooseSuggestion(WidgetTester tester, String name) async {
  await tester.enterText(_field('Name'), name.substring(0, 3).toLowerCase());
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(InkWell, name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unknown barcode opens the empty form showing the barcode', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);

    await scanBarcode(tester, scanner, _milkBarcode);

    expect(find.byType(AddStockItemScreen), findsOneWidget);
    expect(find.text('Barcode $_milkBarcode'), findsOneWidget);
    expect(find.byType(SelectedProductCard), findsNothing);
  });

  testWidgets('a known barcode selects its product', (tester) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');

    await scanBarcode(tester, scanner, _milkBarcode);

    expect(_selectedProduct('Milch'), findsOneWidget);
  });

  testWidgets('a known product is stored in 2 taps from the overview', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');

    // Tap 1: the camera button. Scanning needs no tap.
    await scanBarcode(tester, scanner, _milkBarcode);
    // Tap 2: add.
    await _submit(tester);

    expect(find.widgetWithText(StockItemCard, 'Milch'), findsNWidgets(2));
  });

  testWidgets('a scanned barcode is given to the chosen existing product', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await addStockItem(tester, name: 'Milch', quantity: '1');
    await scanBarcode(tester, scanner, _milkBarcode);
    await _chooseSuggestion(tester, 'Milch');
    await _submit(tester);

    await scanBarcode(tester, scanner, _milkBarcode);

    expect(_selectedProduct('Milch'), findsOneWidget);
  });

  testWidgets('a product with another barcode keeps it, and the form says so', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');
    await scanBarcode(tester, scanner, _otherBarcode);

    await _chooseSuggestion(tester, 'Milch');

    expect(
      find.text(
        'Das Produkt hat schon einen anderen Barcode, '
        'der gescannte wird nicht übernommen.',
      ),
      findsOneWidget,
    );
    await _submit(tester);
    await scanBarcode(tester, scanner, _otherBarcode);
    expect(find.byType(SelectedProductCard), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await scanBarcode(tester, scanner, _milkBarcode);
    expect(_selectedProduct('Milch'), findsOneWidget);
  });

  testWidgets('clearing the product of a known barcode drops the barcode', (
    tester,
  ) async {
    final scanner = await _openFridge(tester);
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');
    await scanBarcode(tester, scanner, _milkBarcode);

    await tester.tap(find.byTooltip('Anderes Produkt eintragen'));
    await tester.pumpAndSettle();

    expect(find.text('Barcode $_milkBarcode'), findsNothing);
    await tester.enterText(_field('Name'), 'Hafermilch');
    await _submit(tester);
    expect(find.widgetWithText(StockItemCard, 'Hafermilch'), findsOneWidget);
  });

  testWidgets('adding without barcode opens the empty form', (tester) async {
    await _openFridge(tester);

    await openAddStockItem(tester);

    expect(find.byType(AddStockItemScreen), findsOneWidget);
    expect(find.textContaining('Barcode'), findsNothing);
  });

  final cameraErrorCases = {
    'a denied camera leads to the form with a hint': (
      error: const CameraAccessDeniedException(),
      hint:
          'Fridgo darf die Kamera nicht benutzen. Du kannst das in den '
          'Einstellungen erlauben. Bis dahin trägst du das Lebensmittel hier '
          'ein.',
    ),
    'a missing camera leads to the form with a hint': (
      error: const CameraUnavailableException('unsupported'),
      hint:
          'Die Kamera ist gerade nicht verfügbar. '
          'Trag das Lebensmittel hier ein.',
    ),
  };
  for (final MapEntry(key: description, value: (:error, :hint))
      in cameraErrorCases.entries) {
    testWidgets(description, (tester) async {
      final scanner = await _openFridge(tester);
      scanner.startError = error;

      await tester.tap(find.byTooltip('Lebensmittel scannen'));
      await tester.pumpAndSettle();

      expect(find.byType(AddStockItemScreen), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
    });
  }

  testWidgets('a product only Open Food Facts knows is stored in 2 taps', (
    tester,
  ) async {
    final scanner = await _openFridge(
      tester,
      openFoodFacts: _openFoodFactsAnswering(
        () => _productFound({'product_name_de': 'Bio-Vollmilch'}),
      ),
    );

    // Tap 1: the camera button. Scanning needs no tap.
    await scanBarcode(tester, scanner, _milkBarcode);
    expect(_fieldText(tester, 'Name'), 'Bio-Vollmilch');
    expect(find.text(_lookupFoundHint), findsOneWidget);
    // Tap 2: add.
    await _submit(tester);

    expect(find.widgetWithText(StockItemCard, 'Bio-Vollmilch'), findsOneWidget);
  });

  testWidgets('the nutrition facts from Open Food Facts are filled in', (
    tester,
  ) async {
    final scanner = await _openFridge(
      tester,
      openFoodFacts: _openFoodFactsAnswering(
        () => _productFound({
          'product_name': 'Vollmilch',
          'nutriments': {'energy-kcal_100g': 64, 'fat_100g': 3.8},
        }),
      ),
    );

    await scanBarcode(tester, scanner, _milkBarcode);
    await tester.ensureVisible(find.text('Nährwerte (optional)'));
    await tester.tap(find.text('Nährwerte (optional)'));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'Brennwert'), '64');
    expect(_fieldText(tester, 'Fett'), '3,8');
    expect(_fieldText(tester, 'Eiweiß'), isEmpty);
  });

  testWidgets('the lookup shows that it is loading and can be cancelled', (
    tester,
  ) async {
    final answer = Completer<http.Response>();
    final scanner = await _openFridge(
      tester,
      openFoodFacts: _openFoodFactsAnswering(() => answer.future),
    );
    await _scanWhileLookingUp(tester, scanner, _milkBarcode);
    expect(find.text('Suche bei Open Food Facts …'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    answer.complete(await _productFound({'product_name': 'Vollmilch'}));
    await tester.pumpAndSettle();

    expect(find.text('Suche bei Open Food Facts …'), findsNothing);
    expect(_fieldText(tester, 'Name'), isEmpty);
    expect(find.text(_lookupFoundHint), findsNothing);
  });

  testWidgets('a name typed during the lookup is kept', (tester) async {
    final answer = Completer<http.Response>();
    final scanner = await _openFridge(
      tester,
      openFoodFacts: _openFoodFactsAnswering(() => answer.future),
    );
    await _scanWhileLookingUp(tester, scanner, _milkBarcode);

    await tester.enterText(_field('Name'), 'Meine Milch');
    answer.complete(await _productFound({'product_name': 'Vollmilch'}));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'Name'), 'Meine Milch');
  });

  testWidgets('a known barcode does not ask Open Food Facts', (tester) async {
    var requests = 0;
    final scanner = await _openFridge(
      tester,
      openFoodFacts: _openFoodFactsAnswering(() async {
        requests++;
        return http.Response('', HttpStatus.notFound);
      }),
    );
    await _addScanned(tester, scanner, barcode: _milkBarcode, name: 'Milch');

    await scanBarcode(tester, scanner, _milkBarcode);

    expect(requests, 1);
  });

  final lookupFailureCases =
      <String, ({Future<http.Response> Function() answer, String hint})>{
        'no network': (
          answer: () => throw const SocketException('Failed host lookup'),
          hint:
              'Open Food Facts ist gerade nicht erreichbar. '
              'Bitte trag das Produkt selbst ein.',
        ),
        'a timeout': (
          answer: () => Completer<http.Response>().future,
          hint:
              'Open Food Facts ist gerade nicht erreichbar. '
              'Bitte trag das Produkt selbst ein.',
        ),
        'an unknown product': (
          answer: () async => http.Response('', HttpStatus.notFound),
          hint:
              'Open Food Facts kennt das Produkt nicht. '
              'Bitte trag es selbst ein.',
        ),
        'an answer without name': (
          answer: () => _productFound({
            'nutriments': {'fat_100g': 3.8},
          }),
          hint:
              'Open Food Facts kennt das Produkt nur teilweise. '
              'Bitte trag den Namen ein.',
        ),
      };
  for (final MapEntry(key: description, value: (:answer, :hint))
      in lookupFailureCases.entries) {
    testWidgets('$description leads to manual entry with a hint', (
      tester,
    ) async {
      final scanner = await _openFridge(
        tester,
        openFoodFacts: _openFoodFactsAnswering(answer),
      );

      await _scanWhileLookingUp(tester, scanner, _milkBarcode);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text(hint), findsOneWidget);
      expect(_fieldText(tester, 'Name'), isEmpty);
      await tester.enterText(_field('Name'), 'Milch');
      await _submit(tester);
      expect(find.widgetWithText(StockItemCard, 'Milch'), findsOneWidget);
    });
  }

  testWidgets('the image from Open Food Facts becomes the product photo', (
    tester,
  ) async {
    final productImages = FakeProductImageRepository();
    final scanner = await _openFridge(
      tester,
      openFoodFacts: _openFoodFactsWithImage(_jpeg),
      productImages: productImages,
    );

    await scanBarcode(tester, scanner, _milkBarcode);
    expect(find.bySemanticsLabel('Foto ändern'), findsOneWidget);
    expect(find.text(_lookupFoundWithImageHint), findsOneWidget);
    await _submit(tester);

    expect(productImages.temporaryImages.values.single, [0xFF, 0xD8, 0xFF]);
    expect(productImages.storedImages.values.single, '/tmp/downloaded_1.jpg');
  });

  final imageFailureCases = <String, Future<http.Response> Function()>{
    'a missing image': () async => http.Response('', HttpStatus.notFound),
    'no network for the image': () =>
        throw const SocketException('Failed host lookup'),
  };
  for (final MapEntry(key: description, value: image)
      in imageFailureCases.entries) {
    testWidgets('$description adds the product without photo', (tester) async {
      final productImages = FakeProductImageRepository();
      final scanner = await _openFridge(
        tester,
        openFoodFacts: _openFoodFactsWithImage(image),
        productImages: productImages,
      );

      await scanBarcode(tester, scanner, _milkBarcode);
      expect(find.bySemanticsLabel('Foto hinzufügen'), findsOneWidget);
      expect(find.text(_lookupFoundHint), findsOneWidget);
      await _submit(tester);

      expect(productImages.storedImages, isEmpty);
      expect(
        find.widgetWithText(StockItemCard, 'Bio-Vollmilch'),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'cancelling while the image loads keeps the name, not the image',
    (tester) async {
      final image = Completer<http.Response>();
      final productImages = FakeProductImageRepository();
      final scanner = await _openFridge(
        tester,
        openFoodFacts: _openFoodFactsWithImage(() => image.future),
        productImages: productImages,
      );
      await _scanWhileLookingUp(tester, scanner, _milkBarcode);
      expect(_fieldText(tester, 'Name'), 'Bio-Vollmilch');

      await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
      await tester.pumpAndSettle();
      image.complete(await _jpeg());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Foto hinzufügen'), findsOneWidget);
      expect(find.text(_lookupFoundWithImageHint), findsNothing);
      await _submit(tester);
      expect(productImages.storedImages, isEmpty);
    },
  );

  testWidgets('a photo taken while the image loads is kept', (tester) async {
    final image = Completer<http.Response>();
    final productImages = FakeProductImageRepository();
    final scanner = await _openFridge(
      tester,
      openFoodFacts: _openFoodFactsWithImage(() => image.future),
      productImages: productImages,
    );
    await _scanWhileLookingUp(tester, scanner, _milkBarcode);

    await tester.tap(find.bySemanticsLabel('Foto hinzufügen'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Foto aufnehmen'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    image.complete(await _jpeg());
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(
      productImages.storedImages.values.single,
      '/tmp/picked_from_camera.jpg',
    );
  });
}
