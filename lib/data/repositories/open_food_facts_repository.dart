import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  static const _selectedImagesField = 'selected_images';
  static const _frontImageField = 'image_front_url';

  // The API names a 400 px image; the same name with "full" is the upload.
  static final _displaySize = RegExp(r'\.400\.jpg$');

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
        imageUrl: _imageUrl(product),
      );
    }
    throw ProductLookupFailedException(barcode, 'no product in the response');
  }

  /// Throws a [ProductImageDownloadException] if the image does not arrive.
  Future<Uint8List> fetchImage(Uri url) async {
    final http.Response response;
    try {
      response = await _send(url);
    } on Exception catch (error) {
      throw ProductImageDownloadException(url, '$error');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw ProductImageDownloadException(url, 'HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<http.Response> _get(String barcode) async {
    final uri = Uri.https(_host, '/api/v3/product/$barcode', {
      'fields': [
        ..._nameFields,
        'nutriments',
        _selectedImagesField,
        _frontImageField,
      ].join(','),
    });
    try {
      return await _send(uri);
    } on Exception catch (error) {
      // No network, a timeout, a failed TLS handshake: all mean no answer.
      throw ProductLookupFailedException(barcode, '$error');
    }
  }

  Future<http.Response> _send(Uri uri) => _client
      .get(uri, headers: {HttpHeaders.userAgentHeader: _userAgent})
      .timeout(_timeout);

  // The front of the pack, in the order of the names.
  Uri? _imageUrl(Map<String, Object?> product) {
    final frontImages = switch (product[_selectedImagesField]) {
      {'front': {'display': final Map<String, Object?> byLanguage}} =>
        byLanguage,
      _ => const <String, Object?>{},
    };
    return [frontImages['de'], product[_frontImageField], frontImages['en']]
        .whereType<String>()
        .map((url) => Uri.tryParse(url.replaceFirst(_displaySize, '.full.jpg')))
        .nonNulls
        .where((url) => url.isScheme('https'))
        .firstOrNull;
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
