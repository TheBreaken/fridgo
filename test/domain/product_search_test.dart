import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/product.dart';
import 'package:fridgo/domain/product_search.dart';

List<Product> _products(List<String> names) => [
  for (final (index, name) in names.indexed)
    Product(id: 'product-$index', name: name),
];

List<String> _foundNames(List<String> names, String query) => [
  for (final product in searchProducts(_products(names), query)) product.name,
];

void main() {
  const matches = {
    'lower case finds upper case': ('Milch', 'milch'),
    'upper case finds lower case': ('milch', 'MILCH'),
    'a part of the name is found': ('Hafermilch', 'milch'),
    'a part across words is found': ('Frische Vollmilch', 'he voll'),
    'a lower umlaut finds an upper umlaut': ('Äpfel', 'äpfel'),
    'an upper umlaut finds a lower umlaut': ('Hähnchen', 'HÄHN'),
    'a plain vowel finds an umlaut': ('Äpfel', 'apfel'),
    'an umlaut finds a plain vowel': ('Apfelmus', 'äpfel'),
    'ae finds ä': ('Äpfel', 'aepfel'),
    'oe finds ö': ('Brötchen', 'broetchen'),
    'ue finds ü': ('Würstchen', 'wuerstchen'),
    'ü finds ue': ('Mueslix', 'müsli'),
    'ss finds ß': ('Weißwurst', 'weisswurst'),
    'ß finds ss': ('Weisswurst', 'weißwurst'),
    'capital ẞ finds ß': ('Weißwurst', 'WEIẞ'),
    'surrounding spaces are ignored': ('Milch', '  milch  '),
    'a single letter is found': ('Milch', 'm'),
  };

  for (final MapEntry(key: description, value: (name, query))
      in matches.entries) {
    test('search: $description', () {
      expect(_foundNames([name], query), [name]);
    });
  }

  const misses = {
    'another name is not found': ('Butter', 'milch'),
    'a query longer than the name is not found': ('Milch', 'milchreis'),
    'an empty query finds nothing': ('Milch', ''),
    'a query of spaces finds nothing': ('Milch', '   '),
    'a different umlaut is not found': ('Äpfel', 'öpfel'),
  };

  for (final MapEntry(key: description, value: (name, query))
      in misses.entries) {
    test('search: $description', () {
      expect(_foundNames([name], query), isEmpty);
    });
  }

  const orders = {
    'names starting with the query come before others': (
      names: ['Hafermilch', 'Milchreis', 'Kokosmilch', 'Milch'],
      query: 'milch',
      found: ['Milch', 'Milchreis', 'Hafermilch', 'Kokosmilch'],
    ),
    'names are sorted ignoring case and umlauts': (
      names: ['zucchini', 'Äpfel', 'apfelmus', 'Bananen'],
      query: 'n',
      found: ['Bananen', 'zucchini'],
    ),
    'umlauts sort like their plain vowel': (
      names: ['Apfelsaft', 'Äpfel', 'Apfelmus'],
      query: 'apfel',
      found: ['Äpfel', 'Apfelmus', 'Apfelsaft'],
    ),
  };

  for (final MapEntry(key: description, value: (:names, :query, :found))
      in orders.entries) {
    test('search order: $description', () {
      expect(_foundNames(names, query), found);
    });
  }

  test('two products with the same name are both found', () {
    final products = _products(['Milch', 'Milch']);

    final found = searchProducts(products, 'milch');

    expect(found, products);
  });

  test('no products give no matches', () {
    expect(searchProducts([], 'milch'), isEmpty);
  });
}
