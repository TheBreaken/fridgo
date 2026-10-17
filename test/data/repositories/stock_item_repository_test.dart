import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<StorageLocation> _createStorageLocation(
  AppDatabase database, {
  String homeName = 'Berlin',
  String name = 'Kühlschrank',
}) async {
  final home = await HomeRepository(database).createHome(homeName);
  return await StorageLocationRepository(database).createStorageLocation(
    homeId: home.id,
    name: name,
    kind: StorageLocationKind.refrigerator,
  );
}

StockItemDraft _milk(
  StorageLocation storageLocation, {
  String productName = 'Milch',
  double quantity = 1,
  StockUnit unit = StockUnit.liter,
  CalendarDate? bestBeforeDate,
  CalendarDate? openedDate,
}) => StockItemDraft(
  productName: productName,
  storageLocationId: storageLocation.id,
  quantity: quantity,
  unit: unit,
  bestBeforeDate: bestBeforeDate,
  openedDate: openedDate,
);

void main() {
  group('in one storage location', _inOneStorageLocation);

  test('a stock item is still listed after reopening the file', () async {
    final directory = await Directory.systemTemp.createTemp('fridgo_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fridgo.sqlite');
    final firstSession = AppDatabase(NativeDatabase(file));
    final storageLocation = await _createStorageLocation(firstSession);
    final stockItem = await StockItemRepository(firstSession)
        .addStockItemWithNewProduct(
          _milk(storageLocation, bestBeforeDate: CalendarDate(2026, 10, 25)),
        );
    await firstSession.close();

    final secondSession = AppDatabase(NativeDatabase(file));
    addTearDown(secondSession.close);
    final listed = await StockItemRepository(secondSession)
        .watchStockItems(storageLocation.homeId)
        .first;

    expect(listed.single.stockItem, stockItem);
    expect(listed.single.product.name, 'Milch');
  });
}

void _inOneStorageLocation() {
  late AppDatabase database;
  late StockItemRepository repository;
  late StorageLocation fridge;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    repository = StockItemRepository(database);
    fridge = await _createStorageLocation(database);
  });

  Future<List<StockItemDetails>> listed() =>
      repository.watchStockItems(fridge.homeId).first;

  test('a home without stock lists none', () async {
    expect(await listed(), isEmpty);
  });

  test('an added stock item has the given values and UUIDs v4', () async {
    final stockItem = await repository.addStockItemWithNewProduct(
      _milk(
        fridge,
        quantity: 1.5,
        bestBeforeDate: CalendarDate(2026, 10, 25),
        openedDate: CalendarDate(2026, 10, 16),
      ),
    );

    expect(stockItem.id, matches(_uuidV4));
    expect(stockItem.productId, matches(_uuidV4));
    expect(stockItem.storageLocationId, fridge.id);
    expect(stockItem.quantity, 1.5);
    expect(stockItem.unit, StockUnit.liter);
    expect(stockItem.bestBeforeDate, CalendarDate(2026, 10, 25));
    expect(stockItem.openedDate, CalendarDate(2026, 10, 16));
  });

  test(
    'an added stock item is listed with its product and storage location',
    () async {
      final stockItem = await repository.addStockItemWithNewProduct(
        _milk(fridge),
      );

      final details = (await listed()).single;

      expect(details.stockItem, stockItem);
      expect(details.product.id, stockItem.productId);
      expect(details.product.name, 'Milch');
      expect(details.storageLocation, fridge);
    },
  );

  test('a stock item without dates is read back without dates', () async {
    await repository.addStockItemWithNewProduct(_milk(fridge));

    final stockItem = (await listed()).single.stockItem;

    expect(stockItem.bestBeforeDate, isNull);
    expect(stockItem.openedDate, isNull);
  });

  test('the image path of a product is stored as given', () async {
    await repository.addStockItemWithNewProduct(
      _milk(fridge),
      imagePath: 'product_images/milk.jpg',
    );

    final product = (await listed()).single.product;

    expect(product.imagePath, 'product_images/milk.jpg');
  });

  test('a product without photo has no image path', () async {
    await repository.addStockItemWithNewProduct(_milk(fridge));

    final product = (await listed()).single.product;

    expect(product.imagePath, isNull);
  });

  test(
    'the same product name with two best before dates gives two entries',
    () async {
      await repository.addStockItemWithNewProduct(
        _milk(fridge, bestBeforeDate: CalendarDate(2026, 10, 20)),
      );
      await repository.addStockItemWithNewProduct(
        _milk(fridge, bestBeforeDate: CalendarDate(2026, 11, 3)),
      );

      final bestBeforeDates = [
        for (final details in await listed()) details.stockItem.bestBeforeDate,
      ];

      expect(
        bestBeforeDates,
        unorderedEquals([
          CalendarDate(2026, 10, 20),
          CalendarDate(2026, 11, 3),
        ]),
      );
    },
  );

  test('every addition creates its own product', () async {
    final first = await repository.addStockItemWithNewProduct(_milk(fridge));
    final second = await repository.addStockItemWithNewProduct(_milk(fridge));

    expect(first.productId, isNot(second.productId));
    expect(await database.select(database.products).get(), hasLength(2));
  });

  const daylightSavingDates = {
    'summer time starts': ('2026-03-29', '2026-03-28'),
    'summer time ends': ('2026-10-25', '2026-10-24'),
  };

  for (final MapEntry(key: description, value: (bestBefore, opened))
      in daylightSavingDates.entries) {
    test(
      'dates around the day $description are stored as plain text',
      () async {
        await repository.addStockItemWithNewProduct(
          _milk(
            fridge,
            bestBeforeDate: CalendarDate.parse(bestBefore),
            openedDate: CalendarDate.parse(opened),
          ),
        );

        final row = await database
            .customSelect(
              'SELECT best_before_date, opened_date FROM stock_items',
            )
            .getSingle();

        expect(row.data, {
          'best_before_date': bestBefore,
          'opened_date': opened,
        });
      },
    );

    test('dates around the day $description are read back unchanged', () async {
      await repository.addStockItemWithNewProduct(
        _milk(
          fridge,
          bestBeforeDate: CalendarDate.parse(bestBefore),
          openedDate: CalendarDate.parse(opened),
        ),
      );

      final stockItem = (await listed()).single.stockItem;

      expect(stockItem.bestBeforeDate, CalendarDate.parse(bestBefore));
      expect(stockItem.openedDate, CalendarDate.parse(opened));
    });
  }

  const quantities = {
    'the smallest allowed quantity': 0.001,
    'a quantity with one decimal': 1.5,
    'a large quantity': 99999.999,
  };

  for (final MapEntry(key: description, value: quantity)
      in quantities.entries) {
    test('$description is read back exactly', () async {
      await repository.addStockItemWithNewProduct(
        _milk(fridge, quantity: quantity),
      );

      expect((await listed()).single.stockItem.quantity, quantity);
    });
  }

  for (final unit in StockUnit.values) {
    test('the unit ${unit.name} is stored and read back', () async {
      await repository.addStockItemWithNewProduct(_milk(fridge, unit: unit));

      expect((await listed()).single.stockItem.unit, unit);
    });
  }

  test('a product name with umlauts is stored unchanged', () async {
    await repository.addStockItemWithNewProduct(
      _milk(fridge, productName: 'Käse aus Österreich, groß'),
    );

    expect((await listed()).single.product.name, 'Käse aus Österreich, groß');
  });

  const sortingCases = {
    'the earliest best before date comes first': (
      added: [
        ('Milch', '2026-10-25'),
        ('Quark', '2026-10-18'),
        ('Butter', '2026-11-02'),
      ],
      sorted: ['Quark', 'Milch', 'Butter'],
    ),
    'dates across a year boundary keep their order': (
      added: [
        ('Eier', '2027-01-02'),
        ('Joghurt', '2026-12-31'),
        ('Sahne', '2026-02-01'),
      ],
      sorted: ['Sahne', 'Joghurt', 'Eier'],
    ),
    'equal best before dates are sorted by name ignoring case': (
      added: [
        ('quark', '2026-10-20'),
        ('Butter', '2026-10-20'),
        ('eier', '2026-10-20'),
      ],
      sorted: ['Butter', 'eier', 'quark'],
    ),
    'stock items without best before date come last, sorted by name': (
      added: [('brot', null), ('Zucker', '2026-10-30'), ('Apfel', null)],
      sorted: ['Zucker', 'Apfel', 'brot'],
    ),
  };

  for (final MapEntry(key: description, value: (:added, :sorted))
      in sortingCases.entries) {
    test('stock items are sorted by best before date: $description', () async {
      for (final (productName, bestBefore) in added) {
        await repository.addStockItemWithNewProduct(
          _milk(
            fridge,
            productName: productName,
            bestBeforeDate: bestBefore == null
                ? null
                : CalendarDate.parse(bestBefore),
          ),
        );
      }

      expect([
        for (final details in await listed()) details.product.name,
      ], sorted);
    });
  }

  test('stock items of all storage locations of the home are listed', () async {
    final freezer = await StorageLocationRepository(database)
        .createStorageLocation(
          homeId: fridge.homeId,
          name: 'Gefrierfach',
          kind: StorageLocationKind.freezer,
        );
    await repository.addStockItemWithNewProduct(_milk(fridge));
    await repository.addStockItemWithNewProduct(
      _milk(freezer, productName: 'Erbsen'),
    );

    expect(
      [for (final details in await listed()) details.storageLocation.name],
      ['Gefrierfach', 'Kühlschrank'],
    );
  });

  test('stock items of another home are not listed', () async {
    final otherFridge = await _createStorageLocation(
      database,
      homeName: 'Hamburg',
    );
    await repository.addStockItemWithNewProduct(_milk(otherFridge));

    expect(await listed(), isEmpty);
    expect(
      await repository.watchStockItems(otherFridge.homeId).first,
      hasLength(1),
    );
  });

  test('a stock item for an unknown storage location is rejected without '
      'leaving a product behind', () async {
    await expectLater(
      repository.addStockItemWithNewProduct(
        const StockItemDraft(
          productName: 'Milch',
          storageLocationId: '00000000-0000-4000-8000-000000000000',
          quantity: 1,
          unit: StockUnit.liter,
        ),
      ),
      throwsA(
        isA<SqliteException>().having(
          (error) => error.message,
          'message',
          contains('FOREIGN KEY constraint failed'),
        ),
      ),
    );

    expect(await database.select(database.products).get(), isEmpty);
    expect(await database.select(database.stockItems).get(), isEmpty);
  });

  test('a stock item added later appears in a running listing', () async {
    final listings = <List<StockItemDetails>>[];
    final subscription = repository
        .watchStockItems(fridge.homeId)
        .listen(listings.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await repository.addStockItemWithNewProduct(_milk(fridge));
    await pumpEventQueue();

    expect([for (final listing in listings) listing.length], [0, 1]);
  });
}
