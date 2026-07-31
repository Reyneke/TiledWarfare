# Bestandsanalyse

> **Datum:** 31. Juli 2026
> **Kontext:** Sprint "Better Maps" – Stand nach Umsetzung der Features 1–8

---

## 1. Dokumentation – Ist die Dokumentation auf dem Laufenden?

### ✅ `doc/doc/` – Vollständig aktualisiert

| Dokument | Status | Anmerkungen |
|----------|--------|-------------|
| `00_project_overview.md` | ✅ Aktuell | Deckt HexGrid, TerrainService, FogOfWar, MapRegistry, LayerPurpose ab |
| `01_class_diagram.md` | ✅ Aktuell | Enthält alle neuen Klassen (HexGrid, TerrainService, FogOfWarService, MapRegistry, LayerPurpose, MapMeta) |
| `03_dependency_graph.md` | ✅ Aktuell | Alle neuen Abhängigkeiten eingetragen |
| `04_cliffnotes.md` | ✅ Aktuell | Kurzüberblick über alle neuen Features |
| `05_new_employee_guide.md` | ✅ Aktuell | Schritt-für-Schritt-Einstieg inkl. neuer Architektur |
| `06_map_loader.md` | ✅ Aktuell | Umfassender Mapper-Guide mit Layer-System, Terrain, Tilesets |

### ✅ `doc/todo/feat_better_maps/` – Planungsdokumente

| Dokument | Status | Anmerkungen |
|----------|--------|-------------|
| `0_aktueller_stand.md` | ✅ Grundlage | Beschreibt den Ist-Zustand vor den Änderungen |
| `1_Zentralisierte_hex_utility.md` | ✅ Umgesetzt | `HexGrid` in `lib/utils/hex_grid.dart` |
| `2_robusteres_tmx_parsing.md` | ✅ Umgesetzt | `TmxParser` + `TmjParser` in `lib/services/map_parser.dart` |
| `3_terrain_system.md` | ✅ Umgesetzt | `TerrainService`, `FogOfWarService`, `TerrainType`, `TerrainConfig` |
| `4_Kartenauswahl.md` | ✅ Umgesetzt | `MapRegistry`, `MapMeta`, Integration in `ScreenRestaurant` |
| `5_performance.md` | ✅ Umgesetzt | Viewport-Culling, RepaintBoundary, clipRect, shouldRepaint-Tiefenvergleich |
| `6_fehlerbehandlung.md` | ✅ Umgesetzt | `MapException`-Hierarchie, spezifische Catch-Blöcke |
| `7_datenmodell.md` | ✅ Umgesetzt | Serialisierung, GZIP, equals/hashCode, BFS-Duplizierung entfernt |
| `8_tile_layer_system.md` | ✅ Umgesetzt | `LayerPurpose`-Enum, O(1)-Layer-Lookups |

### ⚠️ Kleine Lücken in der Dokumentation

1. **`doc/doc/01_class_diagram.md`** – Zeigt `_HexUtils` noch als Hilfsklasse (Zeile 204), obwohl diese durch `HexGrid` ersetzt wurde.
2. **`doc/doc/04_cliffnotes.md`** – Zeile 145: Der Debug-Tipp verweist noch auf `assets/maps/street_battle.tmx` als Default, aber der Pfad wird jetzt dynamisch aus `maps.json` geladen.
3. **`doc/doc/05_new_employee_guide.md`** – Zeile 268: FAQ verweist noch auf `assets/maps/street_battle.tmx` als einzige Karte.

---

## 2. Aktueller Stand – Probleme, Risiken, Lücken im Code

### 2.1 ✅ Bereits behoben (im Sprint "Better Maps")

| Feature | Status | Enthalten in |
|---------|--------|-------------|
| Zentrale Hex-Utility (`HexGrid`) | ✅ | `lib/utils/hex_grid.dart` |
| TMX-Parsing (CSV, Base64, Zlib, Gzip) | ✅ | `lib/services/map_parser.dart` |
| TMJ-Parsing (JSON-Format) | ✅ | `lib/services/map_parser.dart` |
| Multi-Layer-System (LayerPurpose) | ✅ | `lib/models/map_data.dart` |
| Multi-Tileset-Support | ✅ | `lib/widgets/widget_map_loader.dart` |
| Viewport-Culling | ✅ | `_HexMapPainter` in `widget_map_loader.dart` |
| RepaintBoundary | ✅ | `widget_map_loader.dart` |
| Spezifische Exceptions | ✅ | `lib/services/map_exceptions.dart` |
| Terrain-System (7 Typen) | ✅ | `lib/services/terrain_service.dart` |
| Fog of War (visible + revealed) | ✅ | `lib/services/fog_of_war.dart` |
| Kartenauswahl (maps.json) | ✅ | `lib/services/map_registry.dart` |
| O(1)-Layer-Lookups | ✅ | `MapData._layerIndexByName` |
| Serialisierung (toJson/fromJson) | ✅ | Alle Modelle in `map_data.dart` |
| equals/hashCode | ✅ | `ObjectGroup`, `MapObject`, `MapMeta` |
| BFS-Duplizierung entfernt | ✅ | `TerrainService.reachableHexes()` |
| GZIP-Unterstützung | ✅ | `TmxParser._parseBase64()` |

### 2.2 ❌ Noch offene Bugs

#### Bug 1: `_parseExternalTileset` – Sync-Cast auf async-Operation
**Datei:** `lib/services/map_parser.dart`, Zeile 192–199
**Problem:** Die Methode `_parseExternalTileset()` wird im synchronen `parse()`-Flow aufgerufen, aber externe TSX-Dateien können nur async geladen werden. Aktuell wird nur die `source`-Referenz gespeichert – die tatsächlichen Bild-Metadaten fehlen.
**Risiko:** Wenn eine TMX-Datei externe TSX-Tilesets verwendet, werden die Tileset-Bilder nicht geladen (die async `loadExternalTileset()`-Methode existiert, wird aber nicht im normalen Flow aufgerufen).
**Workaround:** Aktuell werden nur inline-Tilesets verwendet (die TMX hat das Tileset eingebettet).

#### Bug 2: `_parseTilesetElementFromXml` – Hardcodiertes `firstGid: 1`
**Datei:** `lib/services/map_parser.dart`, Zeile 217
**Problem:** `firstGid: 1` ist hartcodiert, obwohl der korrekte Wert vom Aufrufer stammen müsste.
**Risiko:** Wenn `loadExternalTileset()` jemals im normalen Flow aufgerufen wird, haben alle Tilesets `firstGid=1`, was zu falschem Tileset-Mapping führt.

#### Bug 3: `screen_start.dart` – Letzter `catch (_)` im Projekt
**Datei:** `lib/screens/screen_start.dart`, Zeile 193
**Problem:** Einziger verbliebener Catch-All-Block. Verschluckt `FileSystemException` und `FormatException`.
**Risiko:** Fehler beim Bild-Laden werden nicht korrekt kommuniziert.

### 2.3 ⚠️ Code-Qualitäts-Probleme

#### Problem 1: `ObjectHost` verwendet Pixel-Distanz statt Hex-Distanz
**Datei:** `lib/objects/object_host.dart`
**Stellen:**
- Zeile 285: `(zombie.position - target.position).distance` (in `_moveZombieTowardsTarget`)
- Zeile 416: `(zombie.position - target.position).distance` (in `performHostFocusFire`)
- Zeile 526: `(zombie.position - cook.position).distance` (in `performAllZombieAttacks`)

**Problem:** Die Pixel-Distanz wird für Reichweiten-Prüfungen verwendet, obwohl die Hex-Distanz (`hexGrid.distance()`) korrekt wäre. Bei unterschiedlichen Zoom-Stufen oder ungeraden Zeilen kann die Pixel-Distanz von der tatsächlichen Hex-Entfernung abweichen.
**Risiko:** Niedrig, da `rangeValue` meist 0 (Nahkampf) ist und die Pixel-Distanz für benachbarte Felder ähnlich ist. Aber bei `rangeValue > 0` könnte ein Zombie fälschlich außerhalb der Reichweite liegen.

#### Problem 2: `ObjectHost._hexGrid!` – Null-Assertion
**Datei:** `lib/objects/object_host.dart`
**Problem:** `_hexGrid` ist `HexGrid?` (nullable), wird aber überall mit `!` asserted. Wenn `setHexGrid()` nicht vor dem ersten Zugriff aufgerufen wird, gibt es eine Runtime-Null-Exception.
**Risiko:** Mittel – der Flow stellt sicher, dass `ScreenMain` vor dem Spiel `setHexGrid()` aufruft, aber bei Refactoring könnte diese Abhängigkeit übersehen werden.

#### Problem 3: `ObjectHost.collisionSet` – Public mutable field
**Datei:** `lib/objects/object_host.dart`, Zeile 164
**Problem:** `Set<int> collisionSet = {}` ist public und mutable. Jeder Code kann es verändern, ohne dass der Host davon weiß.
**Risiko:** Niedrig (wird nur von `ScreenMain` gesetzt), aber ein Anti-Pattern.

#### Problem 4: `_tilesetLookup` in `_HexMapPainter` – Identisch mit `tilesetImages`
**Datei:** `lib/widgets/widget_map_loader.dart`, Zeile 502
**Problem:** `_tilesetLookup` ist eine exakte Kopie von `tilesetImages` (beide sind `Map<int, ({ui.Image image, int columns})>`). Die Zuweisung `_tilesetLookup = tilesetImages` im Konstruktor (Zeile 514) erzeugt nur eine weitere Referenz auf dasselbe Objekt.
**Risiko:** Kein funktionaler Bug, aber unnötige Code-Komplexität und Speicher-Overhead (eine Referenz mehr).

#### Problem 5: `_getVisibleLayers()` ignoriert `visible`-Flag
**Datei:** `lib/widgets/widget_map_loader.dart`, Zeile 536–548
**Problem:** Der Kommentar sagt: "Die `visible`-Eigenschaft wird ignoriert, da Tiled-Layer als unsichtbar markiert sein können, aber dennoch gezeichnet werden sollen." Das ist ein Design-Entscheid, der aber nirgends dokumentiert ist. Wenn ein Mapper einen Layer in Tiled unsichtbar macht, wird er trotzdem im Spiel angezeigt.
**Risiko:** Niedrig (Mapper müssen wissen, dass `visible` in Tiled ignoriert wird), aber könnte zu Verwirrung führen.

### 2.4 🔮 Fehlende Features / Verbesserungspotenzial

#### Feature 1: Kein LRU-Cache für Tileset-Bilder
**Problem:** Beim Kartenwechsel werden alle Tileset-Bilder disposet und neu geladen. Wenn der Spieler häufig zwischen Karten wechselt, führt das zu wiederholten Ladevorgängen.
**Vorschlag:** Einen LRU-Cache mit max. 3–5 Einträgen einführen.

#### Feature 2: Keine Laufzeit-Validierung der Karte
**Problem:** Es gibt keine Prüfung, ob die geladene Karte tatsächlich alle erforderlichen Layer hat (z. B. `ground`). Fehlende Layer führen zu leeren Karten ohne Fehlermeldung.
**Vorschlag:** Nach dem Parsen prüfen, ob `ground`-Layer existiert. Optional: `collision`-Layer, `Spawns`-Objektgruppe.

#### Feature 3: Keine Vorschaubilder in `maps.json`
**Problem:** Beide Karteneinträge in `maps.json` haben `"previewPath": null`. Die Kartenauswahl zeigt nur ein Icon.
**Vorschlag:** Vorschaubilder für `map0` und `map1` erstellen und in `maps.json` eintragen.

#### Feature 4: `ObjectHost` verwendet keine `TerrainService`-Integration
**Problem:** Der Host hat `collisionSet`, aber nutzt nicht den `TerrainService` für Bewegungskosten oder Passierbarkeit. Zombies ignorieren Geländetypen (Wald, Sumpf, etc.).
**Vorschlag:** `TerrainService` in `ObjectHost` integrieren, sodass Zombies Geländekosten berücksichtigen.

#### Feature 5: Keine Pfadfindung (A*/Dijkstra) für KI
**Problem:** Die Zombie-Bewegung ist gradlinig (wähle Nachbarn mit geringster Distanz zum Ziel). Das funktioniert bei Hindernissen nicht – Zombies bleiben an Wänden hängen.
**Vorschlag:** A*-Pfadfindung für Zombies implementieren, die Kollisions-Tiles und Geländekosten berücksichtigt.

### 2.5 📊 Statistische Übersicht

| Metrik | Wert |
|--------|------|
| **Gesamtzeilen Code (lib/)** | ~4.500 Zeilen (geschätzt) |
| **Größte Datei** | `widget_caretaker.dart` (~1.857 Zeilen) |
| **Services** | 5 (`map_parser`, `terrain_service`, `fog_of_war`, `map_registry`, `map_exceptions`) |
| **Modelle** | 10+ Klassen/Enums in `map_data.dart` |
| **Parser-Formate** | TMX (XML) + TMJ (JSON) |
| **Karten** | 2 (`map0`, `map1`) |
| **Geländetypen** | 7 (`normal`, `ruin`, `forest`, `water`, `wall`, `openGround`, `swamp`) |
| **Offene Bugs** | 3 (siehe 2.2) |
| **Code-Qualitäts-Probleme** | 5 (siehe 2.3) |
| **Fehlende Features** | 5 (siehe 2.4) |

---

## 3. Tests – Aktuelle Abdeckung und Lücken

### 3.1 ✅ Vorhandene Tests

| Test-Datei | Umfang | Getestete Komponenten |
|------------|--------|----------------------|
| `test/fog_of_war_test.dart` | 284 Zeilen, 14 Tests | `FogOfWarService`: Basis-Tests, Sichtbarkeit, Sichtbarrieren, getVisibleEnemies, Edge Cases |
| `lib/fuzzy_logic/test/` | (vorhanden) | Fuzzy Logic Bibliothek |

### 3.2 ❌ Fehlende Tests (kritisch)

| Komponente | Priorität | Begründung |
|------------|-----------|------------|
| **`HexGrid`** | 🔴 Hoch | Kern-Komponente für alle Hex-Berechnungen. Fehler in `hexToPixel`, `pixelToHex`, `distance`, `hexKey` wirken sich auf das gesamte Spiel aus. |
| **`TmxParser`** | 🔴 Hoch | Parst alle TMX-Dateien. Fehler führen zu nicht ladbaren Karten. |
| **`TmjParser`** | 🔴 Hoch | Parst alle TMJ-Dateien. Fehler führen zu nicht ladbaren Karten. |
| **`TerrainService`** | 🔴 Hoch | Bewegungskosten-BFS, Passierbarkeit, `reachableHexes()`. Fehler führen zu falscher Bewegung. |
| **`MapRegistry`** | 🟡 Mittel | Lädt `maps.json`. Fehler führen zu fehlender Kartenauswahl. |
| **`MapData` Serialisierung** | 🟡 Mittel | `toJson()`/`fromJson()` für alle Modelle. Fehler führen zu Datenverlust beim Speichern. |

### 3.3 ❌ Fehlende Tests (wünschenswert)

| Komponente | Priorität | Begründung |
|------------|-----------|------------|
| **`WidgetMapLoader`** | 🟡 Mittel | Integrationstest: TMX laden → MapData → Painter. Fehler führen zu leeren Karten. |
| **`ObjectHost` KI** | 🟡 Mittel | Zombie-Bewegung, FocusFire, Spawning. Fehler führen zu falschem KI-Verhalten. |
| **`ObjectPlayer` Kampf** | 🟡 Mittel | `performAction()`, Initiative, Schadensberechnung. Fehler führen zu falschen Kampfergebnissen. |
| **`WidgetCaretaker`** | 🟢 Niedrig | Integrationstest: Runden, Token-Bewegung, Snap-to-Grid. Sehr aufwändig zu testen. |

### 3.4 📋 Vorschlag für Test-Priorität

```dart
// 1. HexGrid-Tests (höchste Priorität)
group('HexGrid', () {
  test('hexToPixel and pixelToHex are inverses', () { ... });
  test('distance uses cube coordinates (not Manhattan)', () { ... });
  test('hexKey is unique within map bounds', () { ... });
  test('neighborOffsets returns 6 neighbors', () { ... });
  test('isInBounds clamps correctly', () { ... });
  test('findFreeHexNear finds free hex', () { ... });
  test('buildOccupiedHexFields builds correct set', () { ... });
});

// 2. Parser-Tests (höchste Priorität)
group('TmxParser', () {
  test('parses CSV-encoded layer', () { ... });
  test('parses Base64-encoded layer', () { ... });
  test('parses Base64+Zlib compressed layer', () { ... });
  test('parses multiple layers', () { ... });
  test('parses multiple tilesets', () { ... });
  test('parses object groups with properties', () { ... });
  test('throws MapParseException on invalid data', () { ... });
});

group('TmjParser', () {
  test('parses JSON map format', () { ... });
  test('parses object groups with typed properties', () { ... });
});

// 3. TerrainService-Tests (höchste Priorität)
group('TerrainService', () {
  test('configAt returns correct config for terrain type', () { ... });
  test('isPassable checks collision, occupied, and impassable', () { ... });
  test('reachableHexes respects movement cost multipliers', () { ... });
  test('reachableHexes stops at impassable terrain', () { ... });
  test('effectiveMovementRange returns correct count', () { ... });
});
```

### 3.5 🧪 Laufzeittests (Integration)

**Anforderung aus der Aufgabenstellung:** "Wir benötigen Laufzeittests, beispielsweise, um zu prüfen, ob alle graphischen Elemente korrekt miteinander interagieren."

**Möglichkeiten:**

1. **Widget-Tests mit `flutter_test`:** 
   - `WidgetMapLoader` mit einer Test-TMX-Datei laden
   - Prüfen, ob `CustomPaint` gerendert wird
   - Prüfen, ob Callbacks ausgelöst werden

2. **Golden Tests (Screenshot-Vergleich):**
   - Karte rendern und mit einem Referenz-Screenshot vergleichen
   - Erkennt visuelle Regressionen (falsche Tile-Positionen, fehlende Layer)

3. **Integrationstests mit `integration_test`:**
   - Kompletten Spielfluss testen: Karte laden → Tokens spawnen → Bewegung → Kampf
   - Sehr aufwändig, aber deckt die meisten Fehler ab

4. **Empfehlung:** Zuerst Unit-Tests für `HexGrid`, `TmxParser`, `TmjParser` und `TerrainService` schreiben (sind isoliert testbar und decken die kritischsten Komponenten ab). Danach Widget-Tests für `WidgetMapLoader` (prüft, ob die Karte korrekt gerendert wird).

---

## 4. Zusammenfassung & Nächste Schritte

### Kritische ToDos (vor dem nächsten Sprint)

- [ ] **Bug 1 fixen:** `_parseExternalTileset` async machen oder entfernen
- [ ] **Bug 2 fixen:** `firstGid` in `_parseTilesetElementFromXml` korrekt setzen
- [ ] **Bug 3 fixen:** `screen_start.dart` `catch (_)` durch spezifische Exceptions ersetzen
- [ ] **HexGrid-Tests schreiben** (höchste Priorität)
- [ ] **Parser-Tests schreiben** (TMX + TMJ)
- [ ] **TerrainService-Tests schreiben**

### Wichtige Verbesserungen (nächster Sprint)

- [ ] `ObjectHost`: Pixel-Distanz durch Hex-Distanz ersetzen (3 Stellen)
- [ ] `ObjectHost`: `_hexGrid!` durch defensive Prüfung ersetzen
- [ ] `ObjectHost`: `collisionSet` kapseln (private + Setter)
- [ ] `_tilesetLookup` in `_HexMapPainter` entfernen (unnötige Duplizierung)
- [ ] A*-Pfadfindung für Zombies (statt gradliniger Bewegung)
- [ ] `TerrainService` in `ObjectHost` integrieren
- [ ] Vorschaubilder für Karten erstellen

### Langfristige Ziele

- [ ] Laufzeittests (Widget-Tests + Golden Tests)
- [ ] LRU-Cache für Tileset-Bilder
- [ ] Laufzeit-Validierung der Karte nach dem Laden
- [ ] Integrationstests für den kompletten Spielfluss

## 5. Offene Fragen

Nach der Analyse bleiben folgende Fragen offen, die vor dem nächsten Sprint geklärt werden sollten:

### 5.1 Design-Entscheidungen

| # | Frage | Kontext | Optionen |
|---|-------|---------|----------|
| 1 | **Soll `_parseExternalTileset` async werden oder entfernt?** | Bug 1: Die Methode speichert nur die `source`-Referenz, lädt aber keine Bild-Metadaten. Die async `loadExternalTileset()` existiert parallel. | (a) `_parseExternalTileset` async machen und in den `loadFromAsset()`-Flow integrieren. (b) Die Methode entfernen und nur `loadExternalTileset()` verwenden. (c) So lassen – Workaround: nur inline-Tilesets verwenden. | => a
| 2 | **Soll das `visible`-Flag von Tiled-Layern respektiert werden?** | `_getVisibleLayers()` ignoriert `layer.visible` – unsichtbare Layer in Tiled werden trotzdem gezeichnet. | (a) Ignorieren (aktuelles Verhalten) – Mapper müssen wissen, dass `visible` in Tiled ignoriert wird. (b) Respektieren – unsichtbare Layer nicht zeichnen. (c) Konfigurierbar via `MapLoadConfig`. | => Siehe 5.1.2 für eine konkrete Lösungsskizze zu (c) |

**👉 Konkrete Lösungsskizze für Option (c) – Konfigurierbar via `MapLoadConfig`:**

```dart
// In MapLoadConfig (lib/widgets/widget_map_loader.dart):
class MapLoadConfig {
  /// Steuert, ob das `visible`-Flag von Tiled-Layern respektiert wird.
  ///
  /// - `true` (Default): Layer mit `visible = false` in Tiled werden nicht
  ///   gezeichnet. Mapper können Layer gezielt ausblenden.
  /// - `false`: Das `visible`-Flag wird ignoriert – alle Layer werden
  ///   gezeichnet, unabhängig vom Tiled-Status. Nützlich, wenn Layer zur
  ///   Laufzeit dynamisch ein-/ausgeblendet werden sollen.
  final bool respectLayerVisibility;

  const MapLoadConfig({
    this.spawnGroupName = 'Spawns',
    this.respectLayerVisibility = true, // Default: respektieren
    this.layerNameOverrides = const {},
  });
}

// In _getVisibleLayers() (lib/widgets/widget_map_loader.dart):
Iterable<TileLayer> _getVisibleLayers() sync* {
  final ground = _layerByPurpose(LayerPurpose.ground);
  if (ground != null && _isLayerVisible(ground)) yield ground;

  final decor = _layerByPurpose(LayerPurpose.decorative);
  if (decor != null && _isLayerVisible(decor)) yield decor;

  final decorUpper = _layerByPurpose(LayerPurpose.decorativeUpper);
  if (decorUpper != null && _isLayerVisible(decorUpper)) yield decorUpper;
}

/// Prüft, ob ein Layer gezeichnet werden soll.
/// Berücksichtigt die [respectLayerVisibility]-Konfiguration.
bool _isLayerVisible(TileLayer layer) {
  if (!config.respectLayerVisibility) return true; // Ignorieren
  return layer.visible; // Respektieren
}
```

**Vorteile dieser Lösung:**
- **Rückwärtskompatibel**: `respectLayerVisibility = true` ist der Default – bestehende Karten verhalten sich wie erwartet (unsichtbare Layer werden nicht gezeichnet).
- **Flexibel**: Wer das alte Verhalten braucht (alle Layer zeichnen), setzt `respectLayerVisibility = false`.
- **Einfach**: Nur 1 neues Boolean-Feld + 1 Hilfsmethode. Keine Änderung an der Painter-Logik nötig.
- **Dokumentierbar**: Der Mapper-Guide (`06_map_loader.md`) kann erklären, dass `visible` in Tiled standardmäßig respektiert wird, aber per Code-Konfiguration überschrieben werden kann.

=> Klingt gut. Machen wir es so.
| 3 | **Sollen Zombies Geländekosten berücksichtigen?** | `ObjectHost` hat kein `TerrainService`-Integration. Zombies ignorieren Wälder, Sümpfe, Ruinen. | (a) Ja – Zombies sollen wie Spieler-Einheiten Geländekosten haben. (b) Nein – Zombies ignorieren Gelände (einfachere KI, gameplay-technisch gewollt). (c) Nur Kollisions-Tiles, aber keine Bewegungskosten-Multiplikatoren. | => a
| 4 | **Ist A*-Pfadfindung für Zombies ein Blocker?** | Aktuelle gradlinige Bewegung bleibt an Wänden hängen. | (a) Blocker – Zombies müssen um Hindernisse navigieren können. (b) Nice-to-have – aktuelle Karten haben kaum Hindernisse. (c) Reicht BFS aus `TerrainService`? | => a
| 5 | **Sollen Vorschaubilder für Karten erstellt werden?** | Beide `maps.json`-Einträge haben `previewPath: null`. | (a) Ja – PNG-Vorschaubilder für `map0` und `map1` erstellen. (b) Nein – Icon reicht für den Prototypen. (c) Automatisch generieren (aufwändig). | => a

### 5.2 Technische Fragen

| # | Frage | Kontext |
|---|-------|---------|
| 6 | **Wie priorisieren wir die fehlenden Tests?** | 4 Komponenten mit 🔴-Priorität (HexGrid, TmxParser, TmjParser, TerrainService) haben 0 Tests. Sollen alle 4 parallel geschrieben werden oder nacheinander? | => nacheinander
| 7 | **Welche Test-Art für Laufzeittests?** | Widget-Tests, Golden Tests oder Integrationstests? Die Analyse empfiehlt Widget-Tests als ersten Schritt. | => Vorerst Widget und Intergrationstests
| 8 | **Soll der LRU-Cache für Tileset-Bilder jetzt implementiert werden?** | Bei nur 2 Karten ist der Performance-Gewinn gering. Aber die Architektur wäre zukunftssicher. | => Ja
| 9 | **Soll die Laufzeit-Validierung der Karte Fehler oder Warnungen produzieren?** | Fehlende `ground`-Layer: Soll die Karte gar nicht geladen werden (Fehler) oder nur eine Warnung im Log erscheinen? | => Fehler
| 10 | **Sollen die 3 Dokumentations-Lücken jetzt gefixt werden?** | `01_class_diagram.md` (Zeile 204: `_HexUtils`), `04_cliffnotes.md` (Zeile 145: hardcodierter TMX-Pfad), `05_new_employee_guide.md` (Zeile 268: hardcodierter TMX-Pfad). | => Ja

### 5.3 Refactoring-Fragen

| # | Frage | Kontext |
|---|-------|---------|
| 11 | **Soll `ObjectHost._hexGrid!` durch eine defensive Prüfung ersetzt werden?** | Aktuell `HexGrid?` mit `!`-Assertion. Alternative: `late final HexGrid hexGrid` (wird einmal gesetzt, dann nicht-null). | => Ja
| 12 | **Soll `ObjectHost.collisionSet` gekapselt werden?** | Aktuell `Set<int> collisionSet` (public mutable). Alternative: privates Feld mit Setter + Getter. | => Ja
| 13 | **Soll `_tilesetLookup` in `_HexMapPainter` entfernt werden?** | Ist eine exakte Referenz-Kopie von `tilesetImages`. Alternative: direkt `tilesetImages` im Painter verwenden. | => Ja
| 14 | **Soll `ObjectHost` die Pixel-Distanz durch Hex-Distanz ersetzen?** | 3 Stellen verwenden `(a.position - b.position).distance` statt `hexGrid.distance()`. Derzeit niedriges Risiko, da `rangeValue` meist 0 ist. | => Ja

### 5.4 Nächste Schritte – Entscheidungsmatrix

Die folgende Matrix bewertet die offenen Punkte nach **Aufwand** (1–5, niedrig→hoch) und **Nutzen** (1–5, niedrig→hoch):

| Punkt | Aufwand | Nutzen | Empfehlung |
|-------|---------|--------|------------|
| Bug 1 fixen (TSX async) | 3 | 4 | 🔴 Nächster Sprint |
| Bug 2 fixen (firstGid) | 1 | 3 | 🔴 Nächster Sprint |
| Bug 3 fixen (catch _) | 1 | 4 | 🔴 Nächster Sprint |
| HexGrid-Tests | 2 | 5 | 🔴 Nächster Sprint |
| Parser-Tests | 3 | 5 | 🔴 Nächster Sprint |
| TerrainService-Tests | 2 | 5 | 🔴 Nächster Sprint |
| Pixel→Hex-Distanz (ObjectHost) | 2 | 3 | 🟡 Nächster Sprint |
| `_hexGrid!` → `late final` | 1 | 3 | 🟡 Nächster Sprint |
| `collisionSet` kapseln | 1 | 2 | 🟡 Nächster Sprint |
| `_tilesetLookup` entfernen | 1 | 1 | 🟢 Bei Gelegenheit |
| A*-Pfadfindung | 5 | 4 | 🟡 Nächster Sprint |
| TerrainService in ObjectHost | 3 | 3 | 🟡 Nächster Sprint |
| Vorschaubilder | 2 | 3 | 🟡 Nächster Sprint |
| LRU-Cache | 3 | 1 | 🟢 Später |
| Laufzeit-Validierung | 2 | 3 | 🟡 Nächster Sprint |
| Widget-Tests | 4 | 4 | 🟡 Nächster Sprint |
| Dokumentation-Lücken fixen | 1 | 2 | 🟢 Bei Gelegenheit |

**Legende:** 🔴 = kritisch, 🟡 = wichtig, 🟢 = nice-to-have
