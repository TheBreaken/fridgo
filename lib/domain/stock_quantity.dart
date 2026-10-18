import 'dart:math';

final _quantityInputPattern = RegExp(r'^(\d+|\d*[.,]\d{1,3})$');

/// Whether [input] is a quantity above 0 with at most three decimals, written
/// with a decimal comma or point.
bool isValidQuantityInput(String input) =>
    _quantityInputPattern.hasMatch(input.trim()) && _toDouble(input) > 0;

double parseQuantityInput(String input) {
  if (!isValidQuantityInput(input)) {
    throw ArgumentError.value(
      input,
      'input',
      'must be above 0 with at most three decimals',
    );
  }
  return _toDouble(input);
}

/// The quantity left after consuming [consumed]; 0 means used up.
double quantityAfterConsuming(double quantity, double consumed) {
  if (consumed <= 0) {
    throw ArgumentError.value(consumed, 'consumed', 'must be above 0');
  }
  // Quantities have at most three decimals; rounding drops the binary
  // floating point rest, such as 0.30000000000000004.
  final remaining = ((quantity - consumed) * 1000).round() / 1000;
  return max<double>(0, remaining);
}

double _toDouble(String input) =>
    double.parse(input.trim().replaceFirst(',', '.'));
