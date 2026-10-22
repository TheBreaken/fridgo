import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/nutrient.dart';

void main() {
  const inputCases = {
    'an empty input is valid': (Nutrient.fat, '', true),
    'an input of spaces is valid': (Nutrient.fat, '   ', true),
    'zero is valid': (Nutrient.salt, '0', true),
    'a decimal comma is valid': (Nutrient.fat, '12,5', true),
    'a decimal point is valid': (Nutrient.fat, '12.5', true),
    'three decimals are valid': (Nutrient.salt, '0,025', true),
    '100 g is valid': (Nutrient.carbohydrates, '100', true),
    '900 kcal is valid': (Nutrient.energy, '900', true),
    'more than 100 g is invalid': (Nutrient.carbohydrates, '100,1', false),
    'energy may exceed 100': (Nutrient.energy, '101', true),
    'more than 900 kcal is invalid': (Nutrient.energy, '901', false),
    'a negative value is invalid': (Nutrient.protein, '-1', false),
    'four decimals are invalid': (Nutrient.fat, '1,2345', false),
    'letters are invalid': (Nutrient.sugars, 'wenig', false),
    'a trailing decimal comma is invalid': (Nutrient.fat, '1,', false),
  };

  for (final MapEntry(key: description, value: (nutrient, input, isValid))
      in inputCases.entries) {
    test('nutrient input validation: $description', () {
      expect(isValidNutrientInput(input, nutrient), isValid);
    });
  }

  const parsedInputs = {
    'a decimal comma is read as decimal separator': ('3,5', 3.5),
    'a decimal point is read as decimal separator': ('3.5', 3.5),
    'zero is kept as a value': ('0', 0.0),
    'surrounding spaces are ignored': (' 12 ', 12.0),
  };

  for (final MapEntry(key: description, value: (input, expected))
      in parsedInputs.entries) {
    test('parsing the nutrient input: $description', () {
      expect(parseNutrientInput(input, Nutrient.fat), expected);
    });
  }

  test('parsing an empty nutrient input gives no value', () {
    expect(parseNutrientInput(' ', Nutrient.fat), isNull);
  });

  test('parsing an invalid nutrient input is rejected', () {
    expect(
      () => parseNutrientInput('-1', Nutrient.fat),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.invalidValue,
          'invalidValue',
          '-1',
        ),
      ),
    );
  });
}
