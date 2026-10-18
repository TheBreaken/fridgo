import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/stock_quantity.dart';

void main() {
  const inputCases = {
    'a whole number is valid': (input: '1', isValid: true),
    'a decimal comma is valid': (input: '1,5', isValid: true),
    'a decimal point is valid': (input: '1.5', isValid: true),
    'three decimals are valid': (input: '0,001', isValid: true),
    'a leading decimal comma is valid': (input: ',5', isValid: true),
    'surrounding spaces are valid': (input: ' 2 ', isValid: true),
    'a large number is valid': (input: '100000', isValid: true),
    'zero is invalid': (input: '0', isValid: false),
    'zero with decimals is invalid': (input: '0,000', isValid: false),
    'a negative number is invalid': (input: '-1', isValid: false),
    'four decimals are invalid': (input: '1,2345', isValid: false),
    'a trailing decimal comma is invalid': (input: '1,', isValid: false),
    'two decimal separators are invalid': (input: '1,5,5', isValid: false),
    'an exponent is invalid': (input: '1e3', isValid: false),
    'letters are invalid': (input: 'zwei', isValid: false),
    'an empty input is invalid': (input: '', isValid: false),
    'an input of spaces is invalid': (input: '   ', isValid: false),
    'a lone decimal comma is invalid': (input: ',', isValid: false),
  };

  for (final MapEntry(key: description, value: (:input, :isValid))
      in inputCases.entries) {
    test('quantity input validation: $description', () {
      expect(isValidQuantityInput(input), isValid);
    });
  }

  const parsedInputs = {
    'a decimal comma is read as decimal separator': ('1,5', 1.5),
    'a decimal point is read as decimal separator': ('1.5', 1.5),
    'three decimals are kept': ('0,001', 0.001),
    'a leading decimal comma means zero point': (',5', 0.5),
    'surrounding spaces are ignored': (' 2 ', 2.0),
  };

  for (final MapEntry(key: description, value: (input, expected))
      in parsedInputs.entries) {
    test('parsing the quantity input: $description', () {
      expect(parseQuantityInput(input), expected);
    });
  }

  test('parsing an invalid quantity input is rejected', () {
    expect(
      () => parseQuantityInput('0'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.invalidValue,
          'invalidValue',
          '0',
        ),
      ),
    );
  });

  const consumptions = {
    'consuming a part leaves the rest': (500.0, 150.0, 350.0),
    'consuming exactly everything leaves 0': (500.0, 500.0, 0.0),
    'consuming more than available leaves 0': (500.0, 1500.0, 0.0),
    'consuming the smallest step leaves the rest': (1.0, 0.001, 0.999),
    'decimal quantities leave no binary rest': (0.3, 0.1, 0.2),
    'decimal quantities in kilogram': (1.5, 0.25, 1.25),
    'consuming more than a decimal quantity leaves 0': (0.1, 0.3, 0.0),
    'one piece of six leaves five': (6.0, 1.0, 5.0),
  };

  for (final MapEntry(key: description, value: (quantity, consumed, expected))
      in consumptions.entries) {
    test('quantity after consuming: $description', () {
      expect(quantityAfterConsuming(quantity, consumed), expected);
    });
  }

  const invalidConsumptions = {
    'consuming 0 is rejected': 0.0,
    'consuming a negative quantity is rejected': -1.0,
  };

  for (final MapEntry(key: description, value: consumed)
      in invalidConsumptions.entries) {
    test('quantity after consuming: $description', () {
      expect(
        () => quantityAfterConsuming(500, consumed),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            consumed,
          ),
        ),
      );
    });
  }
}
