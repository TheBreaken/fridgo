import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('de'));

  const quantities = {
    'one piece': (1.0, StockUnit.piece, '1 Stück'),
    'several pieces keep the singular': (6.0, StockUnit.piece, '6 Stück'),
    'half a piece': (0.5, StockUnit.piece, '0,5 Stück'),
    'grams without thousands separator': (1500.0, StockUnit.gram, '1500 g'),
    'kilograms with a decimal comma': (1.5, StockUnit.kilogram, '1,5 kg'),
    'three decimals': (0.001, StockUnit.liter, '0,001 l'),
    'no trailing zeros': (0.25, StockUnit.liter, '0,25 l'),
    'milliliters': (250.0, StockUnit.milliliter, '250 ml'),
    'one package in the singular': (1.0, StockUnit.package, '1 Packung'),
    'two packages in the plural': (2.0, StockUnit.package, '2 Packungen'),
    'half a package in the plural': (0.5, StockUnit.package, '0,5 Packungen'),
  };

  for (final MapEntry(key: description, value: (quantity, unit, expected))
      in quantities.entries) {
    test('formatting $description gives "$expected"', () {
      expect(unit.formatQuantity(quantity, l10n), expected);
    });
  }

  const labels = {
    StockUnit.piece: 'Stück',
    StockUnit.gram: 'g',
    StockUnit.kilogram: 'kg',
    StockUnit.milliliter: 'ml',
    StockUnit.liter: 'l',
    StockUnit.package: 'Packung',
  };

  for (final MapEntry(key: unit, value: expected) in labels.entries) {
    test('the unit ${unit.name} is labelled "$expected"', () {
      expect(unit.label(l10n), expected);
    });
  }
}
