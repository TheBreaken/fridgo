import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/storage_location_repository.dart';
import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';

ProviderContainer _createContainer() {
  final database = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return container;
}

Future<String> _createHome(ProviderContainer container, String name) async {
  final home = await container.read(homeRepositoryProvider).createHome(name);
  return home.id;
}

Future<List<String>> _storedNames(
  ProviderContainer container,
  String homeId,
) async {
  final storageLocations = await container
      .read(storageLocationRepositoryProvider)
      .watchStorageLocations(homeId)
      .first;
  return [for (final storageLocation in storageLocations) storageLocation.name];
}

void main() {
  const nameCases = {
    'an empty name is invalid': (name: '', isValid: false),
    'a name of spaces is invalid': (name: '   ', isValid: false),
    'a name of tabs and line breaks is invalid': (name: '\t\n', isValid: false),
    'a single character is valid': (name: 'K', isValid: true),
    'a name with umlauts is valid': (name: 'Kühlschrank', isValid: true),
    'a name with surrounding spaces is valid': (
      name: '  Vorrat  ',
      isValid: true,
    ),
  };

  for (final MapEntry(key: description, value: (:name, :isValid))
      in nameCases.entries) {
    test('name validation: $description', () async {
      final container = _createContainer();
      final homeId = await _createHome(container, 'Berlin');

      final result = container
          .read(storageLocationsViewModelProvider(homeId).notifier)
          .isValidName(name);

      expect(result, isValid);
    });
  }

  test('creating stores the name without surrounding spaces', () async {
    final container = _createContainer();
    final homeId = await _createHome(container, 'Berlin');

    await container
        .read(storageLocationsViewModelProvider(homeId).notifier)
        .createStorageLocation('  Vorrat  ', StorageLocationKind.pantry);

    expect(await _storedNames(container, homeId), ['Vorrat']);
  });

  const blankNames = {
    'an empty name is rejected': '',
    'a name of spaces is rejected': '   ',
  };

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    test('creating: $description and nothing is stored', () async {
      final container = _createContainer();
      final homeId = await _createHome(container, 'Berlin');

      await expectLater(
        container
            .read(storageLocationsViewModelProvider(homeId).notifier)
            .createStorageLocation(name, StorageLocationKind.refrigerator),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            name,
          ),
        ),
      );

      expect(await _storedNames(container, homeId), isEmpty);
    });
  }

  test('the state lists only the storage locations of its home', () async {
    final container = _createContainer();
    final berlinId = await _createHome(container, 'Berlin');
    final hamburgId = await _createHome(container, 'Hamburg');
    final subscription = container.listen(
      storageLocationsViewModelProvider(berlinId),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(storageLocationsViewModelProvider(berlinId).future);

    await container
        .read(storageLocationsViewModelProvider(berlinId).notifier)
        .createStorageLocation('Keller', StorageLocationKind.cellar);
    await container
        .read(storageLocationsViewModelProvider(hamburgId).notifier)
        .createStorageLocation('Vorrat', StorageLocationKind.pantry);
    await pumpEventQueue();

    final storageLocations = container
        .read(storageLocationsViewModelProvider(berlinId))
        .requireValue;
    expect(
      [
        for (final storageLocation in storageLocations)
          (storageLocation.name, storageLocation.kind),
      ],
      [('Keller', StorageLocationKind.cellar)],
    );
  });

  test(
    'updating stores the kind and the name without surrounding spaces',
    () async {
      final container = _createContainer();
      final homeId = await _createHome(container, 'Berlin');
      final viewModel = container.read(
        storageLocationsViewModelProvider(homeId).notifier,
      );
      final fridge = await container
          .read(storageLocationRepositoryProvider)
          .createStorageLocation(
            homeId: homeId,
            name: 'Kühlschrank',
            kind: StorageLocationKind.refrigerator,
          );

      await viewModel.updateStorageLocation(
        fridge,
        '  Truhe  ',
        StorageLocationKind.freezer,
      );

      final stored = await container
          .read(storageLocationRepositoryProvider)
          .watchStorageLocations(homeId)
          .first;
      expect(stored, [
        fridge.copyWith(name: 'Truhe', kind: StorageLocationKind.freezer),
      ]);
    },
  );

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    test('updating: $description and the old name stays', () async {
      final container = _createContainer();
      final homeId = await _createHome(container, 'Berlin');
      final fridge = await container
          .read(storageLocationRepositoryProvider)
          .createStorageLocation(
            homeId: homeId,
            name: 'Kühlschrank',
            kind: StorageLocationKind.refrigerator,
          );

      await expectLater(
        container
            .read(storageLocationsViewModelProvider(homeId).notifier)
            .updateStorageLocation(fridge, name, StorageLocationKind.freezer),
        throwsA(isA<ArgumentError>()),
      );

      expect(await _storedNames(container, homeId), ['Kühlschrank']);
    });
  }
}
