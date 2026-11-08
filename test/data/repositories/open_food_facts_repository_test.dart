import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  const imageBase =
      'https://images.openfoodfacts.org/images/products/400/840/040/1621';
  const imageCases = <String, (Map<String, Object?>, String?)>{
    'the German front comes first, in full size': (
      {
        'selected_images': {
          'front': {
            'display': {
              'en': '$imageBase/front_en.302.400.jpg',
              'de': '$imageBase/front_de.239.400.jpg',
            },
          },
        },
        'image_front_url': '$imageBase/front_it.12.400.jpg',
      },
      '$imageBase/front_de.239.full.jpg',
    ),
    'without German the front on the pack': (
      {
        'selected_images': {
          'front': {
            'display': {'en': '$imageBase/front_en.302.400.jpg'},
          },
        },
        'image_front_url': '$imageBase/front_it.12.400.jpg',
      },
      '$imageBase/front_it.12.full.jpg',
    ),
    'English comes last': (
      {
        'selected_images': {
          'front': {
            'display': {'en': '$imageBase/front_en.302.400.jpg'},
          },
        },
      },
      '$imageBase/front_en.302.full.jpg',
    ),
    'an image of another size is taken as it is': (
      {'image_front_url': '$imageBase/front_de.239.200.jpg'},
      '$imageBase/front_de.239.200.jpg',
    ),
    'an address without https is ignored': (
      {'image_front_url': 'http://example.org/front.400.jpg'},
      null,
    ),
    'an address that is not text is ignored': ({'image_front_url': 42}, null),
    'no image at all': ({}, null),
  };
  for (final MapEntry(key: description, value: (product, url))
      in imageCases.entries) {
    test('image: $description', () async {
      final facts = await _repositoryFinding({
        'product_name': 'Nutella',
        ...product,
      }).fetchProduct(_barcode);

      expect(facts.imageUrl?.toString(), url);
    });
  }

  test('asks for the image fields', () async {
    late http.Request sent;
    final repository = _repositoryAnswering((request) async {
      sent = request;
      return http.Response('{"product": {}}', HttpStatus.ok);
    });

    await repository.fetchProduct(_barcode);

    expect(
      sent.url.queryParameters['fields']?.split(','),
      containsAll(['selected_images', 'image_front_url']),
    );
  });

  final imageUrl = Uri.parse('$imageBase/front_de.239.full.jpg');

  test('downloads the image with its own user agent', () async {
    late http.Request sent;
    final repository = _repositoryAnswering((request) async {
      sent = request;
      return http.Response.bytes([1, 2, 3], HttpStatus.ok);
    });

    final image = await repository.fetchImage(imageUrl);

    expect(image, Uint8List.fromList([1, 2, 3]));
    expect(sent.url, imageUrl);
    expect(
      sent.headers[HttpHeaders.userAgentHeader],
      'Fridgo/1.0 (https://github.com/TheBreaken/fridgo)',
    );
  });

  final imageFailures = <String, OpenFoodFactsRepository>{
    'no network': _repositoryAnswering(
      (_) => throw const SocketException('Failed host lookup'),
    ),
    'a timeout': _repositoryAnswering(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 1),
    ),
    'a missing image': _repositoryAnswering(
      (_) async => http.Response('', HttpStatus.notFound),
    ),
    'a server error': _repositoryAnswering(
      (_) async => http.Response('', HttpStatus.internalServerError),
    ),
  };
  for (final MapEntry(key: description, value: repository)
      in imageFailures.entries) {
    test('image download: $description throws', () async {
      await expectLater(
        repository.fetchImage(imageUrl),
        throwsA(
          isA<ProductImageDownloadException>().having(
            (error) => error.url,
            'url',
            imageUrl,
          ),
        ),
      );
    });
  }
}
