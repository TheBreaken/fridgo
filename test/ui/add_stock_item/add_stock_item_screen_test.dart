import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:fridgo/ui/add_stock_item/add_stock_item_screen.dart';
import 'package:fridgo/ui/add_stock_item/selected_product_card.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_screen.dart';

import '../../data/repositories/fake_product_image_repository.dart';
import '../app_flows.dart';

final _today = DateTime(2026, 10, 16, 9);

const _quantityError =
    'Bitte gib eine Menge über 0 mit höchstens drei Nachkommastellen ein.';

Future<void> _openAddScreen(
  WidgetTester tester, {
  FakeProductImageRepository? productImages,
}) async {
  await pumpApp(tester, now: _today, productImages: productImages);
  await createHomeAndOpenIt(tester, 'Berlin');
  await createStorageLocationAndReturn(tester, 'Kühlschrank');
  await createStorageLocationAndReturn(tester, 'Gefrierfach');
  await tester.tap(find.byTooltip('Lebensmittel hinzufügen'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _enter(WidgetTester tester, String label, String text) =>
    tester.enterText(_field(label), text);

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Hinzufügen');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pickDay(WidgetTester tester, String label, String day) async {
  await tester.ensureVisible(_field(label));
  await tester.tap(_field(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(day));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Finder _photoField(String label) => find.bySemanticsLabel(label);

Future<void> _choosePhotoAction(
  WidgetTester tester,
  String fieldLabel,
  String action,
) async {
  await tester.tap(_photoField(fieldLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Finder _suggestion(String name) => find.widgetWithText(InkWell, name);

Future<void> _addAndReopen(WidgetTester tester, String name) async {
  await _enter(tester, 'Name', name);
  await _submit(tester);
  await tester.tap(find.byTooltip('Lebensmittel hinzufügen'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String name) async {
  await _enter(tester, 'Name', name);
  await tester.pumpAndSettle();
}

bool _isSelected(WidgetTester tester, String chipLabel) => tester
    .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, chipLabel))
    .selected;

void main() {
  testWidgets('the form starts with one piece in the first storage location', (
    tester,
  ) async {
    await _openAddScreen(tester);

    expect(_isSelected(tester, 'Gefrierfach'), isTrue);
    expect(_isSelected(tester, 'Kühlschrank'), isFalse);
    expect(_isSelected(tester, 'Stück'), isTrue);
    expect(_fieldText(tester, 'Menge'), '1');
    expect(_fieldText(tester, 'Mindestens haltbar bis'), isEmpty);
    expect(_fieldText(tester, 'Geöffnet am'), isEmpty);
  });

  const blankNames = {'an empty name': '', 'a name of spaces': '   '};

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    testWidgets('$description shows an error and keeps the form open', (
      tester,
    ) async {
      await _openAddScreen(tester);
      await _enter(tester, 'Name', name);

      await _submit(tester);

      expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
      expect(find.byType(AddStockItemScreen), findsOneWidget);
    });
  }

  const invalidQuantities = {
    'a quantity of 0': '0',
    'a negative quantity': '-1',
    'an empty quantity': '',
    'a quantity with four decimals': '1,2345',
  };

  for (final MapEntry(key: description, value: quantity)
      in invalidQuantities.entries) {
    testWidgets('$description shows an error and keeps the form open', (
      tester,
    ) async {
      await _openAddScreen(tester);
      await _enter(tester, 'Name', 'Milch');
      await _enter(tester, 'Menge', quantity);

      await _submit(tester);

      expect(find.text(_quantityError), findsOneWidget);
      expect(find.byType(AddStockItemScreen), findsOneWidget);
    });
  }

  testWidgets('a picked best before date is shown as a German date', (
    tester,
  ) async {
    await _openAddScreen(tester);

    await _pickDay(tester, 'Mindestens haltbar bis', '25');

    expect(_fieldText(tester, 'Mindestens haltbar bis'), '25.10.2026');
  });

  testWidgets('a picked date can be removed again', (tester) async {
    await _openAddScreen(tester);
    await _pickDay(tester, 'Mindestens haltbar bis', '25');

    await tester.tap(find.byTooltip('Datum entfernen'));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'Mindestens haltbar bis'), isEmpty);
    expect(find.byTooltip('Datum entfernen'), findsNothing);
  });

  testWidgets('the opened date cannot lie after today', (tester) async {
    await _openAddScreen(tester);
    await tester.ensureVisible(_field('Geöffnet am'));

    await tester.tap(_field('Geöffnet am'));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, DateTime(2026, 10, 16));
  });

  testWidgets('the best before date may lie in the past', (tester) async {
    await _openAddScreen(tester);
    await tester.ensureVisible(_field('Mindestens haltbar bis'));

    await tester.tap(_field('Mindestens haltbar bis'));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate.isBefore(DateTime(2025, 10, 16)), isTrue);
  });

  testWidgets('a saved stock item is shown in the home', (tester) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Milch');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kühlschrank'));
    await _enter(tester, 'Menge', '1,5');
    await tester.tap(find.widgetWithText(ChoiceChip, 'l'));
    await _pickDay(tester, 'Mindestens haltbar bis', '25');

    await _submit(tester);

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    final card = find.ancestor(
      of: find.text('Milch'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: card, matching: find.text('1,5 l · MHD 25.10.2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Kühlschrank')),
      findsOneWidget,
    );
  });

  testWidgets('a saved stock item shows its expiry as of the clock', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Milch');
    await _pickDay(tester, 'Mindestens haltbar bis', '18');

    await _submit(tester);

    expect(find.text('Noch 2 Tage'), findsOneWidget);
  });

  testWidgets('a stock item without best before date shows only its quantity', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Äpfel');
    await _enter(tester, 'Menge', '6');

    await _submit(tester);

    expect(find.text('6 Stück'), findsOneWidget);
  });

  testWidgets('back without saving keeps the stock empty', (tester) async {
    await _openAddScreen(tester);
    await _enter(tester, 'Name', 'Milch');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.text('Noch keine Lebensmittel'), findsOneWidget);
  });

  testWidgets('the photo sheet offers camera and gallery but no removal', (
    tester,
  ) async {
    await _openAddScreen(tester);

    await tester.tap(_photoField('Foto hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.text('Foto aufnehmen'), findsOneWidget);
    expect(find.text('Aus Galerie wählen'), findsOneWidget);
    expect(find.text('Foto entfernen'), findsNothing);
  });

  const sources = {
    'a photo from the camera': ('Foto aufnehmen', PhotoSource.camera),
    'a photo from the gallery': ('Aus Galerie wählen', PhotoSource.gallery),
  };

  for (final MapEntry(key: description, value: (action, source))
      in sources.entries) {
    testWidgets('$description is shown in the form', (tester) async {
      final productImages = FakeProductImageRepository();
      final requestedSources = <PhotoSource>[];
      productImages.onPick = (source) async {
        requestedSources.add(source);
        return '/tmp/picked.jpg';
      };
      await _openAddScreen(tester, productImages: productImages);

      await _choosePhotoAction(tester, 'Foto hinzufügen', action);

      expect(requestedSources, [source]);
      expect(_photoField('Foto ändern'), findsOneWidget);
      expect(_photoField('Foto hinzufügen'), findsNothing);
    });
  }

  testWidgets('a picked photo can be removed again', (tester) async {
    await _openAddScreen(tester);
    await _choosePhotoAction(tester, 'Foto hinzufügen', 'Foto aufnehmen');

    await _choosePhotoAction(tester, 'Foto ändern', 'Foto entfernen');

    expect(_photoField('Foto hinzufügen'), findsOneWidget);
  });

  testWidgets('a saved stock item stores the picked photo', (tester) async {
    final productImages = FakeProductImageRepository();
    await _openAddScreen(tester, productImages: productImages);
    await _choosePhotoAction(tester, 'Foto hinzufügen', 'Aus Galerie wählen');
    await _enter(tester, 'Name', 'Milch');

    await _submit(tester);

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(productImages.storedImages.values, ['/tmp/picked_from_gallery.jpg']);
  });

  testWidgets('a removed photo is not stored', (tester) async {
    final productImages = FakeProductImageRepository();
    await _openAddScreen(tester, productImages: productImages);
    await _choosePhotoAction(tester, 'Foto hinzufügen', 'Foto aufnehmen');
    await _choosePhotoAction(tester, 'Foto ändern', 'Foto entfernen');
    await _enter(tester, 'Name', 'Milch');

    await _submit(tester);

    expect(productImages.storedImages, isEmpty);
  });

  testWidgets('back after picking a photo stores no image', (tester) async {
    final productImages = FakeProductImageRepository();
    await _openAddScreen(tester, productImages: productImages);
    await _choosePhotoAction(tester, 'Foto hinzufügen', 'Foto aufnehmen');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(productImages.storedImages, isEmpty);
  });

  testWidgets('a cancelled pick keeps the form without photo', (tester) async {
    final productImages = FakeProductImageRepository()
      ..onPick = (_) async => null;
    await _openAddScreen(tester, productImages: productImages);

    await _choosePhotoAction(tester, 'Foto hinzufügen', 'Foto aufnehmen');

    expect(_photoField('Foto hinzufügen'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  final pickErrors = {
    'denied camera access': (
      'Foto aufnehmen',
      const PhotoAccessDeniedException(PhotoSource.camera),
      'Fridgo darf die Kamera nicht benutzen. '
          'Du kannst das in den Einstellungen erlauben.',
    ),
    'denied photo access': (
      'Aus Galerie wählen',
      const PhotoAccessDeniedException(PhotoSource.gallery),
      'Fridgo darf nicht auf deine Fotos zugreifen. '
          'Du kannst das in den Einstellungen erlauben.',
    ),
    'a missing camera': (
      'Foto aufnehmen',
      const PhotoUnavailableException(
        PhotoSource.camera,
        'no_available_camera',
      ),
      'Das Foto hat nicht geklappt. '
          'Versuch es noch einmal oder trag das Lebensmittel ohne Foto ein.',
    ),
  };

  for (final MapEntry(key: description, value: (action, error, message))
      in pickErrors.entries) {
    testWidgets('$description shows a hint and the form still saves', (
      tester,
    ) async {
      final productImages = FakeProductImageRepository()
        ..onPick = (_) async => throw error;
      await _openAddScreen(tester, productImages: productImages);

      await _choosePhotoAction(tester, 'Foto hinzufügen', action);

      expect(find.text(message), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _enter(tester, 'Name', 'Milch');
      await _submit(tester);
      expect(find.byType(StockOverviewScreen), findsOneWidget);
      expect(find.text('Milch'), findsOneWidget);
      expect(productImages.storedImages, isEmpty);
    });
  }

  testWidgets('typing suggests existing products ignoring case and umlauts', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _addAndReopen(tester, 'Äpfel');
    await _addAndReopen(tester, 'Butter');

    await _type(tester, 'apf');

    expect(_suggestion('Äpfel'), findsOneWidget);
    expect(_suggestion('Butter'), findsNothing);
  });

  testWidgets('a chosen product replaces photo and name with its card', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _addAndReopen(tester, 'Milch');
    await _type(tester, 'mil');

    await tester.tap(_suggestion('Milch'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SelectedProductCard),
        matching: find.text('Milch'),
      ),
      findsOneWidget,
    );
    expect(_field('Name'), findsNothing);
    expect(_photoField('Foto hinzufügen'), findsNothing);
  });

  testWidgets('saving a chosen product adds stock without a second product', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _addAndReopen(tester, 'Milch');
    await _type(tester, 'mil');
    await tester.tap(_suggestion('Milch'));
    await tester.pumpAndSettle();
    await _pickDay(tester, 'Mindestens haltbar bis', '25');

    await _submit(tester);

    expect(find.byType(StockOverviewScreen), findsOneWidget);
    expect(find.text('Milch'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Lebensmittel hinzufügen'));
    await tester.pumpAndSettle();
    await _type(tester, 'mil');
    expect(_suggestion('Milch'), findsOneWidget);
  });

  testWidgets('a typed name of an existing product adds a new product', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _addAndReopen(tester, 'Milch');

    await _addAndReopen(tester, 'Milch');

    await _type(tester, 'mil');
    expect(_suggestion('Milch'), findsNWidgets(2));
  });

  testWidgets('clearing the chosen product brings back an empty form', (
    tester,
  ) async {
    await _openAddScreen(tester);
    await _addAndReopen(tester, 'Milch');
    await _type(tester, 'mil');
    await tester.tap(_suggestion('Milch'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Anderes Produkt eintragen'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectedProductCard), findsNothing);
    expect(_fieldText(tester, 'Name'), isEmpty);
    expect(_photoField('Foto hinzufügen'), findsOneWidget);
  });
}
