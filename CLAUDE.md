# Fridgo

Arbeitstitel war "Kühlschrank App".

## Primäres Ziel

Fridgo gibt einen Überblick über die vorhandenen Lebensmittel in mehreren Wohnungen. Der
Nutzer pendelt zwischen Wohnungen und will

- weniger wegwerfen, weil er sieht, was bald abläuft, und
- gezielt einkaufen, weil er sieht, was in der Zielwohnung liegt.

Die Optik ist ein Kernziel, kein Nachgedanke: Icons, Bilder und Animationen sollen das
Eintragen und Durchsehen angenehm machen. Eine Änderung, die funktioniert, aber lieblos
aussieht, ist nicht fertig.

## Rahmen

- Ein Nutzer, ein Handy, das mitpendelt. Keine Konten, kein Backend, keine Synchronisierung.
- Alle Daten liegen lokal auf dem Gerät. Die App funktioniert vollständig offline.
- Netzwerk gibt es nur für den Abruf bei Open Food Facts. Fehlt das Netz oder das Produkt,
  fällt die App auf manuelle Eingabe zurück.
- Android und iOS zählen gleich. Jede Änderung wird auf beiden Plattformen geprüft.

## Umfang

**Version 1**

- Wohnungen und Lagerorte anlegen
- Lebensmittel mit Foto und MHD (Mindesthaltbarkeitsdatum) hinzufügen
- Bestandsübersicht pro Wohnung, nach MHD sortiert
- Menge reduzieren (Teilverbrauch und vollständiger Verbrauch)
- lokale Erinnerungen vor Ablauf des MHD
- Barcode-Scan mit Abruf bei Open Food Facts
- Export und Import (Datenbank und Bilder gemeinsam)

Empfohlene Reihenfolge: erst die Basis lauffähig, dann Export/Import, Erinnerungen, zuletzt
Barcode.

**Später**

- Bestand zwischen Lagerorten und Wohnungen verschieben, ganz oder teilweise, als
  Datenbanktransaktion und mit Test "Verschieben ohne Mengenverlust"
- Tests nativer Systemdialoge mit Patrol

**Nicht geplant** — nicht bauen und nicht vorbereiten, solange es hier steht:

- Einkaufsliste, Mindestbestand, Rezeptvorschläge
- Backend, Konten, Synchronisierung, mehrere Nutzer

## Domänenmodell

```
Wohnung 1 ── n Lagerort 1 ── n Bestand n ── 1 Produkt
```

| Deutsch  | Im Code           | Bedeutung                                                      |
| -------- | ----------------- | -------------------------------------------------------------- |
| Wohnung  | `Home`            | Ein Wohnort mit seinen Lagerorten                              |
| Lagerort | `StorageLocation` | Kühlschrank, Gefrierfach oder Vorrat innerhalb einer Wohnung   |
| Produkt  | `Product`         | Name, Barcode, Bild, Nährwerte — unabhängig davon, wo es liegt |
| Bestand  | `StockItem`       | Produkt an einem Lagerort: Menge, Einheit, MHD, Öffnungsdatum  |
| MHD      | `bestBeforeDate`  | Mindesthaltbarkeitsdatum                                       |

- Dasselbe Produkt kann mehrere Bestände mit verschiedenen MHDs haben, auch am selben
  Lagerort.
- Diese Begriffe gelten im Code durchgehend. Keine Synonyme (`Fridge`, `Item`, `Inventory`).

## Tech-Stack

Flutter-Stable, fest gepinnt in `.fvmrc`. Sprache ist Dart.

Die folgenden Pakete sind freigegeben. Ein Paket kommt erst mit dem ersten Feature ins
`pubspec.yaml`, das es benutzt. Jedes Paket außerhalb dieser Liste braucht vorher eine
Rückfrage.

| Bereich                         | Paket                                       |
| ------------------------------- | ------------------------------------------- |
| State Management und DI         | `flutter_riverpod`                          |
| Navigation                      | `go_router`                                 |
| Lokale Datenbank                | `drift`, `drift_flutter`                    |
| Unveränderliche Modelle         | `freezed_annotation`, `freezed`             |
| Codegenerierung                 | `build_runner`, `drift_dev`                 |
| Fotos aufnehmen und auswählen   | `image_picker`                              |
| Bilddateien ablegen             | `path_provider`                             |
| Barcode-Scanner                 | `mobile_scanner`                            |
| SVG-Grafiken                    | `flutter_svg`                               |
| Kleine Einstellungen            | `shared_preferences`                        |
| Erinnerungen                    | `flutter_local_notifications`               |
| Texte                           | `flutter_localizations` mit ARB-Dateien     |
| Open Food Facts                 | `http`, `json_serializable`                 |
| Lint-Regeln                     | `very_good_analysis`                        |
| Tests                           | `flutter_test`, `integration_test`, `mocktail` bei Bedarf |

## Architektur

MVVM mit Repositories. Die Abhängigkeiten zeigen nur in eine Richtung:

```
View (Widget) → ViewModel → Repository → Datenquelle (drift, Dateisystem, HTTP)
```

- Views enthalten Darstellung und leiten Eingaben weiter. Keine Datenbank-, Datei- oder
  HTTP-Zugriffe im Widget.
- ViewModels halten den UI-Zustand und kennen nur Repositories.
- Nur Repositories sprechen mit drift, dem Dateisystem und HTTP. drift-Typen verlassen das
  Repository nicht.
- Abhängigkeiten kommen über Riverpod-Provider herein, damit Tests sie ersetzen können.

Feste Regeln:

- **Primärschlüssel sind UUIDs**, keine Autoincrement-IDs.
- **MHD und Öffnungsdatum sind Kalenderdaten**, keine UTC-Zeitpunkte. Keine
  Zeitzonenumrechnung.
- **Fotos sind Dateien.** In SQLite steht nur ein Pfad relativ zum App-Verzeichnis, nie ein
  absoluter Pfad und nie das Bild selbst.
- Aufgenommene oder ausgewählte Fotos werden aus dem temporären Verzeichnis in das
  dauerhafte App-Verzeichnis kopiert, bevor ihr Pfad gespeichert wird.
- Übersichten laden Vorschaubilder, nie das Kamerafoto in voller Größe.
- Eine fehlende Bilddatei ist ein erwarteter Zustand und zeigt einen Platzhalter.
- **Jede Schemaänderung ist eine Migration** mit hochgezählter Schemaversion, von der
  ersten Tabelle an.
- Der Export sichert Datenbank und Bilder gemeinsam; ein Export ohne Bilder ist
  unvollständig.
- Die aktuelle Zeit kommt über eine injizierte Uhr, damit Ablauf und Erinnerungen testbar
  sind.

## Kommandos

`flutter` und `dart` nie direkt aufrufen, immer über das `Makefile`. Das ersetzt in diesem
Projekt die Docker-Regel der globalen Vorgaben; Flutter läuft auf dem Host, FVM stellt die
gepinnte Version bereit.

| Target               | Zweck                                             |
| -------------------- | ------------------------------------------------- |
| `make setup`         | gepinnte Flutter-Version und Pakete laden         |
| `make format`        | Code formatieren                                  |
| `make check`         | Formatierung prüfen, analysieren, testen          |
| `make analyze`       | nur statische Analyse                             |
| `make test`          | nur Tests                                         |
| `make run`           | App auf dem verbundenen Gerät oder Emulator starten |
| `make build-android` | Debug-APK bauen                                   |
| `make build-ios`     | iOS-Debug-Build ohne Signierung                   |

Fehlt ein Target für ein wiederkehrendes Kommando, wird es im `Makefile` ergänzt.

## Qualität

Eine Änderung ist fertig, wenn `make check` grün ist und `make build-android` sowie
`make build-ios` durchlaufen. Die CI (`.github/workflows/ci.yml`) führt `make check` aus.

- Formatierung: `dart format`, ohne Ausnahmen.
- Lint: `very_good_analysis`. Regeln werden nicht per `// ignore` umgangen; eine Abweichung
  steht mit Begründung in `analysis_options.yaml`.
- Generierter Code (`*.g.dart`, `*.freezed.dart`) wird nie von Hand bearbeitet.

Testebenen:

| Ebene             | Werkzeug                         | Beispiele                                           |
| ----------------- | -------------------------------- | --------------------------------------------------- |
| Unit              | `flutter_test`, Fakes            | Mengenberechnung, MHD-Sortierung, ViewModel-Aktionen |
| Datenbank         | drift mit In-Memory-Datenbank    | Abfragen, Transaktionen, Migrationen                |
| Widget            | `flutter_test`                   | Menge ändern, Validierung, leere Zustände           |
| Golden            | `matchesGoldenFile`              | Produktkarten und wichtige Screens                  |
| Integration       | `integration_test`               | Wohnung anlegen → Produkt hinzufügen → verbrauchen  |

Fälle, die für diese App besonders zählen:

- dasselbe Produkt mit zwei verschiedenen MHDs
- Teilverbrauch und vollständiger Verbrauch
- Migration einer älteren Datenbank ohne Datenverlust
- fehlende oder gelöschte Bilddatei
- Bestand nach Schließen und erneutem Start weiterhin vorhanden

Golden-Tests fallen auf Linux (CI) und macOS (lokal) unterschiedlich aus. Vor dem ersten
Golden-Test nachfragen, in welcher Umgebung die Referenzbilder entstehen.

## Assets

- Icons und Illustrationen stammen aus einem einzigen offenen Emoji- oder Icon-Set, als SVG.
  Welches Set es wird, ist noch offen und wird mit dem ersten Feature mit Bildern
  entschieden.
- Vor der Übernahme die Lizenz prüfen und sie im Repo dokumentieren.
- Keine Stile mischen. Fehlt ein Motiv im Set, nachfragen statt ein fremdes dazuzunehmen.
- Pro Produkt ergänzen eigene Fotos und Bilder von Open Food Facts das Set.

## Sprache und Commits

- Dokumentation und UI-Texte auf Deutsch, Code und Bezeichner auf Englisch.
- UI-Texte stehen in ARB-Dateien, nicht als String im Widget.
- Aus den globalen Vorgaben gelten Arbeitsweise, Clean Code, Kommentare, Autorschaft und
  das Commit-Format. Die Abschnitte zu Docker, Symfony, Shopware, PHPUnit und Twig gelten
  hier nicht.
- Commit-Messages ohne `Related:`-Zeile; es gibt kein Ticketsystem.

## Offene Punkte

- Die App-Kennung ist der Platzhalter `com.example.fridgo`. Vor dem ersten TestFlight- oder
  Store-Build ersetzen.
- Die UI ist zunächst nur deutsch.
