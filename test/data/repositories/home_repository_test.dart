import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

HomeRepository _createRepository() {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(
        AppDatabase(NativeDatabase.memory()),
      ),
    ],
  );
  addTearDown(() async {
    await container.read(appDatabaseProvider).close();
    container.dispose();
  });
  return container.read(homeRepositoryProvider);
}

Future<List<String>> _homeNames(HomeRepository repository) async {
  final homes = await repository.watchHomes().first;
  return [for (final home in homes) home.name];
}

void main() {
  test('an empty database has no homes', () async {
    final repository = _createRepository();

    final homes = await repository.watchHomes().first;

    expect(homes, isEmpty);
  });

  test('a created home has the given name and a UUID v4', () async {
    final repository = _createRepository();

    final home = await repository.createHome('Berlin');

    expect(home.name, 'Berlin');
    expect(home.id, matches(_uuidV4));
  });

  test('a created home is listed', () async {
    final repository = _createRepository();

    final home = await repository.createHome('Berlin');

    expect(await repository.watchHomes().first, [home]);
  });

  test('two homes with the same name get different ids', () async {
    final repository = _createRepository();

    final first = await repository.createHome('Berlin');
    final second = await repository.createHome('Berlin');

    expect(first.id, isNot(second.id));
    expect(await _homeNames(repository), ['Berlin', 'Berlin']);
  });

  test('a name with umlauts is stored unchanged', () async {
    final repository = _createRepository();

    await repository.createHome('Ferienwohnung Ötztal');

    expect(await _homeNames(repository), ['Ferienwohnung Ötztal']);
  });

  test('a home created later appears in a running listing', () async {
    final repository = _createRepository();
    final listings = <List<Home>>[];
    final subscription = repository.watchHomes().listen(listings.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    final home = await repository.createHome('Berlin');
    await pumpEventQueue();

    expect(listings, [
      <Home>[],
      [home],
    ]);
  });

  const sortingCases = {
    'lower case sorts before a later upper case letter': (
      created: ['Hamburg', 'berlin'],
      listed: ['berlin', 'Hamburg'],
    ),
    'upper case sorts before a later lower case letter': (
      created: ['hamburg', 'Berlin'],
      listed: ['Berlin', 'hamburg'],
    ),
    'creation order does not matter': (
      created: ['Köln', 'Aachen', 'München'],
      listed: ['Aachen', 'Köln', 'München'],
    ),
  };

  for (final MapEntry(key: description, value: (:created, :listed))
      in sortingCases.entries) {
    test('homes are sorted by name ignoring case: $description', () async {
      final repository = _createRepository();
      for (final name in created) {
        await repository.createHome(name);
      }

      expect(await _homeNames(repository), listed);
    });
  }

  test('a home is still listed after reopening the database file', () async {
    final directory = await Directory.systemTemp.createTemp('fridgo_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fridgo.sqlite');
    final firstSession = AppDatabase(NativeDatabase(file));
    final home = await HomeRepository(firstSession).createHome('Berlin');
    await firstSession.close();

    final secondSession = AppDatabase(NativeDatabase(file));
    addTearDown(secondSession.close);
    final homes = await HomeRepository(secondSession).watchHomes().first;

    expect(homes, [home]);
  });

  test(
    'getting homes once returns them sorted by name ignoring case',
    () async {
      final repository = _createRepository();
      await repository.createHome('hamburg');
      await repository.createHome('Berlin');

      final homes = await repository.getHomes();

      expect([for (final home in homes) home.name], ['Berlin', 'hamburg']);
    },
  );

  group('changing homes', _changingHomes);
}

void _changingHomes() {
  late AppDatabase database;
  late HomeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    repository = HomeRepository(database);
  });

  Future<String> createFridge(Home home) async {
    final storageLocation = await StorageLocationRepository(database)
        .createStorageLocation(
          homeId: home.id,
          name: 'Kühlschrank',
          kind: StorageLocationKind.refrigerator,
        );
    return storageLocation.id;
  }

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

  test('a renamed home is listed with its new name', () async {
    final home = await repository.createHome('Berlin');

    await repository.updateHome(home.copyWith(name: 'Hamburg'));

    expect(await repository.getHomes(), [home.copyWith(name: 'Hamburg')]);
  });

  test('renaming an unknown home throws', () async {
    await expectLater(
      repository.updateHome(const Home(id: 'unknown', name: 'Hamburg')),
      throwsStateError,
    );
  });

  test('a home without storage locations has no stock items', () async {
    final home = await repository.createHome('Berlin');

    expect(await repository.countStockItems(home.id), 0);
  });

  test('stock items of all storage locations of a home are counted', () async {
    final home = await repository.createHome('Berlin');
    final fridge = await createFridge(home);
    final pantry = await createFridge(home);
    await addStockItem(fridge, 'Milch');
    await addStockItem(fridge, 'Butter');
    await addStockItem(pantry, 'Reis');
    final otherHome = await repository.createHome('Hamburg');
    await addStockItem(await createFridge(otherHome), 'Käse');

    expect(await repository.countStockItems(home.id), 3);
  });

  test(
    'deleting a home deletes its storage locations and stock items',
    () async {
      final home = await repository.createHome('Berlin');
      await addStockItem(await createFridge(home), 'Milch');
      await addStockItem(await createFridge(home), 'Reis');

      await repository.deleteHome(home.id);

      expect(await repository.getHomes(), isEmpty);
      expect(await database.select(database.storageLocations).get(), isEmpty);
      expect(await stockItemIds(), isEmpty);
    },
  );

  test('deleting a home keeps the products', () async {
    final home = await repository.createHome('Berlin');
    final milk = await addStockItem(await createFridge(home), 'Milch');

    await repository.deleteHome(home.id);

    final products = await ProductRepository(database).getProducts();
    expect([for (final product in products) product.id], [milk.productId]);
  });

  test('deleting a home leaves other homes untouched', () async {
    final home = await repository.createHome('Berlin');
    await addStockItem(await createFridge(home), 'Milch');
    final otherHome = await repository.createHome('Hamburg');
    final otherFridge = await createFridge(otherHome);
    final cheese = await addStockItem(otherFridge, 'Käse');

    await repository.deleteHome(home.id);

    expect(await repository.getHomes(), [otherHome]);
    expect(await stockItemIds(), [cheese.id]);
    expect(
      [
        for (final row
            in await database.select(database.storageLocations).get())
          row.id,
      ],
      [otherFridge],
    );
  });

  test('a home without storage locations can be deleted', () async {
    final home = await repository.createHome('Berlin');

    await repository.deleteHome(home.id);

    expect(await repository.getHomes(), isEmpty);
  });

  test('a failed delete keeps the home with all its stock items', () async {
    final home = await repository.createHome('Berlin');
    final milk = await addStockItem(await createFridge(home), 'Milch');
    await database.customStatement(
      'CREATE TRIGGER fail_home_delete BEFORE DELETE ON homes '
      "BEGIN SELECT RAISE(ABORT, 'home delete failed'); END",
    );

    await expectLater(
      repository.deleteHome(home.id),
      throwsA(isA<SqliteException>()),
    );

    expect(await repository.getHomes(), [home]);
    expect(
      await database.select(database.storageLocations).get(),
      hasLength(1),
    );
    expect(await stockItemIds(), [milk.id]);
  });
}
