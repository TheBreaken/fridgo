import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

extension StockUnitDisplay on StockUnit {
  String label(AppLocalizations l10n) => switch (this) {
    StockUnit.piece => l10n.stockUnitPiece,
    StockUnit.gram => l10n.stockUnitGram,
    StockUnit.kilogram => l10n.stockUnitKilogram,
    StockUnit.milliliter => l10n.stockUnitMilliliter,
    StockUnit.liter => l10n.stockUnitLiter,
    StockUnit.package => l10n.stockUnitPackage,
  };

  String formatQuantity(double quantity, AppLocalizations l10n) {
    final number = formatQuantityNumber(quantity, l10n);
    return switch (this) {
      StockUnit.piece => l10n.stockQuantityPiece(number),
      StockUnit.gram => l10n.stockQuantityGram(number),
      StockUnit.kilogram => l10n.stockQuantityKilogram(number),
      StockUnit.milliliter => l10n.stockQuantityMilliliter(number),
      StockUnit.liter => l10n.stockQuantityLiter(number),
      StockUnit.package => l10n.stockQuantityPackage(quantity, number),
    };
  }
}

/// The bare number, as the quantity fields accept it.
String formatQuantityNumber(double quantity, AppLocalizations l10n) =>
    NumberFormat('0.###', l10n.localeName).format(quantity);
