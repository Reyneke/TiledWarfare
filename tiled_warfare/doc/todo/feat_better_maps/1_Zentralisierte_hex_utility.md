### 1. Zentralisierte Hex-Utility

Eine gemeinsame Utility-Klasse für alle Hex-Konvertierungen (`pixelToHex`, `hexToPixel`, `neighborOffsets`, `distance`, `hexKey`) – entfernt die Duplizierung zwischen `WidgetMapLoader`, `WidgetCaretaker` und `ObjectHost`.

---

#### 1.1 Aktuelle Duplizierung (Ist-Zustand)

Die Hex-Logik ist derzeit auf **drei Stellen** verteilt, mit teils subtilen Unterschieden und Fehlern:

| Methode | `WidgetCaretaker` | `ObjectHost` | `WidgetMapLoader` |
|---|---|---|---|
| `_hexToPixel` | ✅ Verwendet `widget.tileWidth/Height` | ⚠️ Hardcodierte `_hostTileWidth=32` | ⚠️ Inline in `paint()` |
| `_pixelToHex` | ✅ Mit Bounds-Clamping | ⚠️ **Ohne** Bounds-Clamping | ❌ Fehlt (wird nicht benötigt) |
| `hexKey` | ✅ `y * mapWidth + x` | ❌ **Hardcodiert** `y * 100 + x` | ❌ Fehlt |
| `neighborOffsets` | ✅ In `_HexUtils` (named records) | ⚠️ Inline mit Tupel-Syntax `(-1, -1)` | ❌ Fehlt |
| `distance` | ✅ **Cube-Koordinaten** (korrekt) | ❌ **Manhattan** `\|dx\| + \|dy\|` (falsch!) | ❌ Fehlt |
| `_findFreeHexNear` | ✅ Mit `mapWidth/mapHeight`-Bounds | ⚠️ Nur `x>=0 && y>=0` (keine obere Grenze) | ❌ Fehlt |
| `_buildOccupiedHexFields` | ✅ Mit `_HexUtils.hexKey` | ❌ Hardcodiert `y * 100 + x` | ❌ Fehlt |

---

#### 1.2 Gefundene Fehler und Probleme

1. **Falsche Distanzberechnung in `ObjectHost`** (Zeile 349, 402, 522):
   ```dart
   // ObjectHost verwendet Manhattan-Distanz:
   final hexDistance = (zombieHex.x - targetHex.x).abs() + (zombieHex.y - targetHex.y).abs();
   // Korrekt wäre Cube-Koordinaten-Distanz (wie in _HexUtils.distance)
   ```
   Auf einem Hex-Gitter ist Manhattan-Distanz mathematisch falsch. Die tatsächliche Hex-Entfernung kann abweichen, was zu inkorrekten Reichweiten-Prüfungen führt.

2. **Hardcodierte Kartenbreite `100` in `ObjectHost`** (z. B. Zeile 314, 615, 645):
   ```dart
   occupied.add(zh.y * 100 + zh.x); // Bricht bei mapWidth > 100 oder < 100
   ```
   Dies führt zu Kollisionen bei Karten mit abweichender Breite. Zwei verschiedene (x, y)-Paare könnten denselben Key erzeugen (bei `mapWidth < 100`) oder fälschlich als unterschiedlich gelten (bei `mapWidth > 100`).

3. **Fehlende Bounds-Prüfung in `ObjectHost._pixelToHex`** (Zeile 252-261):
   ```dart
   ({int x, int y}) _pixelToHex(Offset pixel) {
     final approxY = (pixel.dy / (_hostTileHeight * 3.0 / 4.0)).round();
     // Kein clamp(0, mapHeight - 1)!
     int x;
     if (approxY % 2 == 1) {
       x = ((pixel.dx - _hostTileWidth / 2) / _hostTileWidth).round();
     } else {
       x = (pixel.dx / _hostTileWidth).round();
     }
     // Kein clamp(0, mapWidth - 1)!
     return (x: x, y: approxY);
   }
   ```
   Kann negative oder zu große Hex-Koordinaten produzieren, die dann als `hexKey` invalide Werte erzeugen.

4. **Fehlende obere Bounds-Prüfung in `ObjectHost._findFreeHexNear`** (Zeile 638-687):
   ```dart
   if (x >= 0 && y >= 0 && !occupied.contains(y * 100 + x)) {
   ```
   Prüft nicht `x < mapWidth` und `y < mapHeight`, sodass Felder außerhalb der Karte als gültig betrachtet werden können.

5. **Inline-Duplizierung in `WidgetMapLoader._HexMapPainter.paint()`** (Zeile 293-302):
   ```dart
   if (y % 2 == 1) {
     pixelX = (x * tileWidth).toDouble() + tileWidth / 2;
   } else {
     pixelX = (x * tileWidth).toDouble();
   }
   pixelY = y * (tileHeight * 3.0 / 4.0);
   ```
   Dieselbe Logik wie `_hexToPixel`, aber als Inline-Code im Paint-Durchlauf.

---

#### 1.3 Design der zentralen Hex-Utility

##### 1.3.1 Architektur: Kein Observer, sondern eine reine Utility-Klasse

Die Hex-Utility sollte **kein Observer** sein, da Hex-Konvertierungen zustandslose, reine Funktionen sind. Ein Observer-Pattern wäre Overkill. Stattdessen:

- **Reine statische Utility-Klasse** (wie `_HexUtils` bereits ansatzweise in `WidgetCaretaker`)
- **Parameterisiert** mit `tileWidth`, `tileHeight`, `mapWidth`, `mapHeight`
- **Zwei Varianten** zur Auswahl:

**Variante A: Instanz-basierte Utility**
```dart
class HexGrid {
  final int tileWidth;
  final int tileHeight;
  final int mapWidth;
  final int mapHeight;
  
  const HexGrid({
    required this.tileWidth,
    required this.tileHeight,
    required this.mapWidth,
    required this.mapHeight,
  });
  
  Offset hexToPixel(int x, int y) { ... }
  ({int x, int y}) pixelToHex(Offset pixel) { ... }
  int hexKey(int x, int y) => y * mapWidth + x;
  int distance(int x1, int y1, int x2, int y2) { ... }
  List<({int dx, int dy})> neighborOffsets(int y) { ... }
}
```
✅ Vorteil: Einmal konfiguriert, alle Methoden konsistent
✅ Vorteil: Leicht testbar (kann gemockt werden)
✅ Vorteil: `hexKey` benötigt kein extra `mapWidth`-Parameter

**Variante B: Statische Methoden + Parameter-Weitergabe**
```dart
class HexUtils {
  const HexUtils._();
  
  static Offset hexToPixel(int x, int y, int tileWidth, int tileHeight) { ... }
  static ({int x, int y}) pixelToHex(Offset pixel, int tileWidth, int tileHeight, int mapWidth, int mapHeight) { ... }
  static int hexKey(int x, int y, int mapWidth) => y * mapWidth + x;
  static int distance(int x1, int y1, int x2, int y2) { ... }
  static List<({int dx, int dy})> neighborOffsets(int y) { ... }
}
```
✅ Vorteil: Keine Instanz nötig, überall direkt aufrufbar
❌ Nachteil: Viele Parameter bei jedem Aufruf
❌ Nachteil: `mapWidth` muss bei `hexKey` immer mitgegeben werden

**Empfehlung: Variante A (Instanz-basiert)**, da:
- `WidgetCaretaker` und `WidgetMapLoader` haben bereits `tileWidth/Height` und `mapWidth/Height` als Parameter
- `ObjectHost` müsste die Werte vom `WidgetCaretaker` erhalten (z. B. per Konstruktor oder Setter)
- Vermeidet Parameter-Spam bei jedem Methodenaufruf
- Einmal konfiguriert → alle Berechnungen konsistent

##### 1.3.2 Klassendiagramm

```
┌─────────────────────────────────────┐
│            HexGrid                  │
├─────────────────────────────────────┤
│ - tileWidth: int                    │
│ - tileHeight: int                   │
│ - mapWidth: int                     │
│ - mapHeight: int                    │
├─────────────────────────────────────┤
│ + hexToPixel(x, y): Offset          │
│ + pixelToHex(pixel): (x, y)         │
│ + hexKey(x, y): int                 │
│ + distance(x1,y1, x2,y2): int       │
│ + neighborOffsets(y): List<(dx,dy)> │
│ + isInBounds(x, y): bool            │
│ + findFreeHexNear(...): Offset      │
│ + buildOccupiedHexes(tokens): Set   │
└─────────────────────────────────────┘
          ▲               ▲
          │               │
┌─────────┴──────┐ ┌─────┴──────────┐
│ WidgetCaretaker│ │  ObjectHost     │
│ (nutzt HexGrid)│ │ (nutzt HexGrid) │
└────────────────┘ └────────────────┘
          ▲
          │
┌─────────┴──────────┐
│ WidgetMapLoader     │
│ (_HexMapPainter     │
│  nutzt HexGrid)     │
└────────────────────┘
```

##### 1.3.3 Datenfluss

```
TMX-Datei → WidgetMapLoader → onMapLoaded(tileWidth, tileHeight, mapWidth, mapHeight)
                                    │
                                    ▼
                              HexGrid-Instanz
                                    │
                          ┌─────────┼─────────┐
                          │         │         │
                          ▼         ▼         ▼
                   WidgetCaretaker  ObjectHost  _HexMapPainter
                   (Token-Snapping) (Zombie-AI) (Tile-Rendering)
```

---

#### 1.4 Optimierungsmöglichkeiten

1. **Caching von `neighborOffsets`**: Die Offsets sind für gerade/ungerade Zeilen immer gleich. Statt sie jedes Mal neu zu erstellen, könnten sie als `static const` vorgehalten werden:
   ```dart
   static const _evenOffsets = [(dx:-1,dy:-1), (dx:0,dy:-1), ...];
   static const _oddOffsets = [(dx:0,dy:-1), (dx:1,dy:-1), ...];
   ```

2. **`hexKey` als `int`-Berechnung optimieren**: Die Multiplikation `y * mapWidth + x` ist bereits optimal. Wichtig ist nur, dass `mapWidth` korrekt ist (nicht hardcodiert).

3. **`distance` mit Cube-Koordinaten**: Die aktuelle Implementierung in `_HexUtils` ist korrekt und sollte unverändert übernommen werden.

4. **`pixelToHex` mit Double-Präzision**: Die Rundung (`round()`) ist korrekt, aber bei sehr großen Koordinaten könnten Floating-Point-Artefakte auftreten. Ein `+ 0.5`-Offset vor dem `round()` könnte die Stabilität erhöhen.

5. **`_findFreeHexNear` vereinheitlichen**: Die spiralförmige Suche ist in `WidgetCaretaker` und `ObjectHost` nahezu identisch. Einzige Unterschiede:
   - `WidgetCaretaker` prüft `mapWidth`/`mapHeight`-Bounds
   - `ObjectHost` prüft nur `x >= 0 && y >= 0`
   → Nach Extraktion in `HexGrid` sind beide korrekt.

6. **`_buildOccupiedHexes` in Utility verschieben**: Die Logik zum Aufbau der belegten-Felder-Menge ist in beiden Klassen ähnlich und könnte als `HexGrid.buildOccupiedHexes(Iterable<ObjectToken> tokens)` bereitgestellt werden.

---

#### 1.5 Mögliche Fehler bei der Umsetzung

| Fehler | Ursache | Vermeidung |
|---|---|---|
| `ObjectHost` verwendet weiterhin hardcodierte `100` | Übersehen beim Refactoring | Alle `y * 100 + x` durch `hexGrid.hexKey(x, y)` ersetzen |
| `ObjectHost` verwendet weiterhin Manhattan-Distanz | Übersehen beim Refactoring | Alle `\|dx\| + \|dy\|` durch `hexGrid.distance(...)` ersetzen |
| `_HexMapPainter` rendert falsch | Falsche Pixel-Berechnung | `hexGrid.hexToPixel(x, y)` im Painter verwenden |
| `HexGrid`-Instanz wird nicht an `ObjectHost` übergeben | Fehlende Dependency Injection | `ObjectHost` benötigt `HexGrid`-Referenz (Setter oder Konstruktor) |
| `ObjectHost` ist ein Singleton | `HexGrid` müsste nachträglich gesetzt werden | `ObjectHost.setHexGrid(HexGrid grid)` Methode hinzufügen |
| Performance-Einbußen durch Instanz-Methoden | Vernachlässigbar (einmalige Konfiguration) | Keine Maßnahme nötig |

---

#### 1.6 Umsetzungsplan

##### Phase 1: `HexGrid`-Klasse erstellen

1. Neue Datei `lib/utils/hex_grid.dart` anlegen
2. Alle Hex-Methoden aus `_HexUtils` übernehmen (`hexKey`, `distance`, `neighborOffsets`, `offsetToCube`)
3. `hexToPixel` und `pixelToHex` aus `WidgetCaretaker` übernehmen (mit Bounds-Clamping)
4. `findFreeHexNear` aus `WidgetCaretaker` übernehmen (mit Bounds-Prüfung)
5. `buildOccupiedHexes` als neue Methode hinzufügen
6. Klasse als `HexGrid` mit Konstruktor-Parametern (`tileWidth`, `tileHeight`, `mapWidth`, `mapHeight`) designen

##### Phase 2: `WidgetCaretaker` umstellen

1. `_HexUtils`-Klasse entfernen
2. Private Methoden `_hexToPixel`, `_pixelToHex`, `_findFreeHexNear` durch `HexGrid`-Aufrufe ersetzen
3. `_buildOccupiedHexFields` durch `hexGrid.buildOccupiedHexes(...)` ersetzen
4. Alle `_HexUtils.hexKey(...)` durch `hexGrid.hexKey(...)` ersetzen
5. `_HexUtils.distance(...)` durch `hexGrid.distance(...)` ersetzen
6. `_HexUtils.neighborOffsets(...)` durch `hexGrid.neighborOffsets(...)` ersetzen

##### Phase 3: `ObjectHost` umstellen

1. `HexGrid`-Referenz als Property hinzufügen (Setter oder Konstruktor-Parameter)
2. `_hexToPixel`, `_pixelToHex` durch `hexGrid`-Aufrufe ersetzen
3. **Hardcodierte `100`** durch `hexGrid.hexKey(x, y)` ersetzen (kritisch!)
4. **Manhattan-Distanz** durch `hexGrid.distance(...)` ersetzen (kritisch!)
5. **Fehlende Bounds-Prüfung** in `_findFreeHexNear` durch `hexGrid.isInBounds(x, y)` ersetzen
6. `_buildOccupiedHostHexes` durch `hexGrid.buildOccupiedHexes(...)` ersetzen
7. Inline-Nachbar-Offsets durch `hexGrid.neighborOffsets(y)` ersetzen

##### Phase 4: `WidgetMapLoader` umstellen

1. `_HexMapPainter` erhält eine `HexGrid`-Referenz
2. Inline-Pixel-Berechnung in `paint()` durch `hexGrid.hexToPixel(x, y)` ersetzen
3. `mapPixelWidth`/`mapPixelHeight`-Berechnung (Zeile 225-226) in `HexGrid` auslagern:
   ```dart
   int get mapPixelWidth => mapWidth * tileWidth + tileWidth ~/ 2;
   int get mapPixelHeight => (mapHeight * tileHeight * 3 ~/ 4) + tileHeight ~/ 4;
   ```

##### Phase 5: Integration und Tests

1. `HexGrid`-Instanz in `ScreenMain` (oder dem gemeinsamen Parent) erzeugen
2. An `WidgetCaretaker`, `ObjectHost` und `WidgetMapLoader` übergeben
3. Alle Aufrufe auf korrekte Funktionsweise prüfen
4. Besonderes Augenmerk auf:
   - Zombie-Bewegung (vorher Manhattan → jetzt Cube-Distanz)
   - Kollisionserkennung (vorher hardcodierte 100 → jetzt korrekter Key)
   - Spawning neuer Zombies (Bounds-Prüfung)
   - Token-Snapping (Pixel↔Hex-Konvertierung)

---

#### 1.7 Datei-Struktur nach der Umsetzung

```
lib/
├── utils/
│   └── hex_grid.dart          ← NEU: Zentrale Hex-Utility
├── widgets/
│   ├── widget_caretaker.dart  ← GEÄNDERT: Nutzt HexGrid
│   └── widget_map_loader.dart ← GEÄNDERT: Nutzt HexGrid
└── objects/
    └── object_host.dart       ← GEÄNDERT: Nutzt HexGrid
```

---

#### 1.8 Was muss in der Dokumentation geändert werden?

1. **`combat_rules.md`**: Falls dort Reichweiten-Berechnungen beschrieben sind, muss klargestellt werden, dass Cube-Koordinaten-Distanz (nicht Manhattan) verwendet wird.

2. **`Hex-Grid`-Dokumentation**: Neue Dokumentation für `HexGrid`-Klasse mit:
   - Erklärung des odd-r-Schemas (staggeraxis="y", staggerindex="odd")
   - Formeln für `hexToPixel` und `pixelToHex`
   - Cube-Koordinaten-Transformation für Distanzberechnung
   - Nachbar-Offsets für gerade/ungerade Zeilen

3. **Architektur-Dokumentation**: Hinweis, dass `HexGrid` die zentrale Instanz für alle Hex-Berechnungen ist und via Dependency Injection an die Konsumenten weitergegeben wird.

4. **`ObjectHost`-Dokumentation**: Entfernen des Hinweises "Gleiche Logik wie in WidgetCaretaker" (da jetzt zentralisiert). Hinweis auf die Abhängigkeit von `HexGrid`.

5. **TMX-Map-Format-Dokumentation**: Erklärung, wie `tileWidth`, `tileHeight`, `mapWidth`, `mapHeight` aus der TMX-Datei extrahiert und an `HexGrid` übergeben werden.