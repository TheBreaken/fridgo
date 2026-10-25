# Fridgo

Lebensmittelbestand über mehrere Wohnungen im Blick behalten. Flutter-App für Android und
iOS.

Ziel, Umfang, Architektur und Regeln stehen in [CLAUDE.md](CLAUDE.md).

## Einrichten

Voraussetzung: [FVM](https://fvm.app), Android SDK, Xcode.

```
make setup
make check
make run
```

## Open Food Facts

Zu einem unbekannten Barcode holt die App Name und Nährwerte bei
[Open Food Facts](https://world.openfoodfacts.org). Geprüft am 2026-10-24 nach den
[Nutzungsbedingungen](https://world.openfoodfacts.org/terms-of-use) und der
[API-Dokumentation](https://openfoodfacts.github.io/openfoodfacts-server/api/):

- Die Datenbank steht unter der [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/),
  die einzelnen Inhalte unter der [Database Contents License (DbCL)](https://opendatacommons.org/licenses/dbcl/1-0/),
  Produktbilder unter [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
- Wer die Daten nutzt, nennt Open Food Facts und die Lizenz. Die App tut das im Hinweis unter
  einem übernommenen Produkt.
- Jede Anfrage trägt einen eigenen User-Agent mit Kontakt:
  `Fridgo/1.0 (https://github.com/TheBreaken/fridgo)`.
- Produktabrufe sind auf 15 pro Minute und Nutzer begrenzt; wer darüber liegt, riskiert eine
  Sperre.
- Die Daten kommen ohne Gewähr; die App lässt sie deshalb vor dem Speichern prüfen.
