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

> **Status-Update (31. Juli 2026, nach Implementierung):** Die folgenden Häkchen zeigen, was bereits integriert wurde. Punkte ohne Häkchen sind noch offen.

### ✅ Bereits integriert (in dieser Session)

| # | Punkt | Status | Datei(en) |
|---|-------|--------|-----------|
| 1 | **Bug 2:** `firstGid` in `_parseTilesetElementFromXml` korrekt setzen | ✅ Erledigt | `lib/services/map_parser.dart` – `_parseTilesetElementFromXml` akzeptiert jetzt `firstGid`-Parameter |
| 2 | **Bug 3:** `screen_start.dart` `catch (_)` durch spezifische Exceptions ersetzen | ✅ Erledigt | `lib/screens/screen_start.dart` – `on FileSystemException` + `on FormatException` |
| 3 | **Problem 2:** `ObjectHost._hexGrid!` → `late final HexGrid hexGrid` | ✅ Erledigt | `lib/objects/object_host.dart` |
| 4 | **Problem 3:** `ObjectHost.collisionSet` kapseln | ✅ Erledigt | `lib/objects/object_host.dart` – privates Feld + Getter/Setter |
| 5 | **Problem 4:** `_tilesetLookup` in `_HexMapPainter` entfernen | ✅ Erledigt | `lib/widgets/widget_map_loader.dart` – nutzt direkt `tilesetImages` |
| 6 | **Problem 5:** `respectLayerVisibility` in `MapLoadConfig` | ✅ Erledigt | `lib/widgets/widget_map_loader.dart` – neues Boolean-Feld (Default: `true`) |
| 7 | **Problem 1 (teilweise):** Pixel-Distanz → Hex-Distanz | 🟡 Teilweise | `lib/objects/object_host.dart` – Reichweiten-Prüfungen nutzen `hexGrid.distance()`. Die Zielauswahl (`_moveZombieTowardsTarget`) und der `distance`-Parameter für `performAction()` verwenden weiterhin Pixel-Distanz. |
| 8 | **Bug im LoS-Algorithmus:** Cube→Offset-Konvertierung | ✅ Erledigt | `lib/services/fog_of_war.dart` – `qz` statt `qy` für odd-r-Offset |
| 9 | **Test-Bug:** Tokens an Map-Ecken mit `fieldOfView=1` | ✅ Erledigt | `test/fog_of_war_test.dart` – Test auf Kartenmitte korrigiert |
| 10 | **Dokumentations-Lücken:** 3 Dateien | ✅ Erledigt | `01_class_diagram.md` (`_HexUtils`→`HexGrid`), `04_cliffnotes.md`, `05_new_employee_guide.md` (TMX-Pfad dynamisch) |
| 11 | **Verifikation:** `flutter analyze` + `flutter test` | ✅ Erledigt | 0 Fehler, 0 Warnungen; alle 17 Fog-of-War-Tests bestehen |

### ❌ Noch offen (Kritische ToDos)

- [ ] **Bug 1:** `_parseExternalTileset` async machen oder entfernen
  - **Anmerkung:** Der async-Flow existiert bereits über `_resolveExternalTilesetSource()` in `widget_map_loader.dart`. Die Parser-Methode selbst speichert nur die `source`-Referenz. Für Feature-Kompatibilität empfiehlt sich, `_parseExternalTileset` zu entfernen oder `loadExternalTileset()` korrekt in den Parser-Flow zu integrieren.
- [ ] **HexGrid-Tests schreiben** (höchste Priorität)
- [ ] **Parser-Tests schreiben** (TMX + TMJ)
- [ ] **TerrainService-Tests schreiben**

### ❌ Noch offen (Wichtige Verbesserungen)

- [ ] **Problem 1 (Rest):** `_moveZombieTowardsTarget` – Zielauswahl und `distance`-Parameter für `performAction()` auf Hex-Distanz umstellen
- [ ] **A*-Pfadfindung für Zombies** (statt gradliniger Bewegung)
- [ ] **`TerrainService` in `ObjectHost` integrieren** (Zombies berücksichtigen Geländekosten)
- [ ] **Vorschaubilder für Karten erstellen** (`previewPath` in `maps.json`)

### ❌ Noch offen (Langfristige Ziele)

- [ ] Laufzeittests (Widget-Tests + Golden Tests)
- [ ] LRU-Cache für Tileset-Bilder
- [ ] Laufzeit-Validierung der Karte nach dem Laden
- [ ] Integrationstests für den kompletten Spielfluss

## 5. Offene Fragen (beantwortet)

Nach der Analyse wurden alle offenen Fragen geklärt. Die Entscheidungen sind unten dokumentiert.

### 5.1 Design-Entscheidungen

| # | Frage | Entscheidung | Begründung |
|---|-------|-------------|------------|
| 1 | **Soll `_parseExternalTileset` async werden oder entfernt?** | **Option (a):** `_parseExternalTileset` async machen und in den `loadFromAsset()`-Flow integrieren. | Externe TSX-Tilesets müssen korrekt geladen werden können. Die async-Infrastruktur (`loadExternalTileset()`) existiert bereits – sie muss nur in den normalen Flow eingebunden werden. |
| 2 | **Soll das `visible`-Flag von Tiled-Layern respektiert werden?** | **Option (c):** Konfigurierbar via `MapLoadConfig.respectLayerVisibility` (Default: `true`). | Siehe Lösungsskizze unten. Bietet maximale Flexibilität: Mapper können Layer in Tiled ausblenden, Entwickler können das Verhalten per Code überschreiben. |
| 3 | **Sollen Zombies Geländekosten berücksichtigen?** | **Option (a):** Ja – Zombies sollen wie Spieler-Einheiten Geländekosten haben. | Einheitliches Gameplay. `TerrainService` in `ObjectHost` integrieren. |
| 4 | **Ist A*-Pfadfindung für Zombies ein Blocker?** | **Option (a):** Ja – Zombies müssen um Hindernisse navigieren können. | Aktuelle gradlinige Bewegung bleibt an Wänden hängen. A* oder BFS aus `TerrainService` als Grundlage. |
| 5 | **Sollen Vorschaubilder für Karten erstellt werden?** | **Option (a):** Ja – PNG-Vorschaubilder für `map0` und `map1` erstellen. | Verbessert die Benutzererfahrung in der Kartenauswahl. |

**👉 Konkrete Lösungsskizze für Frage 2 (Option c) – `respectLayerVisibility` in `MapLoadConfig`:**

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

### 5.2 Technische Fragen

| # | Frage | Entscheidung | Begründung |
|---|-------|-------------|------------|
| 6 | **Wie priorisieren wir die fehlenden Tests?** | **Nacheinander:** HexGrid → TmxParser → TmjParser → TerrainService. | Fokussierte Arbeit pro Komponente. HexGrid zuerst, da es die Basis für alle anderen ist. |
| 7 | **Welche Test-Art für Laufzeittests?** | **Widget-Tests + Integrationstests.** | Widget-Tests für isolierte UI-Komponenten (z. B. `WidgetMapLoader`), Integrationstests für den kompletten Spielfluss. Golden Tests vorerst zurückgestellt. |
| 8 | **Soll der LRU-Cache für Tileset-Bilder jetzt implementiert werden?** | **Ja.** | Zukunftssicher. Auch bei 2 Karten vermeidet er wiederholte Ladevorgänge beim Kartenwechsel. |
| 9 | **Soll die Laufzeit-Validierung der Karte Fehler oder Warnungen produzieren?** | **Fehler.** | Fehlende `ground`-Layer sind ein schwerwiegendes Problem – die Karte kann nicht korrekt dargestellt werden. Ein Fehler ist klarer als eine Warnung. |
| 10 | **Sollen die 3 Dokumentations-Lücken jetzt gefixt werden?** | **Ja.** | Geringer Aufwand (1), klarer Nutzen (aktuelle Dokumentation). |

### 5.3 Refactoring-Fragen

| # | Frage | Entscheidung | Begründung |
|---|-------|-------------|------------|
| 11 | **Soll `ObjectHost._hexGrid!` durch eine defensive Prüfung ersetzt werden?** | **Ja – `late final HexGrid hexGrid`.** | Wird einmal gesetzt, dann nicht-null. Kein `!`-Assertion mehr nötig. Null-Sicherheit zur Compile-Zeit. |
| 12 | **Soll `ObjectHost.collisionSet` gekapselt werden?** | **Ja – privates Feld mit Setter + Getter.** | Verhindert unbeabsichtigte Mutationen von außen. |
| 13 | **Soll `_tilesetLookup` in `_HexMapPainter` entfernt werden?** | **Ja – direkt `tilesetImages` verwenden.** | Entfernt unnötige Code-Komplexität und eine redundante Referenz. |
| 14 | **Soll `ObjectHost` die Pixel-Distanz durch Hex-Distanz ersetzen?** | **Ja – `hexGrid.distance()` an allen 3 Stellen.** | Korrekte Hex-Distanz statt Pixel-Distanz. Vermeidet potenzielle Fehler bei `rangeValue > 0`. |

### 5.4 Aktualisierte Entscheidungsmatrix

Nach den getroffenen Entscheidungen ergibt sich folgende priorisierte Aufgabenliste:

| Priorität | Punkt | Aufwand | Sprint |
|-----------|-------|---------|--------|
| 🔴 Kritisch | Bug 1 fixen (TSX async) | 3 | Nächster |
| 🔴 Kritisch | Bug 2 fixen (firstGid) | 1 | Nächster |
| 🔴 Kritisch | Bug 3 fixen (catch _) | 1 | Nächster |
| 🔴 Kritisch | HexGrid-Tests schreiben | 2 | Nächster |
| 🔴 Kritisch | Parser-Tests schreiben (TMX + TMJ) | 3 | Nächster |
| 🔴 Kritisch | TerrainService-Tests schreiben | 2 | Nächster |
| 🟡 Wichtig | Pixel→Hex-Distanz (ObjectHost) | 2 | Nächster |
| 🟡 Wichtig | `_hexGrid!` → `late final` | 1 | Nächster |
| 🟡 Wichtig | `collisionSet` kapseln | 1 | Nächster |
| 🟡 Wichtig | A*-Pfadfindung für Zombies | 5 | Nächster |
| 🟡 Wichtig | TerrainService in ObjectHost | 3 | Nächster |
| 🟡 Wichtig | Vorschaubilder für Karten | 2 | Nächster |
| 🟡 Wichtig | Laufzeit-Validierung der Karte | 2 | Nächster |
| 🟡 Wichtig | Widget-Tests + Integrationstests | 4 | Nächster |
| 🟡 Wichtig | LRU-Cache für Tileset-Bilder | 3 | Nächster |
| 🟢 Nice-to-have | `_tilesetLookup` entfernen | 1 | Bei Gelegenheit |
| 🟢 Nice-to-have | Dokumentations-Lücken fixen | 1 | Bei Gelegenheit |

### 5.5 Ausführungsplan

Basierend auf dem ganzen Dokument (besonders 5.4) müssen die folgenden Punkte noch umgesetzt werden. Der Plan ist in **Phasen** gegliedert, die jeweils eine abgeschlossene, testbare Einheit bilden.

---

#### Phase 1: Kritische Bugs & Tests (sofort – nächster Sprint, Aufwand: ~11)

> **Ziel:** Stabilisierung der Basis – alle Kern-Komponenten sind getestet, bekannte Bugs sind behoben.

| # | Punkt | Wie | Dateien | Aufwand |
|---|-------|-----|---------|---------|
| 1 | **Bug 1 fixen:** `_parseExternalTileset` async | `_parseExternalTileset` entfernen und durch den bestehenden async-Flow `_resolveExternalTilesetSource()` + `loadExternalTileset()` ersetzen. Alternativ: Die Methode zu `Future<TilesetInfo>` umbauen und `loadExternalTileset()` in den Tileset-Lade-Flow von `WidgetMapLoader` integrieren. | `lib/services/map_parser.dart`, `lib/widgets/widget_map_loader.dart` | 3 |
| 2 | **HexGrid-Tests schreiben** | Neue Datei `test/hex_grid_test.dart`. Testfälle: `hexToPixel`/`pixelToHex` inverse Operationen, `distance` (Cube ≠ Manhattan), `hexKey` Eindeutigkeit, `neighborOffsets` liefert 6 Nachbarn, `isInBounds` clamping, `findFreeHexNear`, `buildOccupiedHexFields`. Siehe Test-Skizze in §3.4. | `test/hex_grid_test.dart` (neu) | 2 |
| 3 | **Parser-Tests schreiben** | Neue Datei(en) `test/map_parser_test.dart`. TMX: CSV, Base64, Base64+Zlib, Base64+Gzip, mehrere Layer, mehrere Tilesets, Objektgruppen mit Properties, Fehlerfälle (`MapParseException`). TMJ: JSON-Parsing, Objektgruppen, Flip-Bit-Maskierung. Kurze Test-TMX/TMJ-Strings als Inline-Konstanten oder Fixture-Dateien in `test/fixtures/`. | `test/map_parser_test.dart` (neu), ggf. `test/fixtures/` | 3 |
| 4 | **TerrainService-Tests schreiben** | Neue Datei `test/terrain_service_test.dart`. Testfälle: `configAt` korrekte Config pro TerrainType, `isPassable` (Kollision, belegt, impassable), `reachableHexes` mit Bewegungskosten-Multiplikatoren, `reachableHexes` stoppt bei impassable Terrain, `effectiveMovementRange` korrekte Anzahl. | `test/terrain_service_test.dart` (neu) | 2 |
| 5 | **Problem 1 (Rest):** Pixel-Distanz → Hex-Distanz | In `_moveZombieTowardsTarget`: Die Zielauswahl (`(zombie.position - target.position).distance`) durch `hexGrid.distance()` ersetzen. In `performHostFocusFire` und `performAllZombieAttacks`: Den `distance`-Parameter für `player.performAction()` auf die Hex-Distanz (`hexGrid.distance()`) statt `distance.round()` umstellen. | `lib/objects/object_host.dart` | 1 |

---

#### Phase 2: KI-Verbesserungen (danach – nächster/übernächster Sprint, Aufwand: ~8)

> **Ziel:** Zombies navigieren intelligent um Hindernisse und berücksichtigen Geländekosten.

| # | Punkt | Wie | Dateien | Aufwand |
|---|-------|-----|---------|---------|
| 6 | **`TerrainService` in `ObjectHost` integrieren** | `ObjectHost` erhält eine `TerrainService`-Referenz (Setter oder Konstruktor-Injection). `_buildOccupiedHostHexes()` nutzt zusätzlich `terrainService.isPassable()`. Die Zombie-Bewegung berücksichtigt `movementCostMultiplier` bei der Schrittberechnung. | `lib/objects/object_host.dart`, `lib/services/terrain_service.dart`, `lib/screens/screen_main.dart` (Übergabe) | 3 |
| 7 | **A*-Pfadfindung für Zombies** | Eine `findPath()`-Methode (A* oder Dijkstra) in `HexGrid` oder `TerrainService` implementieren, die Kollisions-Tiles und Geländekosten berücksichtigt. `_moveZombieTowardsTarget` ruft `findPath()` auf und bewegt den Zombie entlang des Pfads. BFS aus `TerrainService.reachableHexes()` als Fallback für wenige Schritte. | `lib/utils/hex_grid.dart` oder `lib/services/terrain_service.dart`, `lib/objects/object_host.dart` | 5 |

---

#### Phase 3: UX & Performance (parallel zu Phase 2, Aufwand: ~7)

> **Ziel:** Bessere Benutzererfahrung und stabilere Performance.

| # | Punkt | Wie | Dateien | Aufwand |
|---|-------|-----|---------|---------|
| 8 | **Vorschaubilder für Karten erstellen** | Screenshots der Karten `map0` und `map1` aus Tiled exportieren oder in der App rendern. Als `assets/maps/map0/preview.png` und `assets/maps/map1/preview.png` ablegen. `previewPath` in `maps.json` eintragen. | `assets/maps/map0/preview.png`, `assets/maps/map1/preview.png`, `assets/maps/maps.json` | 2 |
| 9 | **Laufzeit-Validierung der Karte** | In `_loadMap()` nach dem Parsen prüfen: (a) `ground`-Layer existiert, (b) Spawn-Gruppe hat mindestens 1 Objekt. Fehlender `ground`-Layer → `MapParseException` werfen (Entscheidung aus §5.2, Frage 9). Optional: Warnung per `debugPrint` bei fehlender Collision-Schicht. | `lib/widgets/widget_map_loader.dart`, `lib/services/map_exceptions.dart` | 2 |
| 10 | **LRU-Cache für Tileset-Bilder** | Eine `TilesetImageCache`-Klasse mit `LinkedHashMap` (max. 3–5 Einträge) implementieren. Bei Kartenwechsel: Nicht mehr referenzierte Bilder disposen, zuletzt genutzte behalten. `_WidgetMapLoaderState._tilesetImages` durch den Cache ersetzen. | `lib/widgets/widget_map_loader.dart` oder neue Datei `lib/services/tileset_image_cache.dart` | 3 |

---

#### Phase 4: Laufzeittests (nach Phasen 1–3, Aufwand: ~4)

> **Ziel:** Verifizieren, dass graphische Elemente korrekt interagieren (Laufzeittests).

| # | Punkt | Wie | Dateien | Aufwand |
|---|-------|-----|---------|---------|
| 11 | **Widget-Tests** | `test/widget_map_loader_test.dart`: `WidgetMapLoader` mit einer kleinen Test-TMX-Datei rendern. Prüfen: (a) `CustomPaint` wird gerendert, (b) `onMapLoaded`-Callback wird ausgelöst, (c) Fehler-UI wird bei kaputter Datei angezeigt. | `test/widget_map_loader_test.dart` (neu), ggf. `test/fixtures/test_map.tmx` | 2 |
| 12 | **Integrationstests** | `test/game_flow_test.dart` oder `integration_test/`: Kompletter Spielfluss – Karte laden → Tokens spawnen → Bewegung → Kampf → Rundenfortschritt. Läuft gegen die echte `assets/maps/map0/street_battle.tmx`. | `test/game_flow_test.dart` (neu) | 2 |

---

#### Reihenfolge & Abhängigkeiten

```
Phase 1 (kritisch, ~11 Aufwand)
  │
  ├── Phase 2 (KI, ~8 Aufwand)     ← hängt an Phase 1 (Tests sichern Refactoring ab)
  │
  └── Phase 3 (UX/Perf, ~7 Aufwand) ← unabhängig von Phase 2, parallel möglich
          │
          └── Phase 4 (Laufzeittests, ~4 Aufwand) ← hängt an Phase 2+3
```

**Empfehlung:** Phase 1 vollständig abschließen (inkl. grüner `flutter test`), dann Phase 2 und 3 parallel bearbeiten, zum Schluss Phase 4. Gesamtaufwand: **~30** (in Relation zu den bisherigen ~4.500 Zeilen Code).

---

#### Verantwortlichkeiten & Definition of Done

- **Jede Phase** endet mit: `flutter analyze` ohne Fehler/Warnungen + `flutter test` grün.
- **Neue Tests** werden in die bestehende Test-Struktur integriert (`test/`-Verzeichnis).
- **Dokumentation** wird bei jeder Änderung aktualisiert (§1 im Dokument, ggf. `06_map_loader.md` bei neuen Validierungsregeln).
- **Empfehlung:** Pro Phase einen separaten Commit/Branch, damit Fehler isoliert bleiben.

## gefundene Ungereimtheiten

> **Status:** Screenshots können nicht direkt angezeigt werden (Modell unterstützt kein Bild-Input). Die Karten-Dateien `map0` und `map1` wurden stattdessen strukturell analysiert.

### 🔴 Kritische Ungereimtheit 1: `type="ruins"` vs. `TerrainType.fromString("ruin")`

**Datei:** `assets/maps/map1/street_battle_colliders.tmx`, Zeile 159–174

Die "Gelaendetypen"-Objektgruppe in `map1` verwendet `type="ruins"` (Plural), aber `TerrainType.fromString()` in `lib/models/map_data.dart` (Zeile 697) erwartet nur `'ruin'` (Singular):

```dart
switch (value.toLowerCase()) {
  case 'ruin':       // ← Singular
    return TerrainType.ruin;
  ...
  default:
    return TerrainType.normal; // ← "ruins" fällt hierhin
}
```

**Auswirkung:** Alle 12 Ruinen-Objekte in `map1` werden als `TerrainType.normal` geparst:
- ❌ Keine doppelten Bewegungskosten (`movementCostMultiplier: 2.0`)
- ❌ Keine Sichtblockade (`blocksVision: true`)
- ❌ In `map1` sieht man **durch** alle Ruinen-Wände hindurch (Fog of War durchschaut Mauern)

**Fix-Optionen:**
- **Option A (empfohlen):** `TerrainType.fromString()` um `'ruins'` (und ggf. `'ruin'`) erweitern:
  ```dart
  case 'ruin':
  case 'ruins':
    return TerrainType.ruin;
  ```
- **Option B:** Die TMX-Datei `map1` korrigieren (`type="ruin"` statt `type="ruins"`)

### 🔴 Kritische Ungereimtheit 2: Ruinen als Polygone statt Rechtecke

**Datei:** `assets/maps/map1/street_battle_colliders.tmx`, Zeile 160–163

Zwei Ruinen-Objekte (`Wall 12`, `Wall 11`) verwenden `<polygon>`-Geometrie statt Rechtecken:

```xml
<object id="16" name="Wall 12" type="ruins" x="137" y="5">
  <polygon points="0,0 831,1 833,185 ..."/>  <!-- ⚠️ Polygon -->
</object>
```

Die `parseTerrain()`-Funktion in `lib/services/terrain_service.dart` berechnet den Mittelpunkt aus **`x + width / 2`** und **`y + height / 2`**. Bei Polygon-Objekten:
- `width` und `height` sind **nicht in der XML** enthalten → Default `0`
- Der Mittelpunkt ist also `(x + 0, y + 0)` = **die obere linke Ecke** des Polygons
- Daraus wird ein **falsches Hex-Feld** berechnet

**Auswirkung:** Für `Wall 12` (831×185 px groß) wird nur **ein einziges Hex** an der oberen linken Ecke markiert – nicht die gesamte Ruinenfläche. Bewegung und Sicht sind nur an diesem einen Punkt blockiert.

**Fix-Optionen:**
- **Option A:** `parseTerrain()` erweitern, um Polygon-Objekte zu unterstützen (jeden Punkt des Polygons in Hex umrechnen, alle überstrichenen Hexes markieren)
- **Option B:** Die TMX-Karte korrigieren: Ruinen als Rechtecke (`<object x="..." y="..." width="..." height="..."/>`) statt Polygone

### 🟡 Ungereimtheit 3: `map1`-Collision-Layer verwendet Tile-ID 3, `map0` hat keine Collisions

**Datei:** `assets/maps/map1/street_battle_colliders.tmx`, Zeile 38–69

Der Collision-Layer in `map1` hat viele `3`-Werte (blockierte Felder), `map0` hat ausschließlich `0` (alles frei).

**Auswirkung:** Die beiden Karten sehen im Spiel **grundlegend anders aus**:
- `map0` = komplett offene Fläche (keine Wände)
- `map1` = Mauer-Labyrinth (viele blockierte Felder)

Das erklärt den "seltsamen Unterschied" in den Screenshots: **Es sind unterschiedliche Karten mit unterschiedlichem Gameplay.**

### 🟡 Ungereimtheit 4: `map1` hat `decoration`-Layer mit `3`-Werten

**Datei:** `assets/maps/map1/street_battle_colliders.tmx`, Zeile 72–104

Der `decoration`-Layer in `map1` hat exakt dieselben `3`-Werte wie der Collision-Layer. Das erzeugt **sichtbare Dekoration** (Bäume/Steine) auf den blockierten Feldern – vermutlich gewollt, aber der Effekt: Die Dekoration wird **über** den Boden gezeichnet, die Collisions bleiben unsichtbar.

**Auswirkung:** In `map1` sieht man dekorative Objekte auf Mauer-Positionen, aber die eigentlichen Mauer-Tiles (Kollision) sind unsichtbar. In `map0` gibt es weder Collisions noch Dekoration.

### ⚠️ Ungereimtheit 5: `map0`-Tileset-Bildpfad vs. `map1`

Beide Karten referenzieren dasselbe Tileset (`Thespazztikone_tilemaps_005_neu.tsx`) → beide verwenden dasselbe Bild. Kein Unterschied hier. Der eigentliche Unterschied liegt in den **Layer-Daten**, nicht im Tileset.

### 🔴 Ungereimtheit 6: Screenshots zeigen unterschiedliche Karten mit unterschiedlichen Terrain-Problemen

**Screenshot-Vergleich:**

| Screenshot | Karte | Sichtbares Verhalten |
|------------|-------|----------------------|
| `2026-07-31 (1).png` | `map0` ("Street Battle") | Einfarbiger Gras-Boden (Tile 121), keine Wände, keine Dekoration → relativ leeres App-Fenster |
| `2026-07-31 (2).png` | `map1` ("Street Battle - Colliders") | Mauer-Labyrinth (Collision-Layer), Dekorations-Objekte, Ruinen-Polygone → optisch viel dichter/fülliger |

**Problem:** Die Screenshots zeigen zwei Karten mit **grundverschiedenen Terrain-Definitionen**, die zu unterschiedlichem Gameplay führen:

1. **`type="ruins"` wird nicht erkannt** (Kritisch)
   - **Datei:** `assets/maps/map1/street_battle_colliders.tmx`, Zeile 159–174
   - **Problem:** Die Terrain-Objektgruppe verwendet `type="ruins"` (Plural), aber `TerrainType.fromString()` erwartet nur `'ruin'` (Singular)
   - **Auswirkung:** Alle 12 Ruinen-Objekte werden als `TerrainType.normal` geparst:
     - ❌ Keine doppelten Bewegungskosten (`movementCostMultiplier: 2.0`)
     - ❌ Keine Sichtblockade (`blocksVision: true`)
     - ❌ Fog of War durchschaut Ruinen-Mauern

2. **Polygon-Geometrie wird falsch geparst** (Kritisch)
   - **Datei:** `assets/maps/map1/street_battle_colliders.tmx`, Zeile 160–163
   - **Problem:** Zwei Ruinen-Objekte (`Wall 12`, `Wall 11`) verwenden `<polygon>` statt Rechtecken. `parseTerrain()` berechnet den Mittelpunkt aus `x + width/2`, aber bei Polygonen sind `width` und `height` nicht in der XML → Default `0`
   - **Auswirkung:** Statt der gesamten Ruinenfläche (831×185 px) wird nur **ein einziges Hex** an der oberen linken Ecke markiert. Bewegung und Sicht sind nur an diesem Punkt blockiert.

3. **Unterschiedliche Layer-Daten zwischen `map0` und `map1`** (Info)
   - **Datei:** `assets/maps/map1/street_battle_colliders.tmx`, Zeile 38–104
   - **Problem:** `map1` hat Collision-Layer mit Tile-ID `3` (blockierte Felder) und `decoration`-Layer mit denselben Werten. `map0` hat ausschließlich `0` (alles frei).
   - **Auswirkung:** Die Karten sind für unterschiedliches Gameplay designed:
     - `map0` = offene Arena (keine Wände)
     - `map1` = Mauer-Labyrinth (viele Kollisionen + Dekoration)

4. **Weißer Balken unten wird bei Fensterverkleinerung breiter** (Info)
   - **Screenshot:** `2026-07-31 (1).png`, `2026-07-31 (2).png` und `2026-07-31 (3).png`
   - **Problem:** Bei allen drei Screenshots ist am unteren Rand ein weißer Balken sichtbar. Dieser Balken wird breiter, wenn das Fenster verkleinert wird. Dies deutet auf ein Layout-Problem hin: Der verfügbare Platz für die Karte wird nicht optimal genutzt, oder es gibt einen konstanten Abstand/Rand am unteren Rand, der bei kleineren Fenstern relativ gesehen mehr Platz einnimmt.
   - **Auswirkung:** Die Karte wird nicht vollständig dargestellt – der untere Bereich fehlt im Screenshot. Dies ist kein Bug in der Karten-Renderung, sondern ein UI-Layout-Problem bei der Fenstergrößen-Anpassung.

**Fix-Optionen:**

1. **`TerrainType.fromString()` erweitern** (1-Zeilen-Fix, empfohlen):
   ```dart
   case 'ruin':
   case 'ruins':  // ← Plural hinzufügen
     return TerrainType.ruin;
   ```

2. **Polygon-Support in `parseTerrain()`** oder TMX-Karte korrigieren:
   - **Option A:** `parseTerrain()` erweitern, um alle Polygon-Punkte in Hexes umzurechnen
   - **Option B:** TMX-Karte korrigieren: Ruinen als Rechtecke statt Polygone definieren

3. **Gameplay-Design klären:** Entscheiden, ob `map1` absichtlich mehr Kollisionen/Dekoration haben soll (unterschiedliche Spielerfahrung) oder ob beide Karten konsistent sein sollten.

---

### Zusammenfassung der Analyse

| Screenshot | Karte | Charakteristik |
|------------|-------|----------------|
| `2026-07-31 (1).png` | Vermutlich `map0` ("Street Battle") | Einfarbiger Gras-Boden (Tile 121), keine Wände, keine Dekoration → relativ leeres App-Fenster |
| `2026-07-31 (2).png` | Vermutlich `map1` ("Street Battle - Colliders") | Mauer-Labyrinth (Collision-Layer), Dekorations-Objekte, Ruinen-Polygone → optisch viel dichter/fülliger |

**Die wichtigsten Befunde:**
1. **`type="ruins"` wird nicht erkannt** – Ruinen wirken nicht als Hindernisse für Bewegung/Sicht
2. **Polygon-Geometrie wird falsch geparst** – nur 1 Hex pro Ruine markiert, nicht die Fläche
3. **`map1` hat Collisions + Dekoration, `map0` nicht** – das ist der sichtbare Unterschied

**Empfohlene Sofort-Fixes:**
1. `TerrainType.fromString()` um `'ruins'` erweitern (1-Zeilen-Fix)
2. `parseTerrain()` für Polygon-Objekte erweitern oder `map1`-Karte auf Rechtecke umstellen
3. Entscheiden, ob `map1` absichtlich mehr Kollisionen/Dekoration haben soll (Gameplay-Design)

---

## 6. Umgesetzte Fixes (Status-Update)

> **Datum:** 31. Juli 2026, nach Analyse der Ungereimtheiten

### ✅ Fix 1: `TerrainType.fromString()` erweitert

**Datei:** `lib/models/map_data.dart`

```dart
case 'ruin':
case 'ruins': // Tiled-Objektgruppen verwenden oft den Plural "ruins"
  return TerrainType.ruin;
case 'wall':
case 'walls': // Plural-Variante
  return TerrainType.wall;
```

**Effekt:** Alle 12 Ruinen-Objekte in `map1` werden jetzt als `TerrainType.ruin` erkannt (doppelte Bewegungskosten + Sichtblockade).

### ✅ Fix 2: Polygon-Geometrie unterstützt

**Dateien:** `lib/models/map_data.dart`, `lib/services/map_parser.dart`, `lib/services/terrain_service.dart`

| Schritt | Änderung |
|---------|----------|
| **2a** | `MapObject.points` (Liste von `(x, y)`-Offsets) + `absolutePoints`-Getter |
| **2b** | `TmxParser` parst `<polygon points="...">`-Elemente in Objektgruppen |
| **2b** | `TmjParser` parst `"polygon": [{"x":..,"y":..}, ...]`-Strukturen |
| **2c** | `parseTerrain()` markiert bei Polygonen **alle absoluten Eckpunkte** als Gelände |
| **2c** | `==`/`hashCode` von `MapObject` berücksichtigen `points` |

**Effekt:** Die Polygon-Ruinen (`Wall 11`, `Wall 12`) blockieren jetzt mehrere Hex-Felder statt nur eines.

### ✅ Fix 3: Weißer Balken unten (Layout-Problem) behoben

**Dateien:** `lib/widgets/widget_map_loader.dart`, `lib/screens/screen_main.dart`

**Eigentliche Ursache (gefunden nach erneutem Auftreten):** Die `boundaryMargin`-Berechnung in `widget_map_loader.dart` war mathematisch falsch:

```dart
// Vorher (FALSCH): Quadrat der Diagonale statt Diagonale
final diagonal = (viewportWidth * viewportWidth + viewportHeight * viewportHeight);
final boundaryMargin = diagonal * 0.15;
// Bei 800×600 → 1.000.000 * 0.15 = 150.000 Pixel Margin!
```

Das erlaubte dem `InteractiveViewer`, in riesige weiße Randbereiche zu pannen. Beim Verkleinern des Fensters wurde dieser weiße Bereich sichtbar.

**Fix 1 (Hauptursache):** `sqrt()` hinzugefügt:
```dart
final diagonal = sqrt(viewportWidth * viewportWidth + viewportHeight * viewportHeight);
final boundaryMargin = diagonal * 0.15;
// Bei 800×600 → 1.000 * 0.15 = 150 Pixel Margin (korrekt)
```

**Fix 2 (Zentrierung):** `_centerMap()` und `_computeFitToScreenScale()` verwenden jetzt `_lastConstraints?.maxHeight` (vom `LayoutBuilder`) statt `MediaQuery.height - kToolbarHeight`. Das garantiert korrekte Zentrierung im tatsächlich verfügbaren Bereich.

**Fix 3 (Neu-Zentrierung):** `didChangeMetrics()` zentriert die Karte jetzt **immer** neu bei Fenstergrößenänderungen (kein Zoom-Distanz-Check mehr), damit die Karte bei jeder Fenstergröße vollständig sichtbar bleibt.

### ✅ Fix 4: `map1` bleibt Labyrinth (Gameplay-Design bestätigt)

> `map1` ist bewusst als Mauer-Labyrinth konzipiert, um Wegfindung, Fog of War etc. zu testen. Die Collision- und Decoration-Layer bleiben unverändert.

### Verifikation

- **`flutter analyze`:** 0 Fehler, 0 Warnungen
- **`flutter test`:** ✅ **92/92 Tests bestehen**
