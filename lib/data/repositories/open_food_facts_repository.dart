import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/domain/product_lookup.dart';
import 'package:http/http.dart' as http;

class OpenFoodFactsRepository {
  new(this._client, {this._timeout = const Duration(seconds: 10)});

  final http.Client _client;
  final Duration _timeout;

  // Open Food Facts asks every app to name itself and a contact.
  static const _userAgent = 'Fridgo/1.0 (https://github.com/TheBreaken/fridgo)';
  static const _host = 'world.openfoodfacts.org';

  // In order of preference: German, the language on the pack, English.
  static const _nameFields = [
    'product_name_de',
    'product_name',
    'product_name_en',
  ];

  static const Map<Nutrient, String> _nutrientFields = {
    Nutrient.energy: 'energy-kcal_100g',
    Nutrient.fat: 'fat_100g',
    Nutrient.saturatedFat: 'saturated-fat_100g',
    Nutrient.carbohydrates: 'carbohydrates_100g',
    Nutrient.sugars: 'sugars_100g',
    Nutrient.protein: 'proteins_100g',
    Nutrient.salt: 'salt_100g',
  };
  static const _energyInKilojoulesField = 'energy-kj_100g';

  /// Throws a [ProductLookupException] if there is no answer or no product.
  Future<ProductFacts> fetchProduct(String barcode) async {
    final response = await _get(barcode);
    if (response.statusCode == HttpStatus.notFound) {
      throw ProductNotFoundException(barcode);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw ProductLookupFailedException(
        barcode,
        'HTTP ${response.statusCode}',
      );
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw ProductLookupFailedException(barcode, 'invalid JSON: $error');
    }
    if (body case {'product': final Map<String, Object?> product}) {
      return ProductFacts(
        name: _name(product),
        nutritionFacts: _nutritionFacts(product['nutriments']),
      );
    }
    throw ProductLookupFailedException(barcode, 'no product in the response');
  }

  Future<http.Response> _get(String barcode) async {
    final uri = Uri.https(_host, '/api/v3/product/$barcode', {
      'fields': [..._nameFields, 'nutriments'].join(','),
    });
    try {
      return await _client
          .get(uri, headers: {HttpHeaders.userAgentHeader: _userAgent})
          .timeout(_timeout);
    } on Exception catch (error) {
      // No network, a timeout, a failed TLS handshake: all mean no answer.
      throw ProductLookupFailedException(barcode, '$error');
    }
  }

  String? _name(Map<String, Object?> product) => _nameFields
      .map((field) => product[field])
      .whereType<String>()
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .firstOrNull;

  Map<Nutrient, double> _nutritionFacts(Object? nutriments) {
    if (nutriments is! Map<String, Object?>) return const {};
    double? read(String field) => switch (nutriments[field]) {
      final num value => value.toDouble(),
      _ => null,
    };
    final values = {
      for (final MapEntry(key: nutrient, value: field)
          in _nutrientFields.entries)
        nutrient: ?read(field),
    };
    if (read(_energyInKilojoulesField) case final kilojoules?
        when !values.containsKey(Nutrient.energy)) {
      values[Nutrient.energy] = kilojoules / kilojoulesPerKilocalorie;
    }
    return {
      for (final MapEntry(key: nutrient, :value) in values.entries)
        if (_roundToInputPrecision(value) case final rounded
            when nutrient.isValidValue(rounded))
          nutrient: rounded,
    };
  }

  // The form takes at most three decimals.
  double _roundToInputPrecision(double value) => (value * 1000).round() / 1000;
}

final openFoodFactsRepositoryProvider = Provider<OpenFoodFactsRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return OpenFoodFactsRepository(client);
});
