### 2. Robusteres TMX-Parsing

## Zielsetzung
Das bisherige TMX-Parsing in `widget_map_loader.dart` ist rudimentär:
- Nur CSV-Encoding unterstützt
- Nur ein Layer wird gelesen (`.findElements('layer').first`)
- Nur ein Tileset wird unterstützt (`.findElements('tileset').first`)
- Kein TMJ (JSON-Format)-Support
- Objektgruppen werden nur für den hartcodierten Namen `"Spawns"` ausgewertet
- Fehlerbehandlung mit `catch (_)` verschluckt alle Fehler

## Umsetzung

### 1. Datenmodell (`lib/models/map_data.dart`)

Ein zentrales Datenmodell, das alle Karteninformationen kapselt:

```dart
/// Repräsentiert die Ausrichtung einer Tiled-Karte.
enum MapOrientation {
  orthogonal, isometric, hexagonal, staggered;

  static MapOrientation fromString(String value) { ... }
}

/// Repräsentiert eine vollständig geparste Karte aus TMX/TMJ.
@immutable
class MapData {
  final int width;
  final int height;
  final int tileWidth;
  final int tileHeight;
  final MapOrientation orientation;  // Enum statt String
  final String staggerAxis;          // "y" oder "x"
  final String staggerIndex;         // "odd" oder "even"
  final List<TileLayer> layers;
  final List<TilesetInfo> tilesets;
  final List<ObjectGroup> objectGroups;

  const MapData({ ... });

  MapData copyWith({ ... }); // Für Laufzeit-Änderungen (z.B. Fog of War)
}

@immutable
class TileLayer {
  final String name;
  final int width;
  final int height;
  final double opacity;
  final bool visible;
  final Uint32List tileData;  // Flaches Array (effizienter als List<List<int>>)

  int tileAt(int x, int y) => tileData[y * width + x];
  List<List<int>> toListOfLists(); // Rückwärtskompatibilität
}

@immutable
class TilesetInfo {
  final int firstGid;
  final String? source;       // Referenz auf .tsx-Datei
  final String? name;
  final int? tileWidth;
  final int? tileHeight;
  final int? tileCount;
  final int? columns;
  final String? imageSource;  // Relativer Pfad zum Tileset-Bild
  final int? imageWidth;
  final int? imageHeight;
}

@immutable
class ObjectGroup {
  final String name;
  final List<MapObject> objects;
}

@immutable
class MapObject {
  final int id;
  final String name;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final bool visible;
  final Map<String, dynamic> properties; // Custom Properties (typsicher: int, bool, float, String)
}
```

### 2. Parser-Interface (`lib/services/map_parser.dart`)

Ein gemeinsames Interface für TMX- und TMJ-Parser, inklusive Factory:

```dart
abstract class MapParser {
  /// Parst eine Karte aus einem String (XML oder JSON) – synchron.
  MapData parse(String content, String basePath);

  /// Lädt und parst eine Karte aus einer Asset-Datei.
  Future<MapData> loadFromAsset(String assetPath);

  /// Extrahiert den Basis-Pfad aus einem Asset-Pfad.
  static String basePath(String assetPath) { ... }

  /// Factory: erstellt den passenden Parser anhand der Dateiendung.
  static MapParser forPath(String path, {AssetBundle? assetBundle}) { ... }
}
```

**Hinweis:** `parse()` ist synchron, da `zlib.decode` in Dart synchron ist. Die async-Variante `loadFromAsset` lädt die Datei und ruft dann `parse()` auf.

### 3. TMX-Parser (`TmxParser` in `lib/services/map_parser.dart`)

Vollständiger XML-Parser mit Unterstützung für:
- **CSV-Encoding**: `data encoding="csv"` → Komma-separierte Werte (mit Leerzeichen-Handling)
- **Base64-Encoding**: `data encoding="base64"` → Base64-dekodierte Binärdaten (synchron)
- **Zlib-Encoding**: `data encoding="base64" compression="zlib"` → Base64 + Zlib-Dekomprimierung (synchron)
- **Mehrere Layer**: Alle `<layer>`-Elemente parsen
- **Mehrere Tilesets**: Alle `<tileset>`-Elemente mit korrektem `firstgid`-Mapping
- **Externe TSX-Dateien**: Laden von `.tsx`-Referenzen für Tileset-Details
- **Objektgruppen**: Alle `<objectgroup>`-Elemente generisch parsen
- **Custom Properties**: `<properties>`-Elemente mit Typ-Parsing (int, float, bool, color, string)
- **Validierung**: Prüft, ob `tileIds.length == width * height`
- **Fehler mit Kontext**: Layer-Name in `FormatException` bei fehlendem `<data>`-Element
- **Flip-Bit-Maskierung**: `tileId & 0x3FFFFFFF` in Base64-Parser

```dart
class TmxParser implements MapParser {
  final AssetBundle _assetBundle;

  TmxParser({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  @override
  MapData parse(String content, String basePath) {
    final document = XmlDocument.parse(content);
    final mapElement = document.findElements('map').first;

    final orientationStr = mapElement.getAttribute('orientation') ?? 'orthogonal';
    final orientation = MapOrientation.fromString(orientationStr);

    return MapData(
      width: int.parse(mapElement.getAttribute('width') ?? '0'),
      height: int.parse(mapElement.getAttribute('height') ?? '0'),
      tileWidth: int.parse(mapElement.getAttribute('tilewidth') ?? '32'),
      tileHeight: int.parse(mapElement.getAttribute('tileheight') ?? '32'),
      orientation: orientation,
      staggerAxis: mapElement.getAttribute('staggeraxis') ?? 'y',
      staggerIndex: mapElement.getAttribute('staggerindex') ?? 'odd',
      layers: _parseLayers(mapElement),
      tilesets: _parseTilesets(mapElement, basePath),
      objectGroups: _parseObjectGroups(mapElement),
    );
  }

  List<TileLayer> _parseLayers(XmlElement mapElement) {
    // ... parst alle <layer>-Elemente
    // Unterstützt CSV, Base64, Base64+Zlib
    // Validiert tileIds.length == width * height
    // Gibt FormatException mit Layer-Namen bei fehlendem <data>
  }

  List<int> _parseCsv(String csv) {
    // Überspringt leere Einträge (wichtig für Zeilenumbrüche in CSV)
    return csv
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => int.parse(s.trim()))
        .toList();
  }

  List<int> _parseBase64(String base64Data, String? compression) {
    // Synchron (zlib.decode ist synchron in Dart)
    // Flip-Bits werden maskiert (tileId & 0x3FFFFFFF)
  }

  List<TilesetInfo> _parseTilesets(XmlElement mapElement, String basePath) {
    // Verwendet _parseTilesetElement() für beide Fälle (extern/inline)
    // Keine Code-Duplizierung mehr
  }

  TilesetInfo _parseTilesetElement(XmlElement element, int firstGid, {String? source}) {
    // Einheitliche Methode für inline und externe TSX-Tilesets
    // Vermeidet doppelten Code
  }

  List<ObjectGroup> _parseObjectGroups(XmlElement mapElement) {
    // Parst alle <objectgroup>-Elemente
    // Custom Properties mit Typ-Parsing (int, float, bool, color)
  }

  dynamic _parsePropertyValue(String value, String type) {
    // Wandelt Property-Werte basierend auf dem Tiled-Typ um
  }
}
```

### 4. TMJ-Parser (`TmjParser` in `lib/services/map_parser.dart`)

JSON-Parser für das Tiled JSON Map Format (`.tmj`) – vollständig implementiert:

```dart
class TmjParser implements MapParser {
  final AssetBundle _assetBundle;

  TmjParser({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  @override
  MapData parse(String content, String basePath) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    // ... vollständige Implementierung
  }

  List<TileLayer> _parseLayers(Map<String, dynamic> mapJson) {
    // Parst tilelayer-Objekte mit Flip-Bit-Maskierung
  }

  List<TilesetInfo> _parseTilesets(Map<String, dynamic> mapJson, String basePath) {
    // Parst inline- und externe Tilesets (externe als Referenz)
  }

  List<ObjectGroup> _parseObjectGroups(Map<String, dynamic> mapJson) {
    // Parst objectgroup-Objekte mit Custom Properties
  }
}
```

**Wichtig:** Anders als im ursprünglichen Entwurf sind TMX- und TMJ-Parser in **einer Datei** (`lib/services/map_parser.dart`) zusammengefasst, da sie das gleiche Interface implementieren und eng zusammengehören.

### 5. Integration in `WidgetMapLoader`

Der `WidgetMapLoader` wurde komplett überarbeitet:

```dart
// Konfigurierbare Layer-Namen (statt Hardcodierung)
class MapLoadConfig {
  final String groundLayerName;       // default: 'ground'
  final String? collisionLayerName;   // default: 'collision'
  final String spawnGroupName;         // default: 'Spawns'
  final String? decorationLayerName;   // default: 'decoration'
  final String? decorationUpperLayerName; // default: 'decoration - upper'
}

class _WidgetMapLoaderState extends State<WidgetMapLoader> {
  // Alle Tileset-Bilder, indiziert nach firstGid → Multi-Tileset-Support
  final Map<int, ({ui.Image image, int columns})> _tilesetImages = {};

  Future<void> _loadMap() async {
    // 1. Parser per Factory erstellen
    final parser = MapParser.forPath(widget.mapPath, assetBundle: rootBundle);

    // 2. Karte laden und parsen
    final mapData = await parser.loadFromAsset(widget.mapPath);

    // 3. Alle Tileset-Bilder laden (nicht nur das erste)
    await _loadTilesetImages(mapData, basePath);

    // 4. Spawnpunkte extrahieren (konfigurierbarer Gruppenname)
    final spawnPoints = _extractSpawnPoints(mapData);

    // 5. Callbacks auslösen
    widget.onSpawnPointsParsed?.call(spawnPoints);
    widget.onMapLoaded?.call(...);
  }

  // Korrekte Ressourcen-Bereinigung
  @override
  void dispose() {
    for (final entry in _tilesetImages.values) {
      entry.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary um die Karte für Performance
    return RepaintBoundary(
      child: InteractiveViewer(
        // ...
        child: CustomPaint(
          painter: _HexMapPainter(
            tilesetImages: _tilesetImages,  // Multi-Tileset
            tilesets: _mapData!.tilesets,
            mapData: _mapData!,
            config: widget.config,          // Konfigurierbare Layer
          ),
        ),
      ),
    );
  }
}
```

### 6. Viewport-Culling im `_HexMapPainter`

Der Painter wurde für Performance optimiert:

- **Multi-Tileset-Support**: `findTileset()` ermittelt das richtige Tileset per `firstGid`
- **Mehrere Layer**: Bodenschicht, Dekoration, obere Dekoration (konfigurierbar)
- **Layer-Opacity**: Unterstützt transparente Layer
- **Vorberechnete Pixel-Positionen**: `_precomputePositions()` berechnet einmal alle Positionen
- **Viewport-Culling**: Nur Tiles im sichtbaren Bereich werden gezeichnet
- **Korrektes `shouldRepaint`**: Prüft alle relevanten Abhängigkeiten

```dart
class _HexMapPainter extends CustomPainter {
  final Map<int, ({ui.Image image, int columns})> tilesetImages;
  final List<TilesetInfo> tilesets;
  final MapData mapData;
  final MapLoadConfig config;
  late final List<List<Offset>> _pixelPositions; // Vorberechnet

  _HexMapPainter({...}) {
    _precomputePositions(); // Einmalig, nicht pro Frame
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visibleRect = Offset.zero & size;
    _drawLayer(canvas, visibleRect, config.groundLayerName);
    if (config.decorationLayerName != null) {
      _drawLayer(canvas, visibleRect, config.decorationLayerName!);
    }
    if (config.decorationUpperLayerName != null) {
      _drawLayer(canvas, visibleRect, config.decorationUpperLayerName!);
    }
  }

  void _drawLayer(Canvas canvas, Rect visibleRect, String layerName) {
    // Layer anhand des Namens finden
    // Viewport-Culling: visibleRect.overlaps(tileRect)
    // Multi-Tileset: findTileset(tileId, tilesets)
    // Layer-Opacity: paint.color.withValues(alpha: layer.opacity)
  }
}
```

## Klassendiagramm

```
┌─────────────────────────────────────────────────────────────┐
│                      MapParser (Interface)                   │
├─────────────────────────────────────────────────────────────┤
│ + parse(content, basePath) → MapData (synchron!)            │
│ + loadFromAsset(assetPath) → Future<MapData>                │
│ + basePath(assetPath) → String (static)                     │
│ + forPath(path) → MapParser (static Factory)                │
└─────────────────────────────────────────────────────────────┘
          ▲                              ▲
          │                              │
┌─────────┴──────────────┐  ┌───────────┴──────────────┐
│      TmxParser         │  │       TmjParser          │
├────────────────────────┤  ├──────────────────────────┤
│ - _parseLayers()       │  │ - _parseLayers()         │
│ - _parseTilesets()     │  │ - _parseTilesets()       │
│ - _parseObjectGroups() │  │ - _parseObjectGroups()   │
│ - _parseCsv()          │  │ - _parsePropertyValue()  │
│ - _parseBase64()       │  │                          │
│ - _parseTilesetElement()│ │                          │
│ - _parsePropertyValue() │ │                          │
└────────────────────────┘  └──────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                        MapData                               │
├─────────────────────────────────────────────────────────────┤
│ + width, height, tileWidth, tileHeight                      │
│ + orientation: MapOrientation (enum)                        │
│ + staggerAxis, staggerIndex                                 │
│ + layers: List<TileLayer>                                   │
│ + tilesets: List<TilesetInfo>                               │
│ + objectGroups: List<ObjectGroup>                           │
│ + copyWith()                                                │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────┐
│        TileLayer         │  │       TilesetInfo        │  │     ObjectGroup      │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────┤
│ + name                   │  │ + firstGid               │  │ + name               │
│ + width, height          │  │ + source                 │  │ + objects: List<     │
│ + opacity, visible       │  │ + name, tileWidth        │  │     MapObject>       │
│ + tileData: Uint32List   │  │ + tileCount, columns     │  └──────────────────────┘
│ + tileAt(x, y) → int    │  │ + imageSource            │
│ + toListOfLists()        │  │ + imageWidth/Height      │
└──────────────────────────┘  └──────────────────────────┘
```

## Wichtige Änderungen gegenüber dem ursprünglichen Entwurf

### 1. Datenmodell (`map_data.dart`)
- `orientation` ist jetzt ein `MapOrientation`-Enum statt `String`
- `tileData` ist `Uint32List` statt `List<List<int>>` (speichereffizienter)
- `MapObject.properties` ist `Map<String, dynamic>` statt `Map<String, String>` (typsicher)
- Alle Klassen haben `@immutable`-Annotation und `const`-Konstruktoren
- `MapData` hat eine `copyWith()`-Methode
- `TileLayer` hat `tileAt(x, y)` und `toListOfLists()` für Rückwärtskompatibilität

### 2. Parser-Struktur (`map_parser.dart`)
- **Eine Datei** statt drei: TMX- und TMJ-Parser sind in `map_parser.dart` zusammengefasst
- `MapParser` hat statische Factory-Methode `forPath()` für saubere Parser-Auswahl
- `parse()` ist **synchron** (zlib.decode ist synchron in Dart)
- `MapParser.basePath()` vermeidet Duplizierung der Pfad-Extraktion
- `_parseBase64()` maskiert Flip-Bits (`tileId & 0x3FFFFFFF`)
- `_parseCsv()` filtert leere Einträge (`where((s) => s.trim().isNotEmpty)`)
- `_parseTilesetElement()` vermeidet Code-Duplizierung zwischen inline/extern
- Validierung: `tileIds.length == width * height`
- Bessere Fehlermeldungen mit Kontext (Layer-Name)

### 3. TMJ-Parser (`TmjParser`)
- Vollständig mit `_parseTilesets()` und `_parseObjectGroups()` (fehlten im Entwurf)
- `AssetBundle`-Parameter im Konstruktor (fehlte im Entwurf)
- Verwendet `num` für JSON-Zahlen (verhindert Absturz bei Float-Werten)

### 4. Integration (`widget_map_loader.dart`)
- `MapLoadConfig` für konfigurierbare Layer-/Gruppennamen (kein Hardcoding von `'Spawns'`)
- `_loadMap()` in kleinere Methoden aufgeteilt
- Mehrere Tilesets werden geladen (indiziert nach `firstGid`)
- Spezifische Exception-Typen (`FormatException`) statt `catch (_)`
- Korrekte `dispose()`-Methode mit Image-Bereinigung
- `findTileset()` als Top-Level-Funktion für `firstGid`-Mapping

### 5. Painter (`_HexMapPainter`)
- Vorberechnete Pixel-Positionen (Performance-Optimierung)
- Multi-Layer-Unterstützung (Boden, Dekoration, obere Dekoration)
- Multi-Tileset-Unterstützung mit `findTileset()`
- Viewport-Culling
- Layer-Opacity
- `RepaintBoundary` um die Karte

## Layers

### Aktuelle Layer in der TMX
| Layer-ID | Name | Typ | Zweck |
|----------|------|-----|-------|
| 1 | Kachelebene 1 | TileLayer | Boden (einheitlich Gras, Tile 121) |
| 4 | Bildebene 1 | ImageLayer | (leer, ungenutzt) |
| 5 | Gelaendetypen | ObjectGroup | Terrain-Regionen (z. B. "Ruine") |
| 2 | Spawns | ObjectGroup | Startpositionen für Spieler/Monster |

### Vorgeschlagene Layer-Struktur für zukünftige Karten
| Layer-Name | Typ | Zweck |
|------------|-----|-------|
| `ground` | TileLayer | Bodenbelag (Gras, Stein, Wasser) |
| `decoration` | TileLayer | Dekorative Tiles (Bäume, Büsche, Laternen) – keine Kollision |
| `decoration - upper` | Wie `decoration`, nur wird sie an oberster Ebene gezeichnet, um z.B. Wolken darzustellen - keine Kollision |
| `collision` | TileLayer | Kollisions-Tiles (1 = blockiert, 0 = frei) |
| `terrain` | ObjectGroup | Geländetypen als Rechtecke/Polygone |
| `spawns` | ObjectGroup | Spawnpunkte |
| `fog_of_war` | (Laufzeit) | Wird nicht in Tiled definiert, sondern zur Laufzeit generiert |

### Geländetypen: Layer vs. Objekt in Tiled

**Empfehlung: Objektgruppen für Geländetypen verwenden.**

Begründung:
- Geländetypen sind oft **regionen-basiert** (z. B. "Ruine von (100,100) bis (300,200)"), nicht tile-basiert
- Ein Geländetyp kann **mehrere Tiles** überspannen (z. B. eine Ruine aus 4×4 Tiles)
- Objektgruppen erlauben **Custom Properties** (z. B. `movementCost=2`, `blocksVision=true`)
- TileLayer sind besser für sich wiederholende Muster (Boden, Dekoration)

### Fog of War

**Ansatz: Laufzeit-generiert, nicht in Tiled.**

- Fog of War wird **nicht** als Layer in Tiled definiert
- Stattdessen wird zur Laufzeit ein `fogLayer` verwaltet
- Jeder Token hat eine Sichtweite (in Hex-Schritten)
- Nach jedem Zug wird der Fog of War neu berechnet:
  1. Alle Felder in Sichtweite eines freundlichen Tokens → sichtbar
  2. Alle Felder, die einmal sichtbar waren → "explored" (halbdunkel)
  3. Alle anderen Felder → schwarz (unsichtbar)
- Der `_HexMapPainter` malt dann:
  - Sichtbare Felder: normal
  - Explored-Felder: abgedunkelt (Opacity 0.5)
  - Unsichtbare Felder: schwarz

## Tilesets

### Aktuelle Situation
- Ein Tileset: `Thespazztikone_tilemaps_005_neu.tsx` (firstgid=1)
- 160 Tiles (16 Spalten × 10 Zeilen), 32×32 Pixel
- Externe TSX-Datei mit Referenz auf PNG

### Mehrere Tilesets pro Karte

Tiled unterstützt mehrere Tilesets pro Karte. Jedes Tileset hat ein `firstgid`:

```xml
<tileset firstgid="1" source="terrain.tsx"/>
<tileset firstgid="161" source="buildings.tsx"/>
<tileset firstgid="321" source="units.tsx"/>
```

**Wichtig für die Implementierung:**
- `firstgid` ist der erste Global-ID-Wert, den dieses Tileset belegt
- Tile-ID 1–160 → Tileset 1 (Index 0–159)
- Tile-ID 161–320 → Tileset 2 (Index 0–159)
- Tile-ID 321–480 → Tileset 3 (Index 0–159)
- Beim Zeichnen muss das korrekte Tileset anhand des `firstgid`-Bereichs ermittelt werden

```dart
TilesetInfo? findTileset(int tileId, List<TilesetInfo> tilesets) {
  if (tileId == 0) return null;
  for (int i = tilesets.length - 1; i >= 0; i--) {
    if (tileId >= tilesets[i].firstGid) {
      return tilesets[i];
    }
  }
  return null;
}
```

### Tiled als Editor
Tiled bleibt voll nutzbar. Die Implementierung setzt auf:
- Standard-TMX-Format (XML) und TMJ-Format (JSON)
- Standard-Encodings (CSV, Base64, Base64+Zlib)
- Standard-Tileset-Referenzen (extern als TSX oder inline)
- Objektgruppen mit Custom Properties

Ein eigener Editor ist **nicht nötig**.

## Umsetzungsplan

### Phase 1: Datenmodell & Parser-Struktur
- [x] `MapData`, `TileLayer`, `TilesetInfo`, `ObjectGroup`, `MapObject` definieren
- [x] `MapParser`-Interface definieren
- [x] `TmxParser` implementieren (CSV + Base64 + Zlib)
- [x] `TmjParser` implementieren
- [ ] Unit-Tests für beide Parser schreiben

### Phase 2: Integration
- [x] `WidgetMapLoader` auf `MapParser` umstellen
- [x] Mehrere Layer unterstützen (Boden + Dekoration)
- [x] Mehrere Tilesets unterstützen (mit firstgid-Mapping)
- [x] Objektgruppen generisch parsen und per Konfiguration auswerten
- [x] Alten Code entfernen (duplizierte Hex-Logik, hardcodierte Fallbacks)

### Phase 3: Optimierung
- [x] Viewport-Culling im `_HexMapPainter`
- [x] `RepaintBoundary` um die Karte
- [x] Spezifische Exception-Typen statt `catch (_)`

### Phase 4: Erweiterung
- [ ] Geländetypen aus Objektgruppen auswerten
- [ ] Bewegungskosten pro Geländetyp
- [ ] Kollisions-Tiles auswerten
- [ ] Fog of War (Laufzeit-generiert)