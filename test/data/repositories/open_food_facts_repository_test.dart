import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/repositories/open_food_facts_repository.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product_lookup.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _barcode = '4008400401621';

OpenFoodFactsRepository _repositoryAnswering(
  Future<http.Response> Function(http.Request request) answer, {
  Duration timeout = const Duration(seconds: 10),
}) => OpenFoodFactsRepository(MockClient(answer), timeout: timeout);

OpenFoodFactsRepository _repositoryFinding(Map<String, Object?> product) =>
    _repositoryAnswering(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'code': _barcode, 'product': product})),
        HttpStatus.ok,
      ),
    );

void main() {
  test('asks for the barcode with its own user agent', () async {
    late http.Request sent;
    final repository = _repositoryAnswering((request) async {
      sent = request;
      return http.Response('{"product": {}}', HttpStatus.ok);
    });

    await repository.fetchProduct(_barcode);

    expect(sent.url.host, 'world.openfoodfacts.org');
    expect(sent.url.path, '/api/v3/product/$_barcode');
    expect(
      sent.headers[HttpHeaders.userAgentHeader],
      'Fridgo/1.0 (https://github.com/TheBreaken/fridgo)',
    );
  });

  test('translates name and nutrition facts', () async {
    final repository = _repositoryFinding({
      'product_name_de': 'Schoko-Riegel',
      'nutriments': {
        'energy-kcal_100g': 539,
        'energy-kj_100g': 2227.9,
        'fat_100g': 30.9,
        'saturated-fat_100g': 10.6,
        'carbohydrates_100g': 57.5,
        'sugars_100g': 56.3,
        'proteins_100g': 6.3,
        'salt_100g': 0.107,
        'caffeine_100g': 0,
      },
    });

    final facts = await repository.fetchProduct(_barcode);

    expect(
      facts,
      const ProductFacts(
        name: 'Schoko-Riegel',
        nutritionFacts: {
          Nutrient.energy: 539,
          Nutrient.fat: 30.9,
          Nutrient.saturatedFat: 10.6,
          Nutrient.carbohydrates: 57.5,
          Nutrient.sugars: 56.3,
          Nutrient.protein: 6.3,
          Nutrient.salt: 0.107,
        },
      ),
    );
  });

  const nameCases = <String, (Map<String, Object?>, String?)>{
    'German comes first': (
      {
        'product_name_de': 'Milch',
        'product_name': 'Latte',
        'product_name_en': 'Milk',
      },
      'Milch',
    ),
    'without German the name on the pack': (
      {'product_name': 'Latte', 'product_name_en': 'Milk'},
      'Latte',
    ),
    'a blank German name counts as missing': (
      {'product_name_de': '  ', 'product_name': 'Latte'},
      'Latte',
    ),
    'English comes last': ({'product_name_en': 'Milk'}, 'Milk'),
    'the name is trimmed': ({'product_name_de': ' Milch \n'}, 'Milch'),
    'no name at all': ({'product_name': ''}, null),
    'a name that is not text': ({'product_name_de': 42}, null),
  };
  for (final MapEntry(key: description, value: (product, name))
      in nameCases.entries) {
    test('name: $description', () async {
      final facts = await _repositoryFinding(product).fetchProduct(_barcode);

      expect(facts.name, name);
    });
  }

  const nutritionCases =
      <String, (Map<String, Object?>, Map<Nutrient, double>)>{
        'energy only in kJ is converted to kcal': (
          {'energy-kj_100g': 418.4},
          {Nutrient.energy: 100},
        ),
        'kcal wins over kJ': (
          {'energy-kcal_100g': 50, 'energy-kj_100g': 418.4},
          {Nutrient.energy: 50},
        ),
        'values are rounded to three decimals': (
          {'salt_100g': 0.12345},
          {Nutrient.salt: 0.123},
        ),
        'values out of range are dropped one by one': (
          {'sugars_100g': 120, 'fat_100g': -1, 'proteins_100g': 3},
          {Nutrient.protein: 3},
        ),
        'values that are not numbers are dropped': (
          {'fat_100g': '3.5', 'salt_100g': null},
          {},
        ),
      };
  for (final MapEntry(key: description, value: (nutriments, expected))
      in nutritionCases.entries) {
    test('nutrition facts: $description', () async {
      final facts = await _repositoryFinding({
        'product_name': 'Milch',
        'nutriments': nutriments,
      }).fetchProduct(_barcode);

      expect(facts.nutritionFacts, expected);
    });
  }

  test('a product without nutriments has no nutrition facts', () async {
    final facts = await _repositoryFinding({'product_name': 'Milch'})
        .fetchProduct(_barcode);

    expect(facts.nutritionFacts, isEmpty);
  });

  test('an unknown barcode throws ProductNotFoundException', () async {
    final repository = _repositoryAnswering(
      (_) async => http.Response(
        '{"status": "failure", "result": {"id": "product_not_found"}}',
        HttpStatus.notFound,
      ),
    );

    await expectLater(
      repository.fetchProduct(_barcode),
      throwsA(
        isA<ProductNotFoundException>().having(
          (error) => error.barcode,
          'barcode',
          _barcode,
        ),
      ),
    );
  });

  final failures = <String, OpenFoodFactsRepository>{
    'no network': _repositoryAnswering(
      (_) => throw const SocketException('Failed host lookup'),
    ),
    'a timeout': _repositoryAnswering(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 1),
    ),
    'a server error': _repositoryAnswering(
      (_) async => http.Response('', HttpStatus.serviceUnavailable),
    ),
    'broken JSON': _repositoryAnswering(
      (_) async => http.Response('<html>', HttpStatus.ok),
    ),
    'a response without product': _repositoryAnswering(
      (_) async => http.Response('{"status": "success"}', HttpStatus.ok),
    ),
  };
  for (final MapEntry(key: description, value: repository)
      in failures.entries) {
    test('$description throws ProductLookupFailedException', () async {
      await expectLater(
        repository.fetchProduct(_barcode),
        throwsA(isA<ProductLookupFailedException>()),
      );
    });
  }
}
