import 'package:fridgo/domain/storage_location.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/emoji.dart';

extension StorageLocationKindDisplay on StorageLocationKind {
  String get emoji => switch (this) {
    StorageLocationKind.refrigerator => Emoji.milk,
    StorageLocationKind.freezer => Emoji.iceCube,
    StorageLocationKind.pantry => Emoji.jar,
    StorageLocationKind.cellar => Emoji.wineGlass,
    StorageLocationKind.other => Emoji.basket,
  };

  String label(AppLocalizations l10n) => switch (this) {
    StorageLocationKind.refrigerator => l10n.storageLocationKindRefrigerator,
    StorageLocationKind.freezer => l10n.storageLocationKindFreezer,
    StorageLocationKind.pantry => l10n.storageLocationKindPantry,
    StorageLocationKind.cellar => l10n.storageLocationKindCellar,
    StorageLocationKind.other => l10n.storageLocationKindOther,
  };
}
