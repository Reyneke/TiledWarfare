# Klassendiagramm

## Übersicht

```
┌─────────────────────────────────────────────────────────────────┐
│                        ObjectToken                              │
│  (Basis-Klasse für alle Einheiten)                              │
├─────────────────────────────────────────────────────────────────┤
│  + name: String                                                 │
│  + imagePath: String                                            │
│  + woundValue: int                                              │
│  + attackValue: int                                             │
│  + defenseValue: int                                            │
│  + movementValue: int                                           │
│  + damageValue: int                                             │
│  + rangeValue: int                                              │
│  + position: Offset                                             │
│  + hasActed: bool                                               │
└──────────────────────┬──────────────────────────────────────────┘
                        │ extends
           ┌────────────┼─────────────┬──────────────────┐
           ▼            ▼             ▼                  ▼
┌─────────────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────────┐
│  ObjectLineCook │ │ObjectDough│ │ObjectDough   │ │ (Zukünftige  │
│  (Spieler)      │ │Zombie    │ │Dumpster      │ │  Token-Typen)│
├─────────────────┤ ├──────────┤ ├──────────────┤ │              │
│  attack: 80     │ │ attack:40│ │ wound: 50    │ │              │
│  defense: 40    │ │ defense:40│ │ attack: 0    │ │              │
│  movement: 3    │ │ movement:1│ │ movement: 0  │ │              │
│  damage: 2      │ │ damage: 1 │ │ damage: 0    │ │              │
│  range: 3       │ │ range: 0  │ │ range: 0     │ │              │
└────────┬────────┘ └──────────┘ └──────┬───────┘ └──────────────┘
          │                              │
          │ 1..*                         │ 1
          │                              │
          ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ObjectPlayer                             │
│  (Singleton – Spieler-Steuerung)                                │
├─────────────────────────────────────────────────────────────────┤
│  + lineCookList: List<ObjectLineCook>                           │
│  + spawnLineCook(), removeLineCook(cook), rollInitiative()      │
│  + performAction(action, attacker, defender, distance)          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ObjectHost                                │
│  (Singleton – KI-Gegner-Steuerung)                              │
├─────────────────────────────────────────────────────────────────┤
│  + hexGrid: HexGrid (late final)                                │
│  + terrainService: TerrainService?                              │
│  + doughDumpsterList: List<ObjectDoughDumpster>                 │
│  + collisionSet: Set<int> (gekapselt)                           │
│  + moveAllZombiesTowardsTargets() (nutzt A*)                    │
│  + performAllZombieAttacks(), performAllDumpsterSpawning()       │
│  + rollInitiative(), isDefeated                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        HexGrid (utils/)                          │
│  (Zentrale Hex-Utility, odd-r Hex-Gitter)                        │
├─────────────────────────────────────────────────────────────────┤
│  + tileWidth, tileHeight, mapWidth, mapHeight                    │
│  + hexToPixel(x, y) → Offset, pixelToHex(Offset) → (x, y)       │
│  + hexKey(x, y) → int, hexFromKey(key) → (x, y)                 │
│  + distance(x1,y1,x2,y2) → int (Cube-Distanz)                   │
│  + neighborOffsets(y), isInBounds(x, y)                          │
│  + findFreeHexNear(), buildOccupiedHexFields()                   │
│  + findPath() → List<int> (A\*, mit Kollisionen + Geländekosten) │
│  + offsetToCube(x, y) → (x, y, z) (static)                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        MapParser (Interface)                     │
├─────────────────────────────────────────────────────────────────┤
│  + parse(content, basePath) → MapData                           │
│  + loadFromAsset(assetPath) → Future<MapData>                   │
│  + basePath(assetPath) → String (static)                        │
│  + forPath(path) → MapParser (static Factory)                   │
└─────────────────────────────────────────────────────────────────┘
           ▲                              ▲
           │                              │
┌─────────┴──────────────┐  ┌───────────┴──────────────┐
│      TmxParser         │  │       TmjParser          │
├────────────────────────┤  ├──────────────────────────┤
│ - _parseLayers()       │  │ - _parseLayers()         │
│ - _parseTilesets()     │  │ - _parseTilesets()       │
│ - _parseObjectGroups() │  │ - _parseObjectGroups()   │
│ - _parseCsv()          │  │ - _parsePropertyValue()  │
│ - _parseBase64()       │  │ (Polygon-Parsing)        │
│ - _parsePropertyValue()│  │                          │
│ (Polygon-Parsing)      │  │                          │
└────────────────────────┘  └──────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        MapData (models/)                         │
│  (@immutable)                                                    │
├─────────────────────────────────────────────────────────────────┤
│  + width, height, tileWidth, tileHeight                          │
│  + orientation, staggerAxis, staggerIndex                        │
│  + layers: List<TileLayer>, tilesets: List<TilesetInfo>         │
│  + objectGroups: List<ObjectGroup>, terrain: Map<int,TerrainType>│
│  + layerByName(name) / layerByPurpose(purpose) → O(1)           │
│  + computeCollisionTiles(hexGrid) → Set<int>                    │
│  + copyWith(), toJson(), fromJson()                              │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────┐
│       TileLayer              │  │      TilesetInfo         │  │    ObjectGroup       │
├──────────────────────────────┤  ├──────────────────────────┤  ├──────────────────────┤
│  + name, width, height       │  │  + firstGid, source      │  │  + name              │
│  + opacity, visible          │  │  + name, tileWidth/Height│  │  + objects: List<    │
│  + tileData: Uint32List      │  │  + tileCount, columns    │  │      MapObject>      │
│  + purpose: LayerPurpose     │  │  + imageSource           │  └──────────────────────┘
│  + isEmpty, tileAt(x,y)      │  └──────────────────────────┘
└──────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        MapObject                                 │
│  (@immutable)                                                    │
├─────────────────────────────────────────────────────────────────┤
│  + id, name, type, x, y, width, height, rotation, visible       │
│  + properties: Map<String, dynamic>                              │
│  + points: List<({double x, double y})>  (*Polygon-Geometrie)   │
│  + absolutePoints: List<({double x, double y})>                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        WidgetMapLoader                           │
│  (StatefulWidget – Karten-Ladung & -Rendering)                  │
├─────────────────────────────────────────────────────────────────┤
│  + hexGrid: HexGrid, mapPath: String                            │
│  + onMapLoaded, onTransformationControllerCreated               │
│  + onSpawnPointsParsed, onTerrainParsed, config: MapLoadConfig  │
├─ Intern ────────────────────────────────────────────────────────┤
│  - _tilesetImages: LRU-Cache (LinkedHashMap, max 5)             │
│  - _mapData, _tileWidth/Height, _transformationController       │
│  - _loadMap(), _loadTilesetImages(), _resolveExternalTileset    │
│  - _HexMapPainter (CustomPainter): Multi-Layer, Multi-Tileset   │
│    Viewport-Culling, hexagonales Clipping (_createHexPath)      │
│  - Laufzeit-Validierung (ground-Layer, Spawn-Gruppe)            │
│  - InteractiveViewer (constrained: false, boundaryMargin: zero) │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ScreenMain                                │
│  (StatefulWidget – Hauptbildschirm)                             │
├─────────────────────────────────────────────────────────────────┤
│  + mapPath: String                                              │
│  - _hexGrid, _mapTransformationController                       │
│  - _lastConstraints: BoxConstraints (LayoutBuilder)             │
│  - _spawnPoints, _collisionSet                                  │
│  - _centerMap() → Matrix4.identity()                            │
│  - didChangeMetrics() → setState + recenter                     │
│  - _onMapLoaded(), _onTerrainParsed()                           │
│  - _onSpawnPointsParsed(), _onTransformationControllerCreated()  │
└─────────────────────────────────────────────────────────────────┘
```

## Hilfsklassen

| Klasse | Zweck |
|--------|-------|
| `CombatAction` | Enum: `melee`, `ranged`, `focusFire` |
| `CombatResult` | Datenklasse für Kampfergebnisse |
| `EnneagramProfile` | 12 Enneagramm-Persönlichkeitsprofile |
| `HostPersonality` | Fuzzy-Logik-basierte Persönlichkeitsbewertung |
| `Aggressiveness` | Fuzzy-Variable (0–100) |
| `RiskTolerance` | Fuzzy-Variable (0–100) |
| `TacticalComplexity` | Fuzzy-Variable (0–100) |
| `HexGrid` | Zentrale Hex-Gitter-Utility (odd-r), inkl. A\*-Pfadfindung |
| `findPath()` | A\*-Pfadfindung in HexGrid (Kollisions-Tiles + Geländekosten) |
| `hexFromKey()` | Key → (x, y) Rückkonvertierung für Pfad-Ergebnisse |
| `findTileset()` | Top-Level-Funktion: firstGid-Mapping für Multi-Tileset |
| `MapData` | Datenmodell für geparste Karten (TMX/TMJ) |
| `MapMeta` | Metadaten einer Karte aus maps.json |
| `MapRegistry` | Lädt maps.json, stellt `List<MapMeta>` bereit |
| `MapParser` | Interface + Factory für Karten-Parser |
| `TmxParser` | Parser für TMX (XML) inkl. Polygon-Parsing |
| `TmjParser` | Parser für TMJ (JSON) inkl. Polygon-Parsing |
| `MapLoadConfig` | Konfiguration für Layer-Namen, Spawn-Gruppe, `respectLayerVisibility` |
| `MapOrientation` | Enum: orthogonal, isometric, hexagonal, staggered |
| `LayerPurpose` | Enum: ground, collision, decorative, decorativeUpper, terrain, unknown |
| `TerrainType` | Enum: normal, ruin, forest, water, wall, openGround, swamp (mit Plural-Varianten) |
| `TerrainConfig` | Bewegungskosten-Multiplikator, blocksVision, impassable |
| `TerrainService` | Geländekonfiguration, BFS-Bewegung, Passierbarkeit, `parseTerrain()` |
| `FogOfWarService` | Sichtbarkeit (visible + revealed), LoS-Cube-DDA |
| `_HexMapPainter` | CustomPainter für Hex-Karte (Multi-Layer, Multi-Tileset, Viewport-Culling, hexagonales Clipping) |
| `_createHexPath()` | Statische Methode: Hexagonaler Clip-Pfad für Pointy-Top-Tiles |
| `_TokenWidget` | Widget zur Darstellung eines Tokens auf der Karte |