### 3. Terrain-System

> **Status**: Planning phase. No terrain code exists yet.
> **Depends on**: `2_robusteres_tmx_parsing.md` (object group parsing), `1_Zentralisierte_hex_utility.md` (HexGrid utils)
>
> Relevant existing files:
> - `lib/models/map_data.dart` — `ObjectGroup`, `MapObject` with `properties`
> - `lib/services/map_parser.dart` — `_parseObjectGroups()` extracts typed properties
> - `lib/widgets/widget_map_loader.dart` — `collisionLayerName` config, `_drawLayer()` rendering
> - `lib/utils/hex_grid.dart` — `hexKey()`, `distance()`, `isInBounds()`, `buildOccupiedHexFields()`
> - `lib/objects/object_token.dart` — `movementValue`, `rangeValue`

---

#### 3.1 Data Model — Neue Klassen in `lib/models/map_data.dart`

Füge am Ende von `map_data.dart` ein neues `TerrainType`-Enum und eine `TerrainConfig`-Klasse hinzu:

```dart
/// Geländetypen, die über die `"Gelaendetypen"`-Objektgruppe in der TMX
/// definiert werden. Jeder Typ entspricht einer `MapObject.type`-Zeichenkette.
enum TerrainType {
  /// Normales Gelände — keine Modifikatoren. (Standard)
  normal,

  /// Ruine — doppelte Bewegungskosten, blockiert Sicht.
  ruin,

  /// Wald — erhöhte Bewegungskosten, blockiert Sicht (oder gewährt Deckung).
  forest,

  /// Wasser — unpassierbar für die meisten Einheiten.
  water,

  /// Mauer — unpassierbar und blockiert Sicht.
  wall,

  /// Offenes Feld — normale Bewegung, keine Sichtblockade.
  openGround,

  /// Sumpf — dreifache Bewegungskosten.
  swamp;

  static TerrainType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ruin':
        return TerrainType.ruin;
      case 'forest':
        return TerrainType.forest;
      case 'water':
        return TerrainType.water;
      case 'wall':
        return TerrainType.wall;
      case 'open_ground':
        return TerrainType.openGround;
      case 'swamp':
        return TerrainType.swamp;
      default:
        return TerrainType.normal;
    }
  }
}

/// Konfiguration eines Geländetyps: Bewegungskosten und Sichtbarkeitsregeln.
@immutable
class TerrainConfig {
  /// Bewegungskosten-Multiplikator (1.0 = normal, 2.0 = doppelt, 0.0 = unpassierbar).
  final double movementCostMultiplier;

  /// Ob dieses Gelände die Sicht blockiert (Line-of-Sight blockieren).
  final bool blocksVision;

  /// Ob dieses Gelände unpassierbar ist (z. B. Wasser, Mauer).
  final bool impassable;

  const TerrainConfig({
    this.movementCostMultiplier = 1.0,
    this.blocksVision = false,
    this.impassable = false,
  });

  static const Map<TerrainType, TerrainConfig> defaults = {
    TerrainType.normal:     TerrainConfig(),
    TerrainType.ruin:       TerrainConfig(movementCostMultiplier: 2.0, blocksVision: true),
    TerrainType.forest:     TerrainConfig(movementCostMultiplier: 1.5, blocksVision: true),
    TerrainType.water:      TerrainConfig(impassable: true),
    TerrainType.wall:       TerrainConfig(impassable: true, blocksVision: true),
    TerrainType.openGround: TerrainConfig(),
    TerrainType.swamp:      TerrainConfig(movementCostMultiplier: 3.0),
  };
}
```

**Begründung**:
- `@immutable` verhindert unbeabsichtigte Mutationen des Config-Objekts.
- `defaults`-Map dient als **Single Source of Truth** — Erweiterungen erfolgen nur hier.
- `impassable` als explizites Flag statt `movementCostMultiplier: 0.0` (NaN-Risiko bei Divisionen).

---

#### 3.2 Terrain-Layer in `MapData` & Parser-Update

**Problem**: Bisher werden nur `TileLayer`s und `ObjectGroup`s separat gehalten. Ein Terrain-System braucht eine schnelle Lookup-Struktur: "Welcher Terrain-Typ liegt auf Hex (x, y)?"

**Lösung**: Einen `terrain`-Eintrag in `MapData` hinzufügen:

```dart
// In MapData:
final Map<int, TerrainType> terrain; // Key: hexKey(x, y) → TerrainType
```

Dies ist eine **flache Map** (kein 2D-Array), weil:
- Die meisten Felder werden `TerrainType.normal` sein (Default bei Fehlen).
- `hexKey(x, y)` aus `HexGrid` ist der natürliche Key.

**Parser-Update in `map_parser.dart`** (beide Parser):

```dart
/// Parst die "Gelaendetypen"-Objektgruppe.
/// Erwartet Rechteck-Objekte (x, y, width, height) pro Geländebereich.
Map<int, TerrainType> parseTerrain(ObjectGroup? terrainGroup, HexGrid hexGrid) {
  final result = <int, TerrainType>{};
  if (terrainGroup == null) return result;

  for (final obj in terrainGroup.objects) {
    final type = TerrainType.fromString(obj.type);
    // Rechteck-Mittelpunkt in Hex-Koordinaten umrechnen
    final centerX = obj.x + obj.width / 2;
    final centerY = obj.y + obj.height / 2;
    final hex = hexGrid.pixelToHex(Offset(centerX, centerY));
    result[hexGrid.hexKey(hex.x, hex.y)] = type;
  }
  return result;
}
```

**Verbesserungsidee für die Zukunft**: Statt nur Mittelpunkt zu nehmen, könnte man über alle Hex-Felder im Rechteck iterieren (`for (x in 0..width/ tileWidth) for (y in 0..height/tileHeight)`). Das ist aber teurer.

---

#### 3.3 Bewegungskosten — Integration in `ObjectToken` & Pfadfindung

**Aktuelle Situation**: `ObjectToken.movementValue` ist die maximale Bewegung in Hex-Schritten. Es gibt keine Berücksichtigung von Geländekosten.

**Verbesserung**: `movementValue` bleibt die Roh-Bewegungspunkte. Eine neue berechnete Größe modelliert die **effektive Bewegung**:

```dart
// In ObjectToken:
/// Berechnet die effektive Bewegungsreichweite unter Berücksichtigung
/// der Geländekosten auf dem gegebenen Terrain.
/// [terrainMap] ist die Terrain-Lookup-Map (hexKey → TerrainType).
/// [terrainConfigs] definiert die Kosten pro TerrainType.
int effectiveMovementRange(
  Map<int, TerrainType> terrainMap,
  Map<TerrainType, TerrainConfig> terrainConfigs,
  HexGrid hexGrid,
  int currentX,
  int currentY,
) {
  // BFS/Pathfinding über Nachbarn, summiere Kosten
  // bis movementValue ausgeschöpft ist.
  return _bfsMaxReachable(
    startX: currentX,
    startY: currentY,
    maxMovement: movementValue,
    terrainMap: terrainMap,
    terrainConfigs: terrainConfigs,
    hexGrid: hexGrid,
  );
}
```

**Wichtige Prinzipien**:
1. **Separation of Concerns**: `ObjectToken` speichert nur den Rohwert. Die Geländekosten werden vom Terrain-System berechnet.
2. **BFS statt Dijkstra**: Da alle Bewegungskosten ganzzahlige Multiplikatoren sind (1×, 2×, 3×), reicht ein einfacher BFS, der pro Feld die kumulierten Kosten tracked.
3. **Keine Mutation**: `terrainMap` und `terrainConfigs` sind immutable — sie werden von `MapData` bereitgestellt.

---

#### 3.4 Sichtbarkeitsregeln (Line-of-Sight)

**Anforderung**: Bestimmen, ob ein Angreifer auf Hex A ein Ziel auf Hex B sehen kann.

**Algorithmus**: **Digitale Differenzialanalyse (DDA)** auf dem Hex-Gitter — eine angepasste Version von Bresenham:

```dart
/// Prüft, ob eine Sichtlinie zwischen zwei Hex-Feldern (x1,y1) und (x2,y2)
/// existiert.
///
/// Gibt `true` zurück, wenn alle Hex-Felder auf der Linie *keine*
/// Sichtblockade haben (gemäß [terrainConfigs]).
/// Gibt `false` zurück, wenn ein Feld mit `blocksVision == true` auf der Linie liegt.
bool hasLineOfSight({
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required Map<int, TerrainType> terrainMap,
  required Map<TerrainType, TerrainConfig> terrainConfigs,
  required HexGrid hexGrid,
}) {
  // Cube-Koordinaten für die Linie
  final cube1 = HexGrid.offsetToCube(x1, y1);
  final cube2 = HexGrid.offsetToCube(x2, y2);
  final steps = hexGrid.distance(x1: x1, y1: y1, x2: x2, y2: y2);

  if (steps <= 1) return true; // Direkte Nachbarn sind immer sichtbar

  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    final cubeX = cube1.x + (cube2.x - cube1.x) * t;
    final cubeZ = cube1.z + (cube2.z - cube1.z) * t;
    final cubeY = -cubeX - cubeZ;

    // Cube → Offset (abgerundet)
    final qx = cubeX.round();
    final qy = cubeZ.round();
    final qz = cubeY.round();

    // Validierung: muss auf dem Hex-Gitter liegen
    if (qx + qy + qz != 0) continue;

    // Cube → Offset-Koordinaten
    final offsetX = qx + (qy & ~1) ~/ 2;
    final offsetY = qz;

    final terrainType = terrainMap[hexGrid.hexKey(offsetX, offsetY)] ?? TerrainType.normal;
    final config = terrainConfigs[terrainType] ?? TerrainConfig.defaults[terrainType]!;
    if (config.blocksVision) return false;
  }

  return true;
}
```

Wie würde das Ganze aussehen, wenn zusätzlich noch eine Fog Of War Mechanik eingebaut wird? Also wenn alle Units eine Sichtweite in Feldern hätten, z.B. in Gestalt einer Variable namens "field_of_view" in der Basisklasse aller Tokens "object_token.dart"?

**Optimierung**: Für häufige LoS-Prüfungen könnten Ergebnisse in einer Lookup-Tabelle (`Map<(int, int, int, int), bool>`) gecached werden (z. B. `_losCache` im Combat-System). Bei Änderung der Geländekarte wird der Cache invalidiert.



---

#### 3.5 Kollisions-Tiles — Verbesserung des bestehenden Systems

**Aktueller Stand**: `WidgetMapLoader` hat `collisionLayerName = 'collision'`. Im Painter wird dieser Layer **nicht gezeichnet** — die Logik, was damit passiert, fehlt.

**Verbesserung**: `MapData` bekommt einen berechneten `collisionSet`:

```dart
// In MapData — nach dem Parsen berechnet:
late final Set<int> collisionTiles; // hexKey(x, y) für blockierte Felder

Set<int> computeCollisionTiles(String collisionLayerName) {
  final collided = <int>{};
  for (final layer in layers) {
    if (layer.name != collisionLayerName) continue;
    for (int y = 0; y < layer.height; y++) {
      for (int x = 0; x < layer.width; x++) {
        if (layer.tileAt(x, y) != 0) {
          collided.add(HexGrid.hexKey(x, y)); // ⚠️ Braucht mapWidth
        }
      }
    }
  }
  return collided;
}
```

**⚠️ Achtung**: `HexGrid.hexKey(x, y)` benötigt `mapWidth`. Entweder in `MapData` eine `hexKey`-Methode anbieten, oder `HexGrid` aus dem `utils`-Modul importieren. Besser: `MapData` bekommt eine Hilfsmethode:

```dart
int hexKey(int x, int y) => y * width + x;
```

**Integration mit `HexGrid.buildOccupiedHexFields`**:

```dart
// Statt nur Token-Positionen zu tracken, jetzt auch Kollisions-Tiles:
Set<int> buildAllBlockedFields({
  required MapData mapData,
  required String collisionLayerName,
  required Iterable<ObjectToken> tokens,
  ObjectToken? excludeToken,
  required HexGrid hexGrid,
}) {
  final blocked = hexGrid.buildOccupiedHexFields(tokens, excludeToken: excludeToken);
  blocked.addAll(mapData.computeCollisionTiles(collisionLayerName));
  return blocked;
}
```

---

#### 3.6 Laden & Integration — Änderungen in `widget_map_loader.dart`

Im `_loadMap()`-Flow nach dem Parsen:

```dart
// 1. Terrain aus "Gelaendetypen"-Objektgruppe parsen
final terrainGroup = mapData.objectGroups
    .where((g) => g.name == 'Gelaendetypen')
    .firstOrNull;
final terrainMap = parseTerrain(terrainGroup, widget.hexGrid);

// 2. Kollisions-Set berechnen
final collisionSet = mapData.computeCollisionTiles(
  widget.config.collisionLayerName ?? 'collision',
);

// 3. Beides an die Painter/Callback übergeben
widget.onTerrainParsed?.call(terrainMap, collisionSet);
```

**Neuer Callback in `WidgetMapLoader`**:

```dart
final void Function(
  Map<int, TerrainType> terrainMap,
  Set<int> collisionSet,
)? onTerrainParsed;
```

---

#### 3.7 Refactoring-Potenzial: TerrainService

Falls das Terrain-System komplexer wird (dynamische Geländeeffekte, Wetter, Buffs), sollte eine dedizierte `TerrainService`-Klasse ausgelagert werden:

```dart
/// Zentraler Service für alle Gelände-bezogenen Abfragen.
///
/// - Verwaltet die Terrain-Map (hexKey → TerrainType)
/// - Stellt Bewegungskosten-Berechnung bereit
/// - Führt LoS-Prüfungen durch
/// - Trackt Kollisions-Felder
class TerrainService {
  final Map<int, TerrainType> _terrainMap;
  final Map<TerrainType, TerrainConfig> _configs;
  final Set<int> _collisionSet;
  final HexGrid _hexGrid;

  const TerrainService({
    required Map<int, TerrainType> terrainMap,
    required Map<TerrainType, TerrainConfig> configs,
    required Set<int> collisionSet,
    required HexGrid hexGrid,
  }) : _terrainMap = terrainMap,
       _configs = configs,
       _collisionSet = collisionSet,
       _hexGrid = hexGrid;

  TerrainConfig configAt(int x, int y) {
    final type = _terrainMap[_hexGrid.hexKey(x, y)] ?? TerrainType.normal;
    return _configs[type] ?? TerrainConfig.defaults[type]!;
  }

  bool isPassable(int x, int y, {Set<int>? occupied}) {
    if (occupied?.contains(_hexGrid.hexKey(x, y)) ?? false) return false;
    if (_collisionSet.contains(_hexGrid.hexKey(x, y))) return false;
    return !configAt(x, y).impassable;
  }

  bool hasLineOfSight(int x1, int y1, int x2, int y2) { /* s.o. */ }

  int effectiveMovementRange(ObjectToken token, int x, int y) { /* BFS */ }
}
```

---

#### 3.8 Checkliste der Implementierung

> **Status**: Alle Sektionen implementiert. Siehe unten für Details.

- [x] `(3.1)` `TerrainType`-Enum und `TerrainConfig`-Klasse in `map_data.dart` anlegen
- [x] `(3.2)` `terrain`-Map (`Map<int, TerrainType>`) in `MapData` hinzufügen
- [x] `(3.2)` `parseTerrain()`-Funktion in `lib/services/terrain_service.dart` (wird von `WidgetMapLoader._loadMap()` aufgerufen)
- [x] `(3.3)` Bewegungskosten-BFS (`effectiveMovementRange` + `reachableHexes`) in `TerrainService`
- [x] `(3.4)` Line-of-Sight-Prüfung (`hasLineOfSight` in `FogOfWarService`, Cube-DDA mit Cache)
- [x] `(3.5)` `computeCollisionTiles()` in `MapData` + `buildAllBlockedFields()` in `terrain_service.dart`
- [x] `(3.6)` `onTerrainParsed`-Callback in `WidgetMapLoader` + Integration in `_loadMap()`
- [x] `(3.7)` `TerrainService`-Klasse als zentrale Fassade in `lib/services/terrain_service.dart`
- [x] `(3.12)` Fog of War (`FogOfWarService` in `lib/services/fog_of_war.dart`)

---

#### 3.9 Design-Entscheidungen (ADRs)

| # | Entscheidung | Alternative | Begründung |
|---|-------------|-------------|------------|
| 1 | `terrain` als `Map<int, TerrainType>` | 2D-Array `List<List<TerrainType>>` | Speicher-effizienter (Default = `normal` muss nicht gespeichert werden), einfachere Lookups mit `hexKey` |
| 2 | `TerrainConfig` als `@immutable` | Mutable Klasse | Thread-Sicherheit, unerwartete Mutationen ausgeschlossen |
| 3 | `movementCostMultiplier` als `double` | `int` für Festkomma | Flexibler bei zukünftigen Werten (1.25, 2.5, etc.) |
| 4 | Cube-Koordinaten für LoS | Pixel-basierte Raycasting | Genauer auf hex-Gitter, keine Rundungsfehler durch Pixel→Hex Rückkonvertierung |
| 5 | `impassable` als separates Flag | `movementCostMultiplier == 0` | Vermeidet Division-by-Zero und verbessert Lesbarkeit |

---

#### 3.10 Edge Cases & Fallstricke

1. **Tile-ID = 0**: Bedeutet "leeres Tile". Kollisions-Layer darf das nicht als blockiert werten.
2. **Überlappende Geländetypen**: Wenn sich Rechtecke in der Objektgruppe überlappen, gewinnt das zuletzt geparste Objekt. In der Praxis sollten sich Geländetypen nicht überlappen. Optional: Warnung per `debugPrint`.
3. **`movementValue = 0`: Einheiten, die sich nicht bewegen können (stationäre Türme). BFS muss diesen Fall korrekt behandeln (0 Schritte → nur Startfeld).
4. **Sichtlinie durch das eigene Feld**: Das Startfeld eines Angreifers sollte nie die Sicht blockieren (auch wenn es `blocksVision` hat).
5. **Leere `"Gelaendetypen"`-Objektgruppe**: Parser muss damit umgehen können → leere `terrain`-Map.
6. **Performance**: Bei großen Karten (100×100 = 10.000 Hex-Felder) kann eine vollständige BFS pro Einheit teuer sein. Caching der Bewegungskosten pro Runde empfiehlt sich.

---

#### 3.11 Tests

```dart
// Test-Ideen (Datei: test/terrain_system_test.dart)
void main() {
  group('TerrainConfig defaults', () {
    test('normal terrain has movementCostMultiplier 1.0 and does not block vision');
    test('ruin terrain has movementCostMultiplier 2.0 and blocks vision');
    test('water is impassable');
  });

  group('parseTerrain', () {
    test('parses object group with multiple terrain rectangles');
    test('returns empty map for empty object group');
    test('handles overlapping rectangles (last wins)');
  });

  group('hasLineOfSight', () {
    test('direct neighbors are always visible');
    test('wall blocks line of sight');
    test('open field allows line of sight at any distance');
    test('start field blocksVision does not affect line of sight');
  });

  group('effectiveMovementRange (BFS)', () {
    test('normal terrain: range == movementValue');
    test('ruin terrain halves range');
    test('impassable terrain blocks movement');
    test('zero movement value stays on start hex');
  });
}

---

#### 3.12 Fog of War (Nebel des Krieges)

> **Status**: Implementiert in `lib/services/fog_of_war.dart`.
> **Abhängigkeiten**: `3.4` (Line-of-Sight via Cube-DDA), `3.1` (TerrainType, TerrainConfig), `1_Zentralisierte_hex_utility.md` (HexGrid)

**Anforderung**: Einheiten haben eine Sichtweite in Hex-Feldern (`fieldOfView` in der Basisklasse `ObjectToken`). Felder, die von keiner freundlichen Einheit gesehen werden, sind im Nebel des Krieges verborgen.

---

##### 3.12.1 Datenmodell — `ObjectToken.fieldOfView`

In `ObjectToken` wurde eine neue Eigenschaft ergänzt:

```dart
/// Sichtweite in Hex-Feldern für Fog of War.
///
/// Gibt an, wie viele Hex-Felder weit dieser Token sehen kann.
/// 0 bedeutet: der Token sieht nur sein eigenes Feld.
/// Dieser Wert wird von [FogOfWarService] verwendet, um die
/// aktuell sichtbaren Felder zu berechnen.
int fieldOfView;
```

- Default-Wert: `3` (im Konstruktor)
- Wird in `copyWith()` berücksichtigt
- Gilt für alle Token-Typen (Spieler, Zombies, Bosse)

---

##### 3.12.2 `FogOfWarService` — Zentrale Klasse

**Datei**: `lib/services/fog_of_war.dart`

**Zwei Sichtbarkeitsebenen:**

| Ebene | Beschreibung | Lebensdauer |
|-------|-------------|-------------|
| `visibleHexes` | Aktuell sichtbare Felder | Wird pro Runde neu berechnet |
| `revealedHexes` | Jemals gesehene Felder | Kumulativ, nie kleiner |

**Öffentliche API:**

```dart
class FogOfWarService {
  /// Berechnet die Sichtbarkeit für die aktuelle Runde neu.
  void computeVisibility({
    required Iterable<ObjectToken> friendlyTokens,
    required Map<int, TerrainType> terrainMap,
    required Map<TerrainType, TerrainConfig> terrainConfigs,
  });

  /// Setzt den gesamten Fog-of-War-Zustand zurück (neue Karte).
  void reset();

  /// Ist das Feld aktuell sichtbar?
  bool isVisible(int hexKey);

  /// Wurde das Feld jemals aufgedeckt?
  bool isRevealed(int hexKey);

  /// Alle gegnerischen Tokens auf sichtbaren Feldern.
  List<ObjectToken> getVisibleEnemies(Iterable<ObjectToken> enemyTokens);
}
```

---

##### 3.12.3 Algorithmus

Der Sichtbarkeits-Algorithmus pro Token:

```
1. Start-Hex des Tokens ist immer sichtbar.
2. BFS erkundet benachbarte Hex-Felder bis zur fieldOfView-Distanz.
3. Für jedes Kandidaten-Hex: hasLineOfSight() (Cube-DDA aus §3.4)
4. Nur bei freier Sichtlinie:
   a) Hex als sichtbar markieren
   b) Wenn das Hex selbst blocksVision == false → Propagation fortsetzen
   c) Wenn blocksVision == true → Hex sichtbar, aber dahinter nicht erkunden
5. Aggregation: visibleHexes = Union aller Token-Sichtbarkeit
6. revealedHexes += visibleHexes
```

**Wichtige Eigenschaften:**

- **Sichtbarrieren**: Ein Feld mit `blocksVision: true` (z. B. Mauer, Ruine) blockiert die Sicht. Das Feld selbst ist noch sichtbar, aber dahinterliegende Felder nicht.
- **Startfeld**: Das Feld, auf dem der Token steht, blockiert nie die Sicht (es wird vor der LoS-Prüfung markiert).
- **Tote Token**: Ein Token mit `woundValue <= 0` trägt nicht zur Sicht bei.
- **`fieldOfView = 0`**: Der Token sieht nur sein eigenes Feld (z. B. stationäre Türme).
- **`fieldOfView = 1`**: Token sieht eigenes Feld + alle direkten Nachbarn.

---

##### 3.12.4 LoS-Caching

Für die Performance werden LoS-Ergebnisse innerhalb eines `computeVisibility()`-Durchlaufs gecached:

```dart
final Map<(int, int, int, int), bool> _losCache = {};
```

- **Schlüssel**: `(x1, y1, x2, y2)` — die beiden Hex-Koordinaten
- **Symmetrie-Ausnutzung**: LoS von A→B ist identisch mit LoS von B→A. Wird `(x2,y2,x1,y1)` gefunden, wird das Ergebnis auch für `(x1,y1,x2,y2)` verwendet.
- **Invalidierung**: Der Cache wird bei jedem `computeVisibility()`-Aufruf geleert, da sich die Terrain-Map zwischen Runden ändern kann (z. B. durch zerstörbare Wände).

---

##### 3.12.5 Integration in `ObjectPlayer` / Host

**Pro Runde** (z. B. zu Beginn des Spieler-Zugs):

```dart
fogOfWar.computeVisibility(
  friendlyTokens: player.unitList,   // Nur Spieler-Einheiten
  terrainMap: terrainMap,            // Aus MapData
  terrainConfigs: TerrainConfig.defaults,
);
```

**Für gegnerische Sicht** (KI):

```dart
// Host berechnet Sicht für seine Zombies
hostFogOfWar.computeVisibility(
  friendlyTokens: hostUnits,         // Zombies + Dumpster
  terrainMap: terrainMap,
  terrainConfigs: TerrainConfig.defaults,
);
```

**Im UI** (CustomPainter):

```dart
for (int y = 0; y < mapHeight; y++) {
  for (int x = 0; x < mapWidth; x++) {
    final key = hexGrid.hexKey(x, y);
    if (fogOfWar.isVisible(key)) {
      // Zeichne hell/normal
    } else if (fogOfWar.isRevealed(key)) {
      // Zeichne abgedunkelt (grau/transparent)
    } else {
      // Zeichne schwarz (unerforscht)
    }
  }
}
```

---

##### 3.12.6 Edge Cases & Fallstricke

1. **feldOfView = 0**: Nur das eigene Feld sichtbar → BFS wird sofort beendet.
2. **Tote Tokens**: `woundValue <= 0` → werden in `computeVisibility()` übersprungen.
3. **Token außerhalb der Karte**: `pixelToHex()` clamped automatisch auf `mapWidth`/`mapHeight`.
4. **Sicht durch Sichtbarrieren**: `blocksVision` blockiert die BFS-Propagation, sodass hinter der Barriere nichts sichtbar ist.
5. **Multiple Tokens**: Überlappende Sichtbereiche werden vereinigt (Set-Union).
6. **Rundenübergreifende Sicht**: `revealedHexes` bleibt erhalten, `visibleHexes` wird neu berechnet.
7. **Performance bei vielen Tokens**: Der LoS-Cache verhindert mehrfache Berechnungen zwischen denselben Hex-Paaren.

---

##### 3.12.7 Design-Entscheidungen (ADRs)

| # | Entscheidung | Alternative | Begründung |
|---|-------------|-------------|------------|
| 1 | Zwei Ebenen (visible + revealed) | Nur eine Ebene (current) | Erlaubt "Fog of War" vs. "Fog of Exploration" — aufgedeckte Karte bleibt sichtbar |
| 2 | BFS + LoS-Validierung | Nur Distanz-basiert | Verhindert "X-ray vision" durch Wände — realistischer |
| 3 | `hasLineOfSight` aus §3.4 integriert | Separate LoS-Klasse | Wiederverwendung des bestehenden Cube-DDA-Algorithmus |
| 4 | LoS-Cache pro Durchlauf | Globaler Cache | Einfacher zu invalidieren; keine Stale-State-Probleme |

---

##### 3.12.8 Checkliste der Implementierung

- [x] `(3.12.1)` `fieldOfView` in `ObjectToken` ergänzt (Default: 3)
- [x] `(3.12.2)` `FogOfWarService` in `lib/services/fog_of_war.dart` angelegt
- [x] `(3.12.3)` BFS-Sichtbarkeitsalgorithmus in `_computeTokenVisibility()`
- [x] `(3.12.4)` LoS-Cache mit Symmetrie-Ausnutzung
- [x] `(3.12.5)` `getVisibleEnemies()` für gegnerische Token-Filterung
- [x] `(3.6)` `TerrainType`/`TerrainConfig` in `map_data.dart` angelegt (Grundlage)

---

##### 3.12.9 Beispiel: Sichtberechnung für einen Token

Gegeben:
- Karte 10×10 Hex-Felder
- Token bei (5, 5) mit `fieldOfView = 3`
- Eine Mauer (`wall`, `blocksVision: true`) bei (5, 7)

Ergebnis:
- Token sieht alle Felder im Radius 3, *außer* Felder hinter der Mauer bei (5, 7).
- Das Feld (5, 7) selbst (die Mauer) ist sichtbar.
- Feld (5, 8) ist **nicht** sichtbar, da die Mauer die Sicht blockiert.
- Feld (4, 6) ist sichtbar, da es nicht hinter der Mauer liegt.

```
Legende:  T = Token, M = Mauer, v = sichtbar, . = unsichtbar

    Spalte:  3  4  5  6  7
  Zeile 3:   .  v  v  v  .
  Zeile 4:   v  v  v  v  v
  Zeile 5:   v  v  T  v  v
  Zeile 6:   v  v  v  v  v
  Zeile 7:   .  v  M  v  .
  Zeile 8:   .  .  .  .  .     ← Mauer blockiert Sicht auf (5,8)
```
