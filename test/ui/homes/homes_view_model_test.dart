import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/data/repositories/last_home_repository.dart';
import 'package:fridgo/ui/homes/homes_view_model.dart';

import '../../data/repositories/fake_last_home_repository.dart';

ProviderContainer _createContainer({FakeLastHomeRepository? lastHomes}) {
  final database = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      lastHomeRepositoryProvider.overrideWithValue(
        lastHomes ?? FakeLastHomeRepository(),
      ),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return container;
}

Future<List<String>> _storedHomeNames(ProviderContainer container) async {
  final homes = await container.read(homeRepositoryProvider).watchHomes().first;
  return [for (final home in homes) home.name];
}

Future<String> _homeIdNamed(ProviderContainer container, String name) async {
  final homes = await container.read(homeRepositoryProvider).watchHomes().first;
  return homes.firstWhere((home) => home.name == name).id;
}

void main() {
  const nameCases = {
    'an empty name is invalid': (name: '', isValid: false),
    'a name of spaces is invalid': (name: '   ', isValid: false),
    'a name of tabs and line breaks is invalid': (name: '\t\n', isValid: false),
    'a single character is valid': (name: 'B', isValid: true),
    'a name with umlauts is valid': (name: 'Ötztal', isValid: true),
    'a name with surrounding spaces is valid': (
      name: '  Berlin  ',
      isValid: true,
    ),
  };

  for (final MapEntry(key: description, value: (:name, :isValid))
      in nameCases.entries) {
    test('name validation: $description', () {
      final container = _createContainer();

      final result = container
          .read(homesViewModelProvider.notifier)
          .isValidName(name);

      expect(result, isValid);
    });
  }

  test('creating a home stores the name without surrounding spaces', () async {
    final container = _createContainer();

    await container
        .read(homesViewModelProvider.notifier)
        .createHome('  Berlin  ');

    expect(await _storedHomeNames(container), ['Berlin']);
  });

  const blankNames = {
    'an empty name is rejected': '',
    'a name of spaces is rejected': '   ',
  };

  for (final MapEntry(key: description, value: name) in blankNames.entries) {
    test('creating a home: $description and nothing is stored', () async {
      final container = _createContainer();

      await expectLater(
        container.read(homesViewModelProvider.notifier).createHome(name),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            name,
          ),
        ),
      );

      expect(await _storedHomeNames(container), isEmpty);
    });
  }

  test('the state is empty without homes', () async {
    final container = _createContainer();
    final subscription = container.listen(homesViewModelProvider, (_, _) {});
    addTearDown(subscription.close);

    final homes = await container.read(homesViewModelProvider.future);

    expect(homes, isEmpty);
  });

  test('the state lists a created home', () async {
    final container = _createContainer();
    final subscription = container.listen(homesViewModelProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(homesViewModelProvider.future);

    await container.read(homesViewModelProvider.notifier).createHome('Berlin');
    await pumpEventQueue();

    final homes = container.read(homesViewModelProvider).requireValue;
    expect([for (final home in homes) home.name], ['Berlin']);
  });

  test('selecting a home remembers it', () async {
    final lastHomes = FakeLastHomeRepository();
    final container = _createContainer(lastHomes: lastHomes);

    await container.read(homesViewModelProvider.notifier).selectHome('home-1');

    expect(lastHomes.lastHomeId, 'home-1');
  });

  test('without homes there is no start home', () async {
    final container = _createContainer(
      lastHomes: FakeLastHomeRepository(lastHomeId: 'deleted'),
    );

    final startHomeId = await container
        .read(homesViewModelProvider.notifier)
        .findStartHomeId();

    expect(startHomeId, isNull);
  });

  test('the start home is the last selected home', () async {
    final lastHomes = FakeLastHomeRepository();
    final container = _createContainer(lastHomes: lastHomes);
    final viewModel = container.read(homesViewModelProvider.notifier);
    await viewModel.createHome('Berlin');
    await viewModel.createHome('Hamburg');
    final hamburg = await _homeIdNamed(container, 'Hamburg');
    await viewModel.selectHome(hamburg);

    final startHomeId = await viewModel.findStartHomeId();

    expect(startHomeId, hamburg);
  });

  const fallbackCases = {
    'nothing remembered starts in the alphabetically first home': null,
    'a remembered home that is gone starts in the alphabetically first home':
        'deleted',
  };

  for (final MapEntry(key: description, value: lastHomeId)
      in fallbackCases.entries) {
    test(description, () async {
      final container = _createContainer(
        lastHomes: FakeLastHomeRepository(lastHomeId: lastHomeId),
      );
      final viewModel = container.read(homesViewModelProvider.notifier);
      await viewModel.createHome('Hamburg');
      await viewModel.createHome('Berlin');

      final startHomeId = await viewModel.findStartHomeId();

      expect(startHomeId, await _homeIdNamed(container, 'Berlin'));
    });
  }

  test('renaming stores the name without surrounding spaces', () async {
    final container = _createContainer();
    final viewModel = container.read(homesViewModelProvider.notifier);
    await viewModel.createHome('Berlin');
    final berlin =
        (await container.read(homeRepositoryProvider).getHomes()).single;

    await viewModel.renameHome(berlin, '  Hamburg  ');

    expect(await _storedHomeNames(container), ['Hamburg']);
  });

  const blankRenames = {
    'an empty name is rejected': '',
    'a name of spaces is rejected': '   ',
  };

  for (final MapEntry(key: description, value: name) in blankRenames.entries) {
    test('renaming: $description and the old name stays', () async {
      final container = _createContainer();
      final viewModel = container.read(homesViewModelProvider.notifier);
      await viewModel.createHome('Berlin');
      final berlin =
          (await container.read(homeRepositoryProvider).getHomes()).single;

      await expectLater(
        viewModel.renameHome(berlin, name),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            name,
          ),
        ),
      );

      expect(await _storedHomeNames(container), ['Berlin']);
    });
  }

  test(
    'after deleting the selected home another home is the start home',
    () async {
      final lastHomes = FakeLastHomeRepository();
      final container = _createContainer(lastHomes: lastHomes);
      final viewModel = container.read(homesViewModelProvider.notifier);
      await viewModel.createHome('Berlin');
      await viewModel.createHome('Hamburg');
      final berlin = await _homeIdNamed(container, 'Berlin');
      await viewModel.selectHome(berlin);

      await viewModel.deleteHome(berlin);

      expect(
        await viewModel.findStartHomeId(),
        await _homeIdNamed(container, 'Hamburg'),
      );
    },
  );

  test('after deleting the only home there is no start home', () async {
    final container = _createContainer();
    final viewModel = container.read(homesViewModelProvider.notifier);
    await viewModel.createHome('Berlin');
    final berlin = await _homeIdNamed(container, 'Berlin');
    await viewModel.selectHome(berlin);

    await viewModel.deleteHome(berlin);

    expect(await viewModel.findStartHomeId(), isNull);
  });
}
