# Zwischenstand

> **Datum:** 13. August 2026
> **Kontext:** Sprint "Better Maps" – Stand der Umsetzung und verbleibende Punkte

Nachdem bereits eine Menge Veränderungen im Mapping vorgenommen wurden, ist es an der Zeit, einen Zwischenstand zu ziehen.

---

## Aktueller Stand

Wo sind wir gerade, was das Feature "Better Maps" angeht?

Das Feature "Better Maps" ist in seinen Kernbereichen weit fortgeschritten. Die ehemals rudimentäre Kartenverarbeitung (laut `0_aktueller_stand.md`) wurde durch eine modulare Architektur mit klaren Services, Modellen und Utilities abgelöst.

### Umgesetzte Module

| Modul | Beschreibung | Datei(en) |
|-------|--------------|-----------|
| **Zentrale Hex-Utility** | Alle Pixel↔Hex-Konvertierungen, Distanzen, Nachbarsuche, `hexKey`, `findPath` (A*). Entfernt die Duplizierung zwischen Loader und Caretaker. | `lib/utils/hex_grid.dart` |
| **Robustes Parsing** | TMX (CSV, Base64, Zlib, Gzip) + TMJ (JSON), Multi-Layer, Multi-Tileset, Objektgruppen mit Properties, Polygon-Geometrie | `lib/services/map_parser.dart` |
| **Datenmodell** | `MapData` kapselt Tiles, Layer, Tilesets, Objektgruppen. `LayerPurpose`-Enum, O(1)-Layer-Lookups, Serialisierung (`toJson`/`fromJson`), `equals`/`hashCode` | `lib/models/map_data.dart` |
| **Terrain-System** | 7 Geländetypen (`normal`, `ruin`, `forest`, `water`, `wall`, `openGround`, `swamp`), Bewegungskosten, Passierbarkeit, `reachableHexes()` (BFS) | `lib/services/terrain_service.dart` |
| **Fog of War** | Zwei Sichtbarkeitsebenen (`visible` + `revealed`), LoS-DDA, Terrain-Sichtblockade, Ghost-Darstellung, `ChangeNotifier`-Event, in UI + KI integriert | `lib/services/fog_of_war.dart` |
| **Kartenauswahl** | `maps.json` wird eingelesen, 2 Karten verfügbar, Vorschaubilder, Integration in `ScreenRestaurant` | `lib/services/map_registry.dart`, `assets/maps/maps.json` |
| **Fehlerbehandlung** | `MapException`-Hierarchie, spezifische Catch-Blöcke (kein `catch (_)` mehr im Parser/Start-Screen) | `lib/services/map_exceptions.dart` |
| **Rendering** | Viewport-Culling, `RepaintBoundary`, hexagonales Tile-Clipping, respektierte Layer-Sichtbarkeit (`respectLayerVisibility`), Tiefenvergleich in `shouldRepaint()` | `lib/widgets/widget_map_loader.dart` |
| **KI/ObjectHost** | Hex-Distanz statt Pixel-Distanz, `late final HexGrid`, gekapselter `collisionSet`, A*-Pfadfindung um Mauern, TerrainService integriert | `lib/objects/object_host.dart` |
| **Laufzeit-Validierung** | `ground`-Layer + Spawn-Gruppe werden nach dem Laden validiert (sonst `MapParseException`) | `lib/widgets/widget_map_loader.dart` |
| **LRU-Cache Tileset-Bilder** | `LinkedHashMap` mit max. 5 Einträgen, älteste Einträge werden automatisch disposed | `lib/widgets/widget_map_loader.dart` |
| **Vorschaubilder** | `preview.png` (256×256) für `map0` + `map1`, generiert per Skript aus den Tileset-Assets | `assets/maps/map0/preview.png`, `assets/maps/map1/preview.png`, `scripts/generate_previews.py` |

### Daten & Karten

- **2 Karten** in `assets/maps/maps.json`: `map0` ("Street Battle") und `map1` ("Street Battle - Colliders")
- Beide nutzen dasselbe Tileset (`Thespazztikone_tilemaps_005_neu`)
- `map0` = offene Arena, `map1` = Mauer-Labyrinth (bewusster Gameplay-Unterschied)
- Beide Karten haben jetzt ein Vorschaubild (`previewPath` gesetzt)

### Bereits behobene Punkte aus der Bestandsanalyse

Die in `9-bestandsanalyse.md` identifizierten kritischen Bugs und Code-Qualitäts-Probleme wurden zwischenzeitlich angegangen:

- ✅ **Bug 1 (`_parseExternalTileset`):** Die Methode existiert nicht mehr. Stattdessen `loadExternalTileset()` (async) + `_parseTilesetElementFromXml()` mit korrektem `firstGid`-Parameter.
- ✅ **Bug 2 (`firstGid` hartcodiert):** `_parseTilesetElementFromXml` akzeptiert nun `firstGid`.
- ✅ **Bug 3 (`catch (_)` in `screen_start.dart`):** Durch `on FileSystemException` / `on FormatException` ersetzt.
- ✅ **Problem 1 (Pixel→Hex-Distanz):** `ObjectHost` nutzt `hexGrid.distance()`.
- ✅ **Problem 2 (`_hexGrid!` Null-Assertion):** `late final HexGrid hexGrid`.
- ✅ **Problem 3 (`collisionSet` public):** Privates Feld mit Getter/Setter.
- ✅ **Problem 4 (`_tilesetLookup` redundant):** Entfernt – nutzt direkt `tilesetImages`.
- ✅ **Problem 5 (Layer-`visible` ignoriert):** `MapLoadConfig.respectLayerVisibility` (Default: `true`).
- ✅ **`TerrainType.fromString` Plural:** `ruin`/`ruins` und `wall`/`walls` werden erkannt.
- ✅ **Polygon-Geometrie:** `<polygon>` und TMJ-`polygon` werden in `parseTerrain()` unterstützt.
- ✅ **Weißer Balken (Hauptursache):** `sqrt()` in der `boundaryMargin`-Berechnung korrigiert; Karte wird bei Fenstergrößenänderung neu zentriert.

### Tests

- `test/hex_grid_test.dart` – Pixel↔Hex, hexKey, Distanz, A*, Nachbarsuche, etc.
- `test/map_parser_test.dart` – TMX (CSV/Base64+Zlib), TMJ, Objektgruppen, Properties, Flip-Bits, Fehlerfälle
- `test/terrain_service_test.dart` – `configAt`, `isPassable`, `reachableHexes`, `effectiveMovementRange`, `parseTerrain`
- `test/fog_of_war_test.dart` – Sichtbarkeit, LoS, Performance, Edge Cases
- `test/widget_map_loader_test.dart` – Rendering mit echten Assets, Fehler-UI, **Fenstergrößen-Änderung (weißer Balken)**
- `test/game_flow_test.dart` – Integration: Karte laden, Terrain, Zombie-Bewegung (A*)

> **Stand:** `flutter analyze` 0 Fehler/0 Warnungen; `flutter test` **100/100 grün**. CI führt Tests in `nightly.yml` und `release.yml` aus.

---

## Probleme

Welche bekannten Probleme gibt es beim Import und der Verarbeitung von Tilemaps aktuell?

### 🟡 1. Weißer Balken am Fensterrand (Layout)

**Status:** Teilweise behoben

Die Hauptursache (fehlerhafte `boundaryMargin`-Berechnung – fehlendes `sqrt()`) wurde beseitigt. Der weiße Rahmen tritt bei direkter Fenstergrößenänderung nicht mehr auf. Er kann jedoch weiterhin auftreten, wenn die Fenstergröße unten/rechts verändert, der Rahmen über die Map gezogen und die Karte dann hin- und herbewegt wird. Der Rahmen verschwindet, sobald die Fenstergröße erneut geändert wird.

**Maßnahmen:** Automatisierte Widget-Tests wurden ergänzt (`test/widget_map_loader_test.dart`), die Fenstergrößen-Änderungen zur Laufzeit simulieren. Diese prüfen:
- Das `SizedBox`-Child hat die korrekte Karten-Pixelgröße (30×30 Tiles à 32px)
- Der `InteractiveViewer` ist korrekt konfiguriert (`constrained: false`, `boundaryMargin: EdgeInsets.zero`)
- Die Karte bleibt nach mehrfachen Größenänderungen gerendert (kein Fehler, `CustomPaint` vorhanden)

### ✅ 2. Kein Event/Callback bei Sichtbarkeitsänderung (Fog of War)

**Status:** Behoben

`FogOfWarService` ist ein `ChangeNotifier` mit `visibilityVersion`-Zähler. `_WidgetMapLoaderState` lauscht via `addListener(_onFogOfWarChanged)` und löst `setState` aus. `_HexMapPainter` vergleicht die eingefrorene `_fogVisibilityVersion` in `shouldRepaint()`. Die Karte wird also automatisch neu gezeichnet, sobald sich die Sichtbarkeit ändert. Details: `10-fog-of-war.md`, Problem 4.

### ✅ 3. Laufzeit-Validierung der Karte

**Status:** Behoben

`_loadMap()` validiert jetzt nach dem Parsen:
- `ground`-Layer muss existieren (war bereits implementiert)
- Spawn-Gruppe (`config.spawnGroupName`) muss mindestens 1 Objekt enthalten (**neu ergänzt**)

Fehlt einer der beiden Punkte → `MapParseException` mit klarer Fehlermeldung.

### ✅ 4. Vorschaubilder in `maps.json`

**Status:** Behoben

Neue Vorschaubilder `assets/maps/map0/preview.png` und `assets/maps/map1/preview.png` (256×256) wurden per Skript (`scripts/generate_previews.py`) aus den Tileset-Assets generiert. `previewPath` ist in `maps.json` für beide Karten gesetzt.

### ✅ 5. Performance-Tests in CI

**Status:** Behoben

Beide CI-Workflows (`nightly.yml` + `release.yml`) haben jetzt einen `test`-Job mit `flutter analyze` und `flutter test` (inkl. Performance-Benchmarks). Im Nightly-Workflow sind die Build-Jobs vom Test-Job abhängig; im Release-Workflow ist der Test-Job ein Quality Gate (`needs: test`).

---

## Verbesserungen

Welche Verbesserungen können wir noch vornehmen?

### 1. Laufzeit-Validierung der Karte

**Status:** ✅ Umgesetzt (ground-Layer + Spawn-Gruppe)

Nach dem Parsen wird geprüft, ob der `ground`-Layer existiert und ob die Spawn-Gruppe mindestens ein Objekt enthält. Fehlt einer der beiden Punkte → `MapParseException`.

### 2. LRU-Cache für Tileset-Bilder

**Status:** ✅ Bereits umgesetzt

`kMaxTilesetImages = 5` + `LinkedHashMap` mit `_putTilesetImage()`: älteste Einträge werden automatisch disposed, wenn das Limit überschritten wird.

### 3. Vorschaubilder für Karten

**Status:** ✅ Umgesetzt

`preview.png` für `map0` + `map1` generiert und in `maps.json` eingetragen. Das Skript liegt unter `scripts/generate_previews.py`.

### 4. Fog-of-War-Event sauber verdrahten

**Status:** ✅ Bereits umgesetzt + dokumentiert

`ChangeNotifier` + `visibilityVersion` + `_onFogOfWarChanged`-Listener + `shouldRepaint`-Vergleich. In `10-fog-of-war.md` dokumentiert (Problem 4 + Erweiterung 8).

### 5. Weißer-Balken-Bug systematisch angehen

**Status:** ✅ In Arbeit

Automatisierte Widget-Tests simulieren die Fenstergrößen-Änderung zur Laufzeit (`tester.view.physicalSize`). Zusätzlich sollte `didChangeMetrics()` in `screen_main.dart` genauer geprüft werden, falls das Teilproblem weiterhin auftritt.

### 6. TerrainService-Integration in ObjectHost ausbauen

**Status:** ✅ Bereits umgesetzt

`ObjectHost` hat ein `terrainService`-Feld mit `setTerrainService()` und nutzt `costFn` für Bewegungskosten und unpassierbares Gelände bei der Zombie-Bewegung.

### 7. Performance-Tests in die CI aufnehmen

**Status:** ✅ Umgesetzt

`test`-Job mit `flutter analyze` + `flutter test` in `nightly.yml` und `release.yml` ergänzt.

## 8. Neue Objektebene "Sektoren"

**Status:** ✅ Umgesetzt

Die neue Objektebene **"Sektoren"** wurde in das Projekt eingebunden, analog zu den anderen Objektebenen (`Spawns`, `Gelaendetypen`):

- **Neues Datenmodell:** `lib/models/sector.dart` – `Sector` mit Name, Geometrie (Rechteck/Polygon/Punkt), Properties, `containsPixel()` (Ray-Casting für Polygone) und `containsHex()`.
- **Service:** `lib/services/sector_service.dart` – `parseSectors()` + `findSectorGroup()` (analog zu `parseTerrain()`).
- **Parser-Anbindung:** `WidgetMapLoader.onSectorsParsed` wird nach dem Laden der Karte aufgerufen (analog zu `onTerrainParsed`/`onSpawnPointsParsed`).
- **Screen-Anbindung:** `ScreenMain` hält die Sektoren im State und reicht sie an `WidgetCaretaker` weiter (`sectors`-Feld).
- **Tests:** `test/sector_service_test.dart` – 13 neue Tests (containsPixel, containsHex, parseSectors, findSectorGroup, Integration mit echten Karten `map0` + `map1`).
- **Stand:** `flutter analyze` 0 Fehler/0 neue Warnungen; `flutter test` **113/113 grün**.

---

## Zusammenfassung

| Bereich | Status |
|---------|--------|
| Zentrale Hex-Utility (inkl. A*) | ✅ Implementiert |
| Robustes Parsing (TMX + TMJ) | ✅ Implementiert |
| Datenmodell + Layer-System | ✅ Implementiert |
| Terrain-System | ✅ Implementiert |
| Fog of War (inkl. Event) | ✅ Implementiert |
| Kartenauswahl (inkl. Vorschau) | ✅ Implementiert |
| Fehlerbehandlung | ✅ Implementiert |
| Rendering/Performance | ✅ Implementiert |
| KI (Hex-Distanz, A*, Terrain) | ✅ Implementiert |
| Laufzeit-Validierung (ground + Spawns) | ✅ Implementiert |
| LRU-Cache Tileset-Bilder | ✅ Implementiert |
| Vorschaubilder | ✅ Implementiert |
| CI-Tests (nightly + release) | ✅ Implementiert |
| Weißer-Balken-Widget-Tests | ✅ Implementiert |
| Weißer Balken (Live-Verhalten) | 🟡 Teilweise gelöst (Tests vorhanden) |