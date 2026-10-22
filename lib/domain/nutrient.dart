import 'package:fridgo/domain/stock_quantity.dart';

/// The nutrients an EU food label lists, per 100 g or 100 ml.
enum Nutrient {
  // In kcal; pure fat has about 900 kcal per 100 g, the most any food has.
  energy(maximum: 900),
  fat(maximum: 100),
  saturatedFat(maximum: 100),
  carbohydrates(maximum: 100),
  sugars(maximum: 100),
  protein(maximum: 100),
  salt(maximum: 100);

  new({required this.maximum});

  final double maximum;

  bool isValidValue(double value) => value >= 0 && value <= maximum;
}

/// Whether [input] is empty or a value from 0 to the nutrient's maximum with
/// at most three decimals, written with a decimal comma or point.
bool isValidNutrientInput(String input, Nutrient nutrient) {
  if (input.trim().isEmpty) return true;
  final value = tryParseDecimalInput(input);
  return value != null && nutrient.isValidValue(value);
}

/// The value in [input], or null for an empty input.
double? parseNutrientInput(String input, Nutrient nutrient) {
  if (!isValidNutrientInput(input, nutrient)) {
    throw ArgumentError.value(
      input,
      'input',
      'must be empty or from 0 to ${nutrient.maximum}',
    );
  }
  return tryParseDecimalInput(input);
}

void checkNutritionFacts(Map<Nutrient, double> nutritionFacts) {
  for (final MapEntry(key: nutrient, :value) in nutritionFacts.entries) {
    if (!nutrient.isValidValue(value)) {
      throw ArgumentError.value(
        value,
        nutrient.name,
        'must be from 0 to ${nutrient.maximum}',
      );
    }
  }
}
