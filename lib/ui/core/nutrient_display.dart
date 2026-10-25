import 'package:fridgo/domain/nutrient.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';

extension NutrientDisplay on Nutrient {
  String label(AppLocalizations l10n) => switch (this) {
    Nutrient.energy => l10n.nutrientEnergy,
    Nutrient.fat => l10n.nutrientFat,
    Nutrient.saturatedFat => l10n.nutrientSaturatedFat,
    Nutrient.carbohydrates => l10n.nutrientCarbohydrates,
    Nutrient.sugars => l10n.nutrientSugars,
    Nutrient.protein => l10n.nutrientProtein,
    Nutrient.salt => l10n.nutrientSalt,
  };

  String unit(AppLocalizations l10n) => switch (this) {
    Nutrient.energy => l10n.nutrientUnitKilocalorie,
    _ => l10n.nutrientUnitGram,
  };

  /// Whether the label lists it as part of the nutrient above ("davon").
  bool get isPartOfPrevious =>
      this == Nutrient.saturatedFat || this == Nutrient.sugars;

  String formatAmount(double value, AppLocalizations l10n) =>
      l10n.nutrientAmount(formatQuantityNumber(value, l10n), unit(l10n));

  /// The amount as a label shows it, energy in kcal and kJ.
  String formatValue(double value, AppLocalizations l10n) {
    final amount = formatAmount(value, l10n);
    if (this != Nutrient.energy) return amount;
    final kilojoules = (value * kilojoulesPerKilocalorie).roundToDouble();
    return l10n.nutrientEnergyValue(
      amount,
      formatQuantityNumber(kilojoules, l10n),
    );
  }
}
