import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/database/app_database.dart';
import 'package:fridgo/data/repositories/home_repository.dart';
import 'package:fridgo/ui/homes/homes_view_model.dart';

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

Future<List<String>> _storedHomeNames(ProviderContainer container) async {
  final homes = await container.read(homeRepositoryProvider).watchHomes().first;
  return [for (final home in homes) home.name];
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
}
