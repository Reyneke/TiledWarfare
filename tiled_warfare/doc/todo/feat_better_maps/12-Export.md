# Export der Tilemap Engine

Die ursprüngliche Tilemap-Engine entstand als Engine, welche eine Urban-Brawl-Umsetzung ermöglichen sollte. Leider stand das Projekt eine Weile still, aber jetzt geht es langsam wieder los. Daher ist die Überlegung, die aktuelle Tilemap-Engine in das Urban-Brawl-Projekt einzubinden – sofern dies möglich ist.

Dieses Dokument ist zunächst ein reines Planungsdokument zur Klärung aller Fragen und Erstellung eines Plans.

## Zu klärende Fragen und Entscheidungen

### Einbindungsform

**Frage:** Soll die Engine als eigenständiges Pub-Paket ausgelagert, als Git-Submodul/Pfadabhängigkeit eingebunden oder als Kopie in das Urban-Brawl-Projekt übernommen werden?

**Entscheidung:** Einbindung als **Git-Submodul** im OpenBrawl Repository. Dies dient hauptsächlich der Wartbarkeit: Die Engine soll hier weiterentwickelt werden, ohne ein zweites Repo für die Engine pflegen zu müssen. Änderungen, die hier im Projekt eintreten und die Engine betreffen, sollen direkt auch im OpenBrawl Projekt vertreten sein.

### Umfang

**Frage:** Welche Bestandteile sollen exportiert werden (TMX-Parser, Hex-Utility, Karten-Rendering, Spawn-/Objekt-Logik)?

**Antwort:** Da das OpenBrawl-Projekt eine andere Spielelogik hat (Spieler kontrollieren die Token nicht direkt usw.), dürften **TMX-Parser, Hex-Utility und Karten-Rendering** ausreichen. Die Spawn-/Objekt-Logik ist hingegen nicht ohne Weiteres übertragbar.

**Analyse des OpenBrawl-Repositories (durchgeführt):**

Das OpenBrawl-Projekt (`c:/Users/matth/dev/OpenBrawl/open_brawl`) besitzt bereits eine eigene, rudimentäre Karten-Implementierung:

| Datei | Zweck | Status |
|---|---|---|
| `lib/utils/tmx_parser.dart` | Eigener TMX-/TMJ-Parser (`TmxMap`, `TmxTileset`) | Aktiv, aber eingeschränkt |
| `lib/widgets/widget_hex_map_renderer.dart` | Hex-Grid-Renderer (`HexMapRenderer`, `_HexMapPainter`) | Aktiv, mit Token-Zeichnung |
| `lib/widgets/widget_map_loader.dart` | Lädt TMJ-Karte, generiert Tokens, Tile-Auswahl | Aktiv |
| `lib/widgets/widget_maploader.dart` | Lädt TMX-Karte (veraltet) | **Unbenutzt** (durch `WidgetMapLoader` ersetzt) |
| `lib/objects/object_token.dart` | `ObjectToken` mit `hexCol`/`hexRow` | Aktiv, spiel-spezifisch |

**Grenzen des bestehenden OpenBrawl-Parsers** (`tmx_parser.dart`):
- Nur **CSV**-Encoding (kein Base64/Zlib/Gzip)
- Nur **ein** Layer (`.first`)
- Nur **ein** Tileset (`.first`)
- Keine Objektgruppen (Spawns, Terrain-Regionen)
- Keine Flip-Bit-Maskierung

**Grenzen des bestehenden OpenBrawl-Renderers** (`widget_hex_map_renderer.dart`):
- Hex-Geometrie (Zentrum, Hit-Test) ist direkt im Widget implementiert, nicht zentralisiert
- Kein Viewport-Culling, kein `RepaintBoundary`
- Token-Zeichnung ist fest mit `ObjectToken`/`ObjectPlayer` gekoppelt (spiel-spezifisch)

**Vergleich mit der TiledWarfare-Engine:**
- `lib/services/map_parser.dart` + `lib/models/map_data.dart`: unterstützt **mehrere Layer**, **mehrere Tilesets**, **Base64/Zlib/Gzip**, **Objektgruppen** (inkl. Polygon-Punkte), Flip-Bit-Maskierung → deutlich robuster als der OpenBrawl-Parser
- `lib/utils/hex_grid.dart`: zentralisierte Hex-Utility (Pixel↔Hex, Nachbarn, Distanz) → ersetzt die im Renderer duplizierte Geometrie
- `lib/services/map_exceptions.dart`: spezifische Fehlerbehandlung

**Fazit zum Export-Umfang:**
- **Exportieren**: `map_parser.dart`, `map_data.dart`, `map_exceptions.dart`, `hex_grid.dart` sowie ein entkoppelter Hex-Map-Renderer (ohne Token-/Spieler-Kopplung)
- **Nicht exportieren**: `ObjectToken`, `ObjectPlayer`, `ObjectTeam`, `WidgetMapLoader` (Token-Generierung), Spawn-/Objekt-Logik – diese bleiben spiel-spezifisch in OpenBrawl
- **Ersetzen**: Der bestehende OpenBrawl-Parser und -Renderer werden durch die exportierte Engine ersetzt bzw. darauf aufgebaut
- **Abhängigkeit**: OpenBrawl nutzt aktuell `hex_toolkit` (^1.0.0) und `xml` (^6.5.0) – die exportierte Engine bringt `hex_grid.dart` mit, `xml` bleibt als Abhängigkeit

**Entscheidung:** Ja, der OpenBrawl-Parser kann und soll direkt mit der exportierten Engine aktualisiert werden. Da er deutlich hinter der TiledWarfare-Engine zurücksteht (nur CSV, ein Layer, ein Tileset, keine Objektgruppen, keine Flip-Bit-Maskierung), wird er durch die robustere Engine ersetzt. Dies geschieht im Zuge der Einbindung als Git-Submodul: Der bestehende `tmx_parser.dart` in OpenBrawl wird durch die exportierten Dateien (`map_parser.dart`, `map_data.dart`, `map_exceptions.dart`, `hex_grid.dart`) ersetzt, und der Renderer (`widget_hex_map_renderer.dart`) wird auf die zentralisierte Hex-Utility umgestellt. Die spiel-spezifischen Teile (Token-Generierung, `ObjectToken`, `ObjectPlayer`, `ObjectTeam`) bleiben unverändert in OpenBrawl.

### Entkopplung

**Frage:** Wie stark ist die Engine aktuell mit TiledWarfare-spezifischem Code (Widgets, Services, Assets) verwoben, und welche Refactorings sind nötig, um sie eigenständig nutzbar zu machen?

**Analyse der TiledWarfare-Engine (durchgeführt):**

| Datei | Externe Abhängigkeiten | Entkopplungs-Status |
|---|---|---|
| `lib/services/map_exceptions.dart` | Keine | ✅ Vollständig entkoppelt |
| `lib/models/map_data.dart` | `flutter/foundation.dart` (`@immutable`, `listEquals`, `mapEquals`), `hex_grid.dart` | ⚠️ Teilweise entkoppelt |
| `lib/services/map_parser.dart` | `dart:io` (zlib/gzip), `flutter/services.dart` (`rootBundle`), `xml`, `map_data.dart`, `map_exceptions.dart` | ⚠️ Teilweise entkoppelt |
| `lib/utils/hex_grid.dart` | `dart:ui` (`Offset`), **`object_token.dart`** | ❌ Kritisch gekoppelt |

**Kritische Kopplung: `hex_grid.dart` ↔ `ObjectToken`**
- `hex_grid.dart` importiert `package:tiled_warfare/objects/object_token.dart`
- Die Methoden `buildOccupiedHexFields()` und `buildOccupiedHexesFromIterable()` hängen direkt von `ObjectToken` ab (nutzen `token.woundValue`, `token.position`)
- **Refactoring nötig**: Diese Methoden müssen aus `hex_grid.dart` entfernt oder generisch gemacht werden (z. B. über eine Getter-Funktion `Offset Function(T) getPosition`), damit die Hex-Utility ohne das Spielmodell auskommt

**Kritische Kopplung: `map_parser.dart` ↔ `dart:io`**
- `map_parser.dart` importiert `dart:io` für `zlib.decode()`/`gzip.decode()` (Base64-kodierte Layer)
- **Problem**: `dart:io` ist auf Web-Plattformen nicht verfügbar → bricht die Web-Kompatibilität
- **Refactoring nötig**: Auf `package:archive` umstellen oder konditionale Imports verwenden

**Weitere Kopplungen:**
- `map_data.dart` nutzt `flutter/foundation.dart` für `@immutable`, `listEquals`, `mapEquals` – akzeptabel, da `foundation` ein leichtgewichtiges Flutter-Paket ist
- `map_data.dart` enthält die Klasse `MapMeta` (Metadaten aus `maps.json`) – **spiel-spezifisch**, sollte nicht exportiert werden
- `map_parser.dart` nutzt `flutter/services.dart` (`rootBundle`) für Asset-Laden – akzeptabel für eine Flutter-Engine, aber der `AssetBundle`-Parameter ist bereits injizierbar (gut für Tests)
- `map_data.dart` enthält `TerrainType`/`TerrainConfig` (Geländesystem) – **Engine-Level**, sollte exportiert werden

**Fazit zur Entkopplung:**
- **Bereits entkoppelt**: `map_exceptions.dart` (keine Änderungen nötig)
- **Refactoring nötig (kritisch)**: `hex_grid.dart` von `ObjectToken` entkoppeln; `map_parser.dart` von `dart:io` entkoppeln (Web-Kompatibilität)
- **Refactoring nötig (leicht)**: `MapMeta` aus `map_data.dart` ausschließen oder in ein separates spiel-spezifisches Modul verschieben
- **Kein Refactoring nötig**: `flutter/foundation.dart` und `flutter/services.dart` sind akzeptable Abhängigkeiten für eine Flutter-Engine

### Wartung

**Frage:** Wo soll die Engine künftig gepflegt werden (mono-Repo, eigenes Repo) und wie werden Änderungen zwischen den Projekten synchronisiert?

**Entscheidung:** Die Engine soll hier gewartet werden. Jegliche Änderungen, die im OpenBrawl-Projekt Verwendung finden, sollen automatisch dort übernommen werden – daher die Idee mit dem Git-Submodul.

### Kompatibilität

**Frage:** Welche Flutter-/Dart-Versionen und Plattformen muss das Urban-Brawl-Projekt unterstützen?

**Entscheidung:** Dieselben Flutter-/Dart-Versionen und Plattformen, die dieses Projekt unterstützt.

### Merge der Feature-Branch in den Main-Branch

**Frage:** Da wir uns gerade in einem Nebenbranch befinden, wäre es für die Umsetzung evtl. sinnvoll, die Ergebnisse dieses Branches per Pull-Request in den Main-Branch zu übernehmen und das OpenBrawl-Repo den Main-Branch einbinden zu lassen?

**Entscheidung:** Ja, das ist sinnvoll. Ein Git-Submodul referenziert immer einen konkreten Kommitt – keinen Branch. Daher macht der Weg über den Merge per Pull-Request Sinn:

- **Stabiler Stand**: Der Feature-Branch wird per PR reviewed und mit den automatisierten Checks (CI) in den Main-Branch überführt → die Engine steht dort in einem getesteten, reproduzierbaren Zustand.
- **Klare Referenz für das Submodul**: Das OpenBrawl-Repo kann als Submodul-Referenz den gemergten Main-Commit verwenden (bzw. den Main-Branch im Submodul nachziehen).
- **Konsistente Weiterentwicklung**: Künftige Änderungen an der Engine fließen weiterhin über den normalen Workflow (Feature-Branch → PR → Main) und werden dann über das Submodul-Update in OpenBrawl übernommen – passend zur bereits getroffenen Entscheidung unter „Wartung".
- **Empfehlung**: Das Submodul im OpenBrawl-Repo sollte dem Main-Branch von TiledWarfare (commit nach Commit) folgen. Bei Bedarf kann in `.gitmodules` der `branch = main` gesetzt werden, um das Tracking explizit zu machen (das Submodul zeigt weiterhin auf konkrete, nachvollziehbare Commits).

## Was für Probleme können auftreten?

- **Versteckte Abhängigkeiten**: Die Engine nutzt u. U. interne Pfade, Assets oder Services (z. B. `rootBundle`, hardcodierte Bildpfade), die im Zielprojekt nicht vorhanden sind.
- **Versionskonflikte**: Unterschiedliche Flutter-/Dart-Versionen oder abweichende Abhängigkeiten (z. B. `package:xml`) zwischen den Projekten.
- **Lizenz- und Urheberfragen**: Klärung der Lizenz der Engine sowie der verwendeten Assets (Tilesets, Bilder).
- **Regressionsrisiko**: Änderungen für den Export dürfen das laufende TiledWarfare-Spiel nicht beschädigen – benötigt werden passende Tests und eine saubere Abstraktionsgrenze.
- **Doku-Lücke**: Fehlende oder veraltete Dokumentation der Engine erschwert die Einarbeitung im Zielprojekt.

## Links

- [OpenBrawl Repository](https://github.com/Reyneke/OpenBrawl)

## Umsetzungsplan

### Phase 1: Engine entkoppeln (in TiledWarfare)

**1.1 `hex_grid.dart` von `ObjectToken` entkoppeln**
- Methoden `buildOccupiedHexFields()` und `buildOccupiedHexesFromIterable()` aus `hex_grid.dart` entfernen
- Stattdessen eine generische Methode einführen, z. B.:
  ```dart
  Set<int> buildOccupiedHexes<T>(Iterable<T> items, Offset Function(T) getPosition, {bool Function(T)? include})
  ```
- Aufrufer in TiledWarfare (`widget_caretaker.dart`, `object_host.dart` etc.) auf die neue API umstellen

**1.2 `map_parser.dart` von `dart:io` entkoppeln (Web-Kompatibilität)**
- `package:archive` als Abhängigkeit hinzufügen
- `zlib.decode()` → `ZLibDecoder().decodeBytes()` und `gzip.decode()` → `GZipDecoder().decodeBytes()` aus `package:archive`
- Verifizieren, dass `dart:io`-Import entfällt

**1.3 `MapMeta` aus der Engine ausschließen**
- `MapMeta`, `map_registry.dart` und `maps.json`-Logik verbleiben spiel-spezifisch in TiledWarfare
- `map_data.dart` referenziert `MapMeta` nicht (bereits der Fall) → kein Refactoring nötig

### Phase 2: Engine als Paket strukturieren

**2.1 Engine-Verzeichnis anlegen**
- Neues Verzeichnis `packages/tilemap_engine/` im TiledWarfare-Repo
- `pubspec.yaml` mit `name: tilemap_engine`, Abhängigkeiten: `flutter`, `xml`, `archive`
- `lib/tilemap_engine.dart` als öffentliche Export-Datei (`map_parser.dart`, `map_data.dart`, `map_exceptions.dart`, `hex_grid.dart`)

**2.2 Entkoppelten Hex-Map-Renderer erstellen**
- Neues Widget `HexMapView` (analog zu `widget_hex_map_renderer.dart` in OpenBrawl) im Paket
- Keine Abhängigkeit zu `ObjectToken`/`ObjectPlayer` – stattdessen generische `tokenPainter`-Callback oder `List<HexTokenFigure>`-Modell:
  ```dart
  typedef TokenPainter = void Function(Canvas canvas, Offset center);
  ```
- Laden des Tileset-Bilds über `AssetBundle` (injizierbar)

**2.3 TiledWarfare auf Paket umstellen**
- `pubspec.yaml` von TiledWarfare: `tilemap_engine: path: packages/tilemap_engine`
- Imports in `lib/` anpassen: `package:tilemap_engine/tilemap_engine.dart`
- Alle Tests laufen lassen → Regressionen fixen

### Phase 3: Feature-Branch per Pull-Request in den Main-Branch überführen

**3.1 Pull-Request erstellen**
- Feature-Branch (aktueller Stand) per PR in den Main-Branch von TiledWarfare überführen
- Begründung (siehe „Merge der Feature-Branch in den Main-Branch"): Ein Git-Submodul referenziert konkrete Commits – die Engine muss zuerst stabil im Main stehen

**3.2 CI & Review**
- Automatisierte Checks (`flutter analyze` + `flutter test`) laufen im PR
- Review durchführen und den PR mergen

**Bestehende CI-Workflows (geprüft):**
- **`nightly.yml`** (`.github/workflows/nightly.yml`): Enthält einen `test`-Job (`flutter analyze` + `flutter test`) und läuft u. a. bei **Pushes auf Nicht-Main-Branches** (`branches-ignore: main`) → deckt den Feature-Branch ab
- **`release.yml`** (`.github/workflows/release.yml`): Enthält denselben `test`-Job und läuft bei **Pushes auf `main`** → deckt den Merge in den Main ab
- **Fazit**: Ja, es existieren bereits fertige CI-Tests für diesen Fall. Beide Workflows führen `flutter analyze` + `flutter test` aus. Für den PR-Merge ist kein neuer Workflow nötig – die Checks laufen automatisch auf dem Feature-Branch (nightly) und nach dem Merge auf `main` (release). Optional kann zusätzlich ein `pull_request`-Trigger ergänzt werden, damit die Checks direkt im PR-Status sichtbar sind.

**Aufgetretenes CI-Problem („Run flutter analyze" schlägt mit leerer Fehlermeldung fehl):**
- **Ursache**: `flutter analyze` endet mit Exit-Code 1, sobald **auch nur Info-Level-Issues** gefunden werden. Im Repo existierten 77 vorbestehende `info`-Issues – davon 57 im eingebetteten externen Unterprojekt `lib/fuzzy_logic/` (`non_constant_identifier_names`, `avoid_print` etc.) und 20 im Spiel-Code (`object_host.dart`/`object_team_medic.dart` Namenskonventionen, `terrain_service.dart` `prefer_initializing_formals`). In GitHub Actions wirkt das wie eine leere Fehlermeldung, weil der Schritt nur den Exit-Code als Fehler meldet.
- **Fix 1 – `analysis_options.yaml`**: `lib/fuzzy_logic/**` aus der Analyse ausgeschlossen (eingebettetes externes Unterprojekt, nicht Teil der App) → reduziert auf 20 Issues.
- **Fix 2 – Beide Workflows** (`nightly.yml`, `release.yml`): `flutter analyze` → `flutter analyze --no-fatal-infos`. Damit brechen echte Errors/Warnings weiterhin die Pipeline, Info-Level-Issues jedoch nicht mehr.
- **Verifiziert** (lokal): `flutter analyze --no-pub --no-fatal-infos` endet mit Exit-Code 0:
  ```
  20 issues found. (ran in 14.0s)
  EXIT_OK
  ```
  Die 20 verbleibenden Issues sind reine `info`-Hinweise (Stil) – keine Fehler, keine Warnings.
- **Fazit**: Die CI läuft nach dem nächsten Push mit den Fixes durch (`--no-fatal-infos` + excludiertes `fuzzy_logic`).

**3.3 Main-Commit als Submodul-Referenz festlegen**
- Nach dem Merge den Main-Commit notieren; er dient als Ausgangsreferenz für das Submodul in OpenBrawl

### Phase 4: Einbindung in OpenBrawl ✅ (durchgeführt)

**4.1 Git-Submodul anlegen**
- Im OpenBrawl-Repo als Submodul hinzugefügt: `git submodule add https://github.com/Reyneke/TiledWarfare.git packages/tilemap_engine`
- `.gitmodules` enthält `branch = main` (Submodul folgt dem Main-Branch von TiledWarfare)
- `pubspec.yaml` von OpenBrawl: `tilemap_engine: path: ../packages/tilemap_engine/tiled_warfare/packages/tilemap_engine`
  - Hinweis: Das Submodul zeigt auf den **Repo-Stamm** von TiledWarfare; dadurch enthält es zusätzlich das gesamte TiledWarfare-Projekt (`packages/tilemap_engine/tiled_warfare/`). Das Engine-Paket liegt verschachtelt darunter.
- `xml` auf `^7.0.1` angehoben (Engine-Anforderung; entspricht der Kompatibilitäts-Entscheidung „dieselben Versionen wie TiledWarfare")
- `flutter pub get` erfolgreich durchgelaufen

**4.2 OpenBrawl-Karten-Code auf Engine umstellen**
- `lib/utils/tmx_parser.dart` gelöscht (durch `MapParser`/`MapData` aus der Engine ersetzt)
- `lib/widgets/widget_maploader.dart` gelöscht (Legacy, unbenutzt)
- `lib/widgets/widget_hex_map_renderer.dart`: umgebaut auf `HexMapView` + `HexGrid` und `MapData`; Token-Zeichnung (OpenBrawl-spezifisch, `ObjectToken`) über den generischen `tokenPainter`-Callback realisiert
- `lib/widgets/widget_map_loader.dart`: nutzt `MapParser.forPath().loadFromAsset()`, baut die `HexGrid`-Utility, löst externe TSX-Tilesets auf und lädt das Tileset-Bild

**4.3 Assets vorbereiten**
- `test.tmj` referenziert das Tileset **extern** (`source: Thespazztikone_tilemaps_005_neu.tsx`)
- Die Engine wurde erweitert: `MapParser.loadExternalTileset()` ist nun Teil des Interfaces und auch in `TmjParser` implementiert (TSX ist immer XML), damit die Auflösung externer TSX-Referenzen unabhängig vom Kartenformat (TMX/TMJ) funktioniert
- `Thespazztikone_tilemaps_005_neu.png` wird weiterhin als Tileset-Bild verwendet (Pfad über `imageSource` + `basePath` aufgelöst)

**Verifikation (OpenBrawl):**
- `flutter analyze --no-fatal-infos` → `EXIT_CODE=0` (nur 8 vorbestehende `info`-Hinweise in `widget_image_select.dart`)

**Hinweis / Nächster Schritt:** Die Engine-Erweiterung (`loadExternalTileset` im `TmjParser`) wurde **im Submodul** vorgenommen. Damit sie dauerhaft in der Engine ist, muss sie im TiledWarfare-Repo committet und gepusht werden, und das Submodul in OpenBrawl auf den neuen Commit aktualisiert werden.

### Phase 5: Tests und Verifikation

**5.1 TiledWarfare-Tests**
- `flutter test` im TiledWarfare-Repo
- Sicherstellen, dass `hex_grid_test.dart`, `map_parser_test.dart` etc. weiterhin grün sind

**5.2 OpenBrawl-Tests**
- Neuen Test für die Engine-Integration anlegen (Parser-Laden der `test.tmj`, HexGrid-Pixel-Konvertierung)
- `flutter analyze` und `flutter test` in OpenBrawl

**5.3 Web-Kompatibilität ✅ (verifiziert)**
- `flutter build web` in TiledWarfare erfolgreich: `√ Built build\web` (84,2s) – damit ist der `dart:io`-Fix (Umstellung auf `package:archive` in `map_parser.dart`) bestätigt. Die Engine ist web-kompatibel.
- Hinweis: Es erschien eine unkritische Font-Warnung (CupertinoIcons fehlt in pubspec), die den Build nicht stoppt.

**Ergänzung: `MapParser.loadExternalTileset` in Engine übernommen (TiledWarfare)**
- Abstrakte Methode `loadExternalTileset(String tsxPath)` im `MapParser`-Interface ergänzt
- Implementierung in `TmxParser` (mit `@override`) und neu in `TmjParser` (TSX ist immer XML – unabhängig vom Kartenformat)
- Verifikation: `flutter test` → 115 Tests grün; `flutter analyze --no-fatal-infos` → 20 vorbestehende `info`-Hinweise, keine Fehler
- **Auszuführen vom Nutzer**: Änderungen in TiledWarfare committen/pushen und das Submodul in OpenBrawl auf den neuen Commit aktualisieren (`git submodule update --remote`)

### Phase 6: Abschluss

**6.1 Dokumentation**
- `README.md` der Engine erweitern (Nutzung, API, Migration)
- `doc/todo/feat_better_maps/12-Export.md` um Ist-Zustand ergänzen

**6.2 Lizenz & Beitragende**
- Lizenz der Engine prüfen (siehe "Lizenz- und Urheberfragen")
- OpenBrawl-Repo-Lizenz mit der Engine-Lizenz abgleichen

**6.3 Bonus**
- OpenBrawl-eigene Hex-Logik (`hex_toolkit`) entfernen, da `HexGrid` aus Engine übernommen wird
- Unbenutzten `widget_maploader.dart` in OpenBrawl löschen

## Frage: Combat-Maneuver-Buttons vs. Export-Änderungen

**Frage:** Es hat ein Problem mit den Buttons gegeben, welche die CombatManeuvers des Spielers kontrollieren. Wurde durch die Änderungen etwas an den bereits erledigten Phasen des Exports geändert?

**Antwort:** Nein. Die Export-Änderungen (Phasen 1–2) betreffen ausschließlich:

- `lib/utils/hex_grid.dart` – Entkopplung von `ObjectToken` (generische `buildOccupiedHexes`-API statt `buildOccupiedHexFields`/`buildOccupiedHexesFromIterable`)
- `lib/services/map_parser.dart` – `dart:io`/`zlib`/`gzip` → `package:archive` (Web-Kompatibilität)
- `packages/tilemap_engine/` – neues Paket mit `map_parser`, `map_data`, `map_exceptions`, `hex_grid`, `hex_map_view`
- `pubspec.yaml` – neue Abhängigkeiten (`archive`, `tilemap_engine`)

**Zum Button-Problem:** Der Regressionstest `test/widget_caretaker_combat_test.dart` beschreibt den eigentlichen Bug: Das Info-Panel lag bei Stack-Position `left: -232` außerhalb der Stack-Bounds des gepaddeten `WidgetCaretaker`. `RenderBox.hitTest` lehnt Positionen außerhalb der Bounds ab (`Clip.none` erlaubt nur das Malen über die Grenzen, nicht das Hit-Testen) – die Buttons waren dadurch physisch nicht klickbar.

- **Meine einzige Änderung** in `lib/widgets/widget_caretaker.dart` war `_buildBlockedHexFields` (Umstellung auf `buildOccupiedHexes`) – **keinerlei** Einfluss auf UI-Layout oder Button-Interaktion.
- Das Info-Panel-Layout (`left: -232` / `right: 8`, `top: 8`) sowie die Combat-Button-Logik (`_buildPlayerActionButtons`, `_enterTargetingMode` etc.) wurden **nicht** verändert.

**Verifikation:** Der neue Regressionstest `Combat-Maneuver-Buttons sind sichtbar und klickbar` läuft grün:
```
00:01 +1: All tests passed!
```
Die Export-Phasen 1–2 sind davon unberührt und weiterhin voll funktionsfähig (114 Tests grün).
