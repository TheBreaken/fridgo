# Fridgo

Arbeitstitel war "Kühlschrank App".

## Primäres Ziel

Fridgo gibt einen Überblick über die vorhandenen Lebensmittel in mehreren Wohnungen. Der
Nutzer pendelt zwischen Wohnungen und will

- weniger wegwerfen, weil er sieht, was bald abläuft, und
- gezielt einkaufen, weil er sieht, was in der Zielwohnung liegt.

Optik und müheloses Erfassen sind die beiden Kernziele, keine Nachgedanken.

- **Optik:** Icons, Bilder und Animationen sollen das Eintragen und Durchsehen angenehm
  machen. Eine Änderung, die funktioniert, aber lieblos aussieht, ist nicht fertig.
- **Müheloses Erfassen:** Jedes Produkt von Hand einzutippen hält niemand lange durch. Die
  App nimmt dem Nutzer so viel Eingabe ab wie möglich: Barcode, Kassenbon, Vorschläge aus
  dem, was sie schon kennt. Eine Erfassung, die mehr Tipps braucht als nötig, ist nicht
  fertig.

## Rahmen

- Ein Nutzer, ein Handy, das mitpendelt. Keine Konten, kein Backend, keine Synchronisierung.
- Alle Daten liegen lokal auf dem Gerät. Die App funktioniert vollständig offline.
- Netzwerk gibt es nur für den Abruf bei Open Food Facts. Fehlt das Netz oder das Produkt,
  fällt die App auf manuelle Eingabe zurück.
- Die Texterkennung von Kassenbons läuft auf dem Gerät, ohne Netz.
- Android und iOS zählen gleich. Jede Änderung wird auf beiden Plattformen geprüft.

## Umfang

**Version 1**

- Wohnungen und Lagerorte anlegen
- Lebensmittel mit Foto und MHD (Mindesthaltbarkeitsdatum) hinzufügen
- Bestandsübersicht pro Wohnung, nach MHD sortiert
- Menge reduzieren (Teilverbrauch und vollständiger Verbrauch)
- lokale Erinnerungen vor Ablauf des MHD
- Barcode-Scan mit Abruf bei Open Food Facts, auch mehrere Barcodes nacheinander
- MHD und Lagerort beim Erfassen aus Erfahrung vorschlagen
- Kassenbon fotografieren, Zeilen erkennen und nach Prüfung als Bestand übernehmen
- Export und Import (Datenbank und Bilder gemeinsam)

Empfohlene Reihenfolge: erst die Basis lauffähig, dann Erfassen (Barcode, Kassenbon), dann
Export/Import, zuletzt Erinnerungen.

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
- Ein Lagerort hat eine Art (`StorageLocationKind`: Kühlschrank, Gefrierfach, Vorrat, Keller,
  Sonstiges), die sein Icon bestimmt, und einen frei wählbaren Namen.
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
| Primärschlüssel (UUID v4)       | `uuid`                                      |
| Unveränderliche Modelle         | `freezed_annotation`, `freezed`             |
| Codegenerierung                 | `build_runner`, `drift_dev`                 |
| Fotos aufnehmen und auswählen   | `image_picker`                              |
| Bilddateien ablegen             | `path_provider`                             |
| Barcode-Scanner                 | `mobile_scanner`                            |
| Texterkennung (Kassenbon)       | `google_mlkit_text_recognition`             |
| SVG-Grafiken                    | `flutter_svg`                               |
| Kleine Einstellungen            | `shared_preferences`                        |
| Erinnerungen                    | `flutter_local_notifications`               |
| Texte                           | `flutter_localizations` mit ARB-Dateien, `intl` |
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

Ordnerstruktur:

```
lib/
  main.dart
  app/                 App-Widget und Router
  l10n/                ARB-Dateien
  ui/
    <anwendungsfall>/  Screen, ViewModel und nur dort benutzte Widgets
    core/              von mehreren Anwendungsfällen geteilte Widgets
  domain/              Modelle
  data/
    repositories/
    database/          drift
test/                  spiegelt lib/
```

- Die UI ist nach Anwendungsfall geschnitten, Modelle und Daten nach Schicht, weil mehrere
  Anwendungsfälle dieselben Modelle und Repositories benutzen.
- Unter `ui/` steht ein Ordner je Screen oder eng zusammengehöriger Screen-Gruppe, zum
  Beispiel `homes/`, `stock_overview/`, `stock_item_detail/`. Die Dateien liegen flach
  darin, ohne Unterordner: `homes_screen.dart`, `homes_view_model.dart`.
- Ein Ordner entsteht mit seiner ersten Datei, nicht auf Vorrat.
- Kein Screen heißt `HomeScreen`; `Home` ist die Wohnung. Die App startet in der
  Übersicht der zuletzt gewählten Wohnung; darunter liegt die Wohnungsliste `HomesScreen`.

Feste Regeln:

- **Primärschlüssel sind UUIDs**, keine Autoincrement-IDs.
- **MHD und Öffnungsdatum sind Kalenderdaten**, keine UTC-Zeitpunkte. Keine
  Zeitzonenumrechnung. In der Domäne `CalendarDate`, in SQLite TEXT `YYYY-MM-DD`; kein
  `DateTime` für Kalenderdaten. `make test` läuft mit `TZ=Europe/Berlin`, damit
  Sommerzeit-Tests auch in der CI (UTC) etwas prüfen.
- **Fotos sind Dateien.** In SQLite steht nur ein Pfad relativ zum App-Verzeichnis, nie ein
  absoluter Pfad und nie das Bild selbst.
- Aufgenommene oder ausgewählte Fotos werden aus dem temporären Verzeichnis in das
  dauerhafte App-Verzeichnis kopiert, bevor ihr Pfad gespeichert wird.
- Übersichten laden Vorschaubilder, nie das Kamerafoto in voller Größe. Sie dekodieren das
  gespeicherte Foto verkleinert (`ResizeImage`); eigene Vorschaudateien gibt es nicht.
- Eine fehlende Bilddatei ist ein erwarteter Zustand und zeigt einen Platzhalter.
- **Jede Schemaänderung ist eine Migration** mit hochgezählter Schemaversion, von der
  ersten Tabelle an. Ablauf: `schemaVersion` erhöhen, `make schema` legt den neuen Stand
  unter `drift_schemas/` ab, Migration schreiben, Migrationstest unter
  `test/data/database/` ergänzen. Abgelegte Schemastände werden nie geändert.
- Der Export sichert Datenbank und Bilder gemeinsam; ein Export ohne Bilder ist
  unvollständig.
- Die aktuelle Zeit kommt über eine injizierte Uhr, damit Ablauf und Erinnerungen testbar
  sind.

## Kommandos

`flutter` und `dart` nie direkt aufrufen, immer über das `Makefile`. Das ersetzt in diesem
Projekt die Docker-Regel der globalen Vorgaben; Flutter läuft auf dem Host, FVM stellt die
gepinnte Version bereit.

Fehlt ein Target für ein wiederkehrendes Kommando, wird es im `Makefile` ergänzt.

`make integration-test` führt die Tests unter `integration_test/` aus. Sie laufen nur lokal, nicht
in der CI, und nur auf einem Emulator oder Simulator, nicht auf dem eigenen Gerät: Die Test-App
ersetzt die installierte App, erst `make run` stellt die echte wieder her. Das Gerät wählt
`make integration-test FLUTTER="fvm flutter -d <Geräte-ID>"`.

`make update-goldens` erzeugt die Referenzbilder der Golden-Tests neu, mit `TESTS=<Datei>` nur
für einzelne Tests. Die neuen Bilder vor dem Commit ansehen.

Das Dart-MCP (`dart`) darf genutzt werden, wo es sinnvoll ist, zum Beispiel für Hot Reload,
Laufzeitfehler oder den Widget-Inspektor einer laufenden App. Formatierung, Analyse und Tests
als Abnahme laufen weiterhin über das `Makefile`.

## Qualität

Eine Änderung ist fertig, wenn `make check` grün ist und `make build-android` sowie
`make build-ios` durchlaufen. Die CI (`.github/workflows/ci.yml`) führt dieselben Schritte wie
`make check` als einzelne Steps aus, damit ein Fehler seinen Schritt zeigt. Ändert sich ein
Target, das `check` benutzt, wird `ci.yml` mitgezogen.

- Formatierung: `dart format`, ohne Ausnahmen.
- Lint: `very_good_analysis`. Regeln werden nicht per `// ignore` umgangen; eine Abweichung
  steht mit Begründung in `analysis_options.yaml`.
- Generierter Code (`*.g.dart`, `*.freezed.dart`) wird nie von Hand bearbeitet.
- Der aus den ARB-Dateien erzeugte Code (`lib/l10n/app_localizations*.dart`) wird nicht
  eingecheckt. `make analyze` und `make test` erzeugen ihn vorher über `make l10n`.
- Ebenso wird der Code von build_runner und drift_dev nicht eingecheckt. `make codegen`
  läuft vor `analyze`, `test`, `run` und den Builds. Eingecheckt sind nur die
  Schemastände unter `drift_schemas/`.

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

Golden-Tests fallen je nach Betriebssystem unterschiedlich aus. Die Referenzbilder entstehen
lokal auf macOS, deshalb läuft auch die CI auf macOS. Weil macOS die Kanten von Schrift je nach
Version anders glättet, toleriert der Vergleich bis 0,5 % abweichende Pixel. Goldens gibt es nur
im hellen Modus. Sie laden echte Schriften und Schatten über `test/ui/golden.dart`, die übrigen
Widget-Tests nicht.

## Aufgaben

Der Weg zu Version 1 steht in `tasks/tasks.json`. Eine Session bearbeitet genau eine Aufgabe.

| Feld                 | Bedeutung                                                     |
| -------------------- | ------------------------------------------------------------- |
| `id`                 | `T` und drei Ziffern, fortlaufend, wird nie neu vergeben      |
| `type`               | einer der Commit-Types aus den globalen Vorgaben              |
| `priority`           | `high`, `medium` oder `low`                                   |
| `status`             | `open` oder `done`                                            |
| `dependsOn`          | IDs der Aufgaben, die vorher `done` sein müssen               |
| `description`        | Ziel, Abgrenzung und was vor der Umsetzung zu klären ist      |
| `acceptanceCriteria` | prüfbare Kriterien, zusätzlich zu den Regeln unter "Qualität" |

Ablauf einer Session:

1. Von aktuellem `main` starten. Ist keine Aufgabe genannt, gilt unter den Aufgaben mit
   Status `open` und erfüllten `dependsOn` die mit der höchsten Priorität, bei Gleichstand
   die erste in der Datei.
2. Branch `feature/<id>-<kurztitel>` anlegen, bei Aufgaben vom Typ `fix` stattdessen
   `bugfix/<id>-<kurztitel>`. Der Kurztitel ist englisch, zum Beispiel
   `feature/T005-add-homes`.
3. Erst klären, was die Beschreibung unter "Zu klären" nennt oder sonst offen lässt, dann
   umsetzen.
4. Sind Abnahmekriterien und "Qualität" erfüllt: nennen, was auf dem Gerät anzusehen ist,
   und auf die Freigabe warten.
5. Nach der Freigabe `status` auf `done` setzen, committen und einen PR öffnen. Auf `main`
   gilt die Aufgabe erst mit dem Merge als erledigt; die nächste Aufgabe beginnt danach.

Regeln:

- Fällt etwas auf, das nicht zur laufenden Aufgabe gehört, wird es eine neue Aufgabe mit
  der nächsten freien ID im selben PR, nicht Teil der laufenden Änderung. Was unter
  "Später" oder "Nicht geplant" fällt, wird nur in der Antwort erwähnt.
- Erledigte Aufgaben bleiben in der Datei stehen.
- Jede Aufgabe, die das Erfassen berührt, nennt ein Tipp-Budget als Abnahmekriterium: die
  Zahl der Tipps vom Einstieg bis zum gespeicherten Bestand.
- Eine Entscheidung, die über die Aufgabe hinaus gilt, wird in dieser Datei festgehalten.

## Assets

- Motive (Lebensmittel, Lagerorte, leere Zustände, Platzhalter) stammen aus
  [Noto Emoji](https://github.com/googlefonts/noto-emoji), als SVG aus `2D/svg/` mit
  unverändertem Dateinamen (`emoji_u<Codepoint>.svg`) unter `assets/emoji/`. Lizenz: SIL Open
  Font License 1.1, liegt als `assets/emoji/LICENSE` bei. Ein Motiv kommt erst mit dem
  Feature, das es zeigt; die Pfade stehen in `lib/ui/core/emoji.dart`.
- Bedien-Icons (Hinzufügen, Zurück, Löschen …) sind die in Flutter eingebauten Material
  Icons in der Variante Rounded (`Icons.*_rounded`), nicht aus dem Emoji-Set.
- Schrift ist Nunito (SIL Open Font License 1.1) als statische TTF in den Stärken 400, 600 und
  700 unter `assets/fonts/nunito/`, Lizenz als `OFL.txt` daneben. Gebündelt, weil die App
  offline läuft.
- Vor der Übernahme die Lizenz prüfen und sie im Repo dokumentieren.
- Keine Stile mischen. Fehlt ein Motiv im Set, nachfragen statt ein fremdes dazuzunehmen.
- Ein neues SVG muss `flutter_svg` darstellen können: keine Filter, Masken oder
  Illustrator-Exporte mit DOCTYPE. `test/ui/core/emoji_test.dart` lädt jedes Motiv; ein
  neues Motiv wird dort ergänzt.
- Pro Produkt ergänzen eigene Fotos und Bilder von Open Food Facts das Set.

## Gestaltung

Richtung „Frisch“: Salatgrün als Hauptfarbe, Karotten-Orange als Akzent für die Hauptaktion,
weiche große Radien, Nunito, farbige Noto-Emojis. Hell und dunkel, die App folgt der
Systemeinstellung; einen Schalter in der App gibt es nicht.

- Theme und Gestaltungswerte liegen zentral in `lib/ui/core/app_theme.dart`: Farben im
  `ColorScheme`, Schrift im `TextTheme`, Abstände in `Spacing`, Radien in `Corners`, feste
  Größen in `Sizes`. Widgets enthalten keine Farbwerte, Schriftgrößen oder Zahlen für
  Abstände und Radien.
- Karten liegen auf `surface`, die Seite dahinter auf `surfaceDim`. Die Hauptaktion ist der
  Floating Action Button in `tertiary`.
- In der Bestandsübersicht ist die Hauptaktion der Kamera-Knopf unten mittig. Er öffnet den
  Scanner, „Ohne Barcode“ führt von dort ins Formular. Weitere Wege zum Erfassen
  (Kassenbon, mehrere Barcodes) beginnen ebenfalls dort, nicht an einem zweiten Knopf.
- Leere Zustände nutzen `EmptyState`, fehlende Bilder `ImagePlaceholder` aus `lib/ui/core/`.
- Jeder Screen wird hell und dunkel angesehen.

## Sprache und Commits

- Dokumentation und UI-Texte auf Deutsch, Code und Bezeichner auf Englisch.
- UI-Texte stehen in ARB-Dateien, nicht als String im Widget.
- Aus den globalen Vorgaben gelten Arbeitsweise, Clean Code, Kommentare, Autorschaft und
  das Commit-Format. Die Abschnitte zu Docker, Symfony, Shopware, PHPUnit und Twig gelten
  hier nicht.
- Commit-Messages auf Englisch, abweichend von den globalen Vorgaben; der Type bleibt klein,
  zum Beispiel `refactor: set app identifier`.
- Commit-Messages ohne `Related:`-Zeile; es gibt kein Ticketsystem.

## Offene Punkte

- Die UI ist zunächst nur deutsch.
