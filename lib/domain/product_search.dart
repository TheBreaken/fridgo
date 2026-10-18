import 'package:fridgo/domain/product.dart';

/// Products whose name contains [query], ignoring case and the spelling of
/// German umlauts, so "apfel" and "aepfel" both find "Äpfel".
///
/// Names that start with the query come first, then all others by name.
List<Product> searchProducts(Iterable<Product> products, String query) {
  final normalizedQuery = _normalize(query.trim());
  if (normalizedQuery.isEmpty) return [];
  final matches = [
    for (final product in products)
      (product: product, name: _normalize(product.name)),
  ].where((match) => match.name.contains(normalizedQuery)).toList();
  int rank(String name) => name.startsWith(normalizedQuery) ? 0 : 1;
  matches.sort((a, b) {
    final byRank = rank(a.name).compareTo(rank(b.name));
    if (byRank != 0) return byRank;
    final byName = a.name.compareTo(b.name);
    if (byName != 0) return byName;
    return a.product.id.compareTo(b.product.id);
  });
  return [for (final match in matches) match.product];
}

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss')
    .replaceAll('ae', 'a')
    .replaceAll('oe', 'o')
    .replaceAll('ue', 'u');
