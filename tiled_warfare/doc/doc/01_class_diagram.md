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
│  + spawnLineCook(): ObjectLineCook                              │
│  + removeLineCook(cook): void                                   │
│  + upgradeLineCook(cook, ...): void                             │
│  + getAvailableActions(cook): List<CombatAction>                │
│  + rollInitiative(): int                                        │
│  + performAction(action, attacker, defender, distance): Combat  │
│    Result                                                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ObjectHost                                │
│  (Singleton – KI-Gegner-Steuerung)                              │
├─────────────────────────────────────────────────────────────────┤
│  + name: String                                                 │
│  + enneagramProfile: EnneagramProfile                           │
│  + personality: HostPersonality                                 │
│  + doughDumpsterList: List<ObjectDoughDumpster>                 │
│  + spawnDoughDumpster(): ObjectDoughDumpster                    │
│  + moveAllZombiesTowardsLineCooks(targets): void                │
│  + performAllZombieAttacks(player): List<String>                │
│  + performAllDumpsterSpawning(): List<String>                   │
│  + rollInitiative(): int                                        │
│  + isDefeated: bool                                             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        WidgetCaretaker                           │
│  (StatefulWidget – Token-Verwaltung & Spiel-Logik)              │
├─────────────────────────────────────────────────────────────────┤
│  + tileWidth, tileHeight: int                                   │
│  + mapWidth, mapHeight: int                                     │
│  + transformationController: TransformationController           │
│  + spawnPoints: List<(name, x, y)>                              │
├─ Intern ────────────────────────────────────────────────────────┤
│  - _player: ObjectPlayer                                        │
│  - _host: ObjectHost                                            │
│  - _selectedToken: ObjectToken?                                 │
│  - _pendingAction: CombatAction?                                │
│  - _targetableEnemies: Set<ObjectToken>                         │
│  - _currentRound: int                                           │
│  - _isPlayerTurn, _isHostTurn, _isGameOver: bool                │
│  - _hexToPixel(), _pixelToHex()                                 │
│  - _handleTap(), _handleDragStart/Update/End()                  │
│  - _enterTargetingMode(), _executeActionOnTarget()              │
│  - _startNewRound(), _endPlayerTurn(), _executeHostTurn()       │
│  - _buildTokenWidgets(), _buildStatusPanel()                    │
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
│ - _parseBase64()       │  │                          │
│ - _parseTilesetElement()│ │                          │
│ - _parsePropertyValue() │ │                          │
└────────────────────────┘  └──────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        MapData                                   │
│  (@immutable – Geparste Kartendaten)                             │
├─────────────────────────────────────────────────────────────────┤
│  + width, height, tileWidth, tileHeight                          │
│  + orientation: MapOrientation (enum)                            │
│  + staggerAxis, staggerIndex                                     │
│  + layers: List<TileLayer>                                       │
│  + tilesets: List<TilesetInfo>                                   │
│  + objectGroups: List<ObjectGroup>                               │
│  + _layerIndexByName: Map<String, int> (late)                    │
│  + layerByName(name) → TileLayer? (O(1))                        │
│  + layerByPurpose(purpose) → TileLayer? (O(1))                  │
│  + layerByPurposeWithMapping() → TileLayer?                     │
│  + computeCollisionTiles(hexGrid) → Set<int>                    │
│  + copyWith()                                                    │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────┐
│        TileLayer             │  │       TilesetInfo        │  │     ObjectGroup      │
│  (@immutable)                │  │  (@immutable)            │  │  (@immutable)        │
├──────────────────────────────┤  ├──────────────────────────┤  ├──────────────────────┤
│  + name                      │  │  + firstGid              │  │  + name              │
│  + width, height             │  │  + source                │  │  + objects: List<    │
│  + opacity, visible          │  │  + name, tileWidth       │  │      MapObject>      │
│  + tileData: Uint32List      │  │  + tileCount, columns    │  └──────────────────────┘
│  + purpose: LayerPurpose     │  │  + imageSource           │
│  + isEmpty: bool             │  │  + imageWidth/Height     │
│  + tileAt(x, y) → int       │  └──────────────────────────┘
│  + copyWith()                │
│  + toListOfLists()           │
└──────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        WidgetMapLoader                           │
│  (StatefulWidget – Karten-Ladung & -Rendering)                  │
├─────────────────────────────────────────────────────────────────┤
│  + hexGrid: HexGrid                                              │
│  + onMapLoaded: Callback                                        │
│  + onTransformationControllerCreated: Callback                  │
│  + onSpawnPointsParsed: Callback                                │
│  + config: MapLoadConfig                                        │
├─ Intern ────────────────────────────────────────────────────────┤
│  - _mapData: MapData?                                           │
│  - _tilesetImages: Map<int, (Image, columns)>                   │
│  - _loadMap(): Future<void>                                     │
│  - _loadTilesetImages(MapData, basePath): Future<void>          │
│  - _extractSpawnPoints(MapData): List<(name, x, y)>             │
│  - _HexMapPainter (CustomPainter) – multi-tileset, multi-layer  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ScreenMain                                │
│  (StatefulWidget – Hauptbildschirm)                             │
├─────────────────────────────────────────────────────────────────┤
│  - _tileWidth, _tileHeight: int                                 │
│  - _mapWidth, _mapHeight: int                                   │
│  - _mapTransformationController: TransformationController?      │
│  - _spawnPoints: List<(name, x, y)>                             │
│  - _onMapLoaded(), _onTransformationControllerCreated()         │
│  - _onSpawnPointsParsed()                                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        MainApp                                   │
│  (StatefulWidget – Root-Widget)                                 │
├─────────────────────────────────────────────────────────────────┤
│  + build(): MaterialApp mit Theme & ScreenMain                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        AppTheme                                  │
│  (Abstract – Theme-Konfiguration)                               │
├─────────────────────────────────────────────────────────────────┤
│  + lightTheme, darkTheme: ThemeData                             │
│  + baseTextTheme: TextTheme (Google Fonts)                      │
│  + themeModeNotifier: ValueNotifier<ThemeMode>                  │
└─────────────────────────────────────────────────────────────────┘
```

## Hilfsklassen

| Klasse | Zweck |
|--------|-------|
| `CombatAction` | Enum: `melee`, `ranged` |
| `CombatResult` | Datenklasse für Kampfergebnisse (hit, damage, ...) |
| `EnneagramProfile` | 12 Enneagramm-Persönlichkeitsprofile |
| `HostPersonality` | Fuzzy-Logik-basierte Persönlichkeitsbewertung |
| `Aggressiveness` | Fuzzy-Variable (0–100) |
| `RiskTolerance` | Fuzzy-Variable (0–100) |
| `TacticalComplexity` | Fuzzy-Variable (0–100) |
| `HexGrid` | Zentrale Hex-Gitter-Utility (odd-r) in `lib/utils/hex_grid.dart` |
| `_BfsVisitedSet` | Optimiertes Set für BFS-Besuchsmarkierungen |
| `_TokenRenderInfo` | Kapselt Token + Metadaten für Darstellung |
| `_TokenWidget` | Widget zur Darstellung eines Tokens auf der Karte |
| `_HexMapPainter` | CustomPainter für das Zeichnen der Hex-Karte (multi-layer, multi-tileset, Viewport-Culling) |
| `MapData` | Datenmodell für geparste Karten (TMX/TMJ) |
| `MapMeta` | Metadaten einer Karte aus maps.json (title, previewPath, tmxPath) |
| `MapRegistry` | Lädt maps.json, stellt `List<MapMeta>` bereit |
| `TmxParser` | Parser für TMX (XML)-Karten |
| `TmjParser` | Parser für TMJ (JSON)-Karten |
| `MapParser` | Interface + Factory für Karten-Parser |
| `MapLoadConfig` | Konfiguration für Layer-/Gruppennamen beim Laden |
| `MapOrientation` | Enum: orthogonal, isometric, hexagonal, staggered |
| **`LayerPurpose`** | **Neu**: Enum für typsichere Layer-Klassifizierung (ground, collision, decorative, decorativeUpper, terrain, unknown) |