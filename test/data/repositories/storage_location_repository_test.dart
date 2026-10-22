import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/product_repository.dart';
import 'package:fridgo/data/repositories/stock_item_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/home.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/domain/storage_location.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

AppDatabase _createDatabase() {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}

Future<List<String>> _storageLocationNames(
  StorageLocationRepository repository,
  String homeId,
) async {
  final storageLocations = await repository.watchStorageLocations(homeId).first;
  return [for (final storageLocation in storageLocations) storageLocation.name];
}

void main() {
  group('in one home', _inOneHome);
  group('changing storage locations', _changingStorageLocations);

  test('a storage location is still listed after reopening the file', () async {
    final directory = await Directory.systemTemp.createTemp('fridgo_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fridgo.sqlite');
    final firstSession = AppDatabase(NativeDatabase(file));
    final fileHome = await HomeRepository(firstSession).createHome('Berlin');
    final storageLocation = await StorageLocationRepository(firstSession)
        .createStorageLocation(
          homeId: fileHome.id,
          name: 'Vorrat',
          kind: StorageLocationKind.pantry,
        );
    await firstSession.close();

    final secondSession = AppDatabase(NativeDatabase(file));
    addTearDown(secondSession.close);
    final storageLocations = await StorageLocationRepository(secondSession)
        .watchStorageLocations(fileHome.id)
        .first;

    expect(storageLocations, [storageLocation]);
  });
}

void _inOneHome() {
  late AppDatabase database;
  late StorageLocationRepository repository;
  late Home home;

  setUp(() async {
    database = _createDatabase();
    repository = StorageLocationRepository(database);
    home = await HomeRepository(database).createHome('Berlin');
  });

  Future<StorageLocation> createFridge({String name = 'Kühlschrank'}) =>
      repository.createStorageLocation(
        homeId: home.id,
        name: name,
        kind: StorageLocationKind.refrigerator,
      );

  test('a home without storage locations lists none', () async {
    final storageLocations = await repository
        .watchStorageLocations(home.id)
        .first;

    expect(storageLocations, isEmpty);
  });

  test(
    'a created storage location has the given values and a UUID v4',
    () async {
      final storageLocation = await createFridge();

      expect(storageLocation.homeId, home.id);
      expect(storageLocation.name, 'Kühlschrank');
      expect(storageLocation.kind, StorageLocationKind.refrigerator);
      expect(storageLocation.id, matches(_uuidV4));
    },
  );

  test('a created storage location is listed', () async {
    final storageLocation = await createFridge();

    expect(await repository.watchStorageLocations(home.id).first, [
      storageLocation,
    ]);
  });

  test('only the storage locations of the given home are listed', () async {
    final otherHome = await HomeRepository(database).createHome('Hamburg');
    await createFridge(name: 'Berliner Kühlschrank');
    await repository.createStorageLocation(
      homeId: otherHome.id,
      name: 'Hamburger Kühlschrank',
      kind: StorageLocationKind.refrigerator,
    );

    expect(await _storageLocationNames(repository, home.id), [
      'Berliner Kühlschrank',
    ]);
    expect(await _storageLocationNames(repository, otherHome.id), [
      'Hamburger Kühlschrank',
    ]);
  });

  test('two storage locations with the same name are both kept', () async {
    final first = await createFridge();
    final second = await createFridge();

    expect(first.id, isNot(second.id));
    expect(await _storageLocationNames(repository, home.id), [
      'Kühlschrank',
      'Kühlschrank',
    ]);
  });

  test('a name with umlauts is stored unchanged', () async {
    await createFridge(name: 'Getränkekühlschrank Größe XL');

    expect(await _storageLocationNames(repository, home.id), [
      'Getränkekühlschrank Größe XL',
    ]);
  });

  test('storage locations are sorted by name ignoring case', () async {
    await createFridge(name: 'vorrat');
    await createFridge(name: 'Keller');
    await createFridge(name: 'gefrierfach');

    expect(await _storageLocationNames(repository, home.id), [
      'gefrierfach',
      'Keller',
      'vorrat',
    ]);
  });

  for (final kind in StorageLocationKind.values) {
    test('the kind ${kind.name} is stored and read back', () async {
      await repository.createStorageLocation(
        homeId: home.id,
        name: 'Lagerort',
        kind: kind,
      );

      final storageLocations = await repository
          .watchStorageLocations(home.id)
          .first;

      expect(storageLocations.single.kind, kind);
    });
  }

  test('a storage location for an unknown home is rejected', () async {
    await expectLater(
      repository.createStorageLocation(
        homeId: '00000000-0000-4000-8000-000000000000',
        name: 'Kühlschrank',
        kind: StorageLocationKind.refrigerator,
      ),
      throwsA(
        isA<SqliteException>().having(
          (error) => error.message,
          'message',
          contains('FOREIGN KEY constraint failed'),
        ),
      ),
    );

    expect(
      await _storageLocationNames(
        repository,
        '00000000-0000-4000-8000-000000000000',
      ),
      isEmpty,
    );
  });

  test(
    'a storage location created later appears in a running listing',
    () async {
      final listings = <List<StorageLocation>>[];
      final subscription = repository
          .watchStorageLocations(home.id)
          .listen(listings.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      final storageLocation = await createFridge();
      await pumpEventQueue();

      expect(listings, [
        <StorageLocation>[],
        [storageLocation],
      ]);
    },
  );

  test('watching a home gives that home', () async {
    expect(await HomeRepository(database).watchHome(home.id).first, home);
  });
}

void _changingStorageLocations() {
  late AppDatabase database;
  late StorageLocationRepository repository;
  late Home home;

  setUp(() async {
    database = _createDatabase();
    repository = StorageLocationRepository(database);
    home = await HomeRepository(database).createHome('Berlin');
  });

  Future<StorageLocation> createFridge() => repository.createStorageLocation(
    homeId: home.id,
    name: 'Kühlschrank',
    kind: StorageLocationKind.refrigerator,
  );

  Future<StockItem> addStockItem(String storageLocationId, String product) =>
      StockItemRepository(database).addStockItemWithNewProduct(
        StockItemDraft(
          storageLocationId: storageLocationId,
          quantity: 1,
          unit: StockUnit.piece,
        ),
        productName: product,
      );

  Future<List<String>> stockItemIds() async => [
    for (final row in await database.select(database.stockItems).get()) row.id,
  ];

  test('an updated storage location is listed with name and kind', () async {
    final fridge = await createFridge();
    final freezer = fridge.copyWith(
      name: 'Gefrierschrank',
      kind: StorageLocationKind.freezer,
    );

    await repository.updateStorageLocation(freezer);

    expect(await repository.watchStorageLocations(home.id).first, [freezer]);
  });

  test('updating an unknown storage location throws', () async {
    final unknown = StorageLocation(
      id: 'unknown',
      homeId: home.id,
      name: 'Vorrat',
      kind: StorageLocationKind.pantry,
    );

    await expectLater(
      repository.updateStorageLocation(unknown),
      throwsStateError,
    );
  });

  test('only the stock items of the storage location are counted', () async {
    final fridge = await createFridge();
    final pantry = await createFridge();
    await addStockItem(fridge.id, 'Milch');
    await addStockItem(fridge.id, 'Butter');
    await addStockItem(pantry.id, 'Reis');

    expect(await repository.countStockItems(fridge.id), 2);
  });

  test('an empty storage location has no stock items', () async {
    final fridge = await createFridge();

    expect(await repository.countStockItems(fridge.id), 0);
  });

  test('deleting a storage location deletes its stock items', () async {
    final fridge = await createFridge();
    await addStockItem(fridge.id, 'Milch');

    await repository.deleteStorageLocation(fridge.id);

    expect(await repository.watchStorageLocations(home.id).first, isEmpty);
    expect(await stockItemIds(), isEmpty);
  });

  test('deleting a storage location keeps the products and other stock '
      'items', () async {
    final fridge = await createFridge();
    final pantry = await createFridge();
    final milk = await addStockItem(fridge.id, 'Milch');
    final rice = await addStockItem(pantry.id, 'Reis');

    await repository.deleteStorageLocation(fridge.id);

    final products = await ProductRepository(database).getProducts();
    expect(
      {for (final product in products) product.id},
      {milk.productId, rice.productId},
    );
    expect(await stockItemIds(), [rice.id]);
    expect(await repository.watchStorageLocations(home.id).first, [pantry]);
  });

  test(
    'a failed delete keeps the storage location with its stock items',
    () async {
      final fridge = await createFridge();
      final milk = await addStockItem(fridge.id, 'Milch');
      await database.customStatement(
        'CREATE TRIGGER fail_storage_location_delete '
        'BEFORE DELETE ON storage_locations '
        "BEGIN SELECT RAISE(ABORT, 'storage location delete failed'); END",
      );

      await expectLater(
        repository.deleteStorageLocation(fridge.id),
        throwsA(isA<SqliteException>()),
      );

      expect(await repository.watchStorageLocations(home.id).first, [fridge]);
      expect(await stockItemIds(), [milk.id]);
    },
  );
}
