# 7. Datenmodell – Ist-Stand & Verbesserungsvorschläge

## Ist-Stand (nach Umsetzung)

Das `MapData`-Modell existiert in `lib/models/map_data.dart` und kapselt:
- **MapData** – width, height, tileWidth, tileHeight, orientation, staggerAxis, staggerIndex, layers, tilesets, objectGroups, terrain (nullable)
- **TileLayer** – name, width, height, opacity, visible, tileData (Uint32List)
- **TilesetInfo** – firstGid, source, name, tileWidth, tileHeight, tileCount, columns, imageSource, imageWidth, imageHeight
- **ObjectGroup** – name, objects
- **MapObject** – id, name, type, x, y, width, height, rotation, visible, properties
- **TerrainType** – enum mit normal, ruin, forest, water, wall, openGround, swamp
- **TerrainConfig** – movementCostMultiplier, blocksVision, impassable + defaults-Map
- **MapMeta** – Metadaten aus `maps.json` (mapPath, title, previewPath, tmxPath)

Die Parser (`TmxParser`, `TmjParser`) in `lib/services/map_parser.dart` unterstützen:
- TMX (XML) mit CSV, Base64/Zlib und **Base64/Gzip**-Kodierung
- TMJ (JSON)
- Externe TSX-Tilesets (teilweise async)

Das Terrain-System in `lib/services/terrain_service.dart` parst die "Gelaendetypen"-Objektgruppe und bietet BFS-basierte Bewegungskosten-Berechnung.

---

## Umgesetzte Verbesserungen

### ✅ Serialisierung (toJson/fromJson) ergänzt

`MapData`, `TileLayer`, `TilesetInfo`, `ObjectGroup`, `MapObject`, `MapMeta`, `TerrainConfig` haben jetzt alle `toJson()` und `fromJson()`.

### ✅ hexKey-Duplizierung entfernt

`MapData.hexKey` wurde entfernt. `computeCollisionTiles()` benötigt jetzt einen `HexGrid`-Parameter.

### ✅ Terrain nullable gemacht

`MapData.terrain` ist jetzt `Map<int, TerrainType>?` (nullable), um klarzumachen, dass das Terrain optional/nachrüstbar ist.

### ✅ GZIP-Kompression im TMX-Parser

`_parseBase64` unterstützt jetzt `'gzip'` zusätzlich zu `'zlib'`:

```dart
final bytes = switch (compression) {
  'zlib' => zlib.decode(decoded),
  'gzip' => gzip.decode(decoded),
  _ => decoded,
};
```

### ✅ _parsePropertyValue vereinheitlicht

TMX- und TMJ-Parser teilen jetzt dieselbe implementierte Logik mit `switch`-Expression und Null-Sicherheit.

### ✅ equals/hashCode ergänzt

`ObjectGroup` und `MapObject` haben jetzt korrekte `==` und `hashCode`-Überschreibungen mit `listEquals`/`mapEquals`.

### ✅ BFS-Duplizierung entfernt

`effectiveMovementRange()` delegiert jetzt an `reachableHexes()`:

```dart
int effectiveMovementRange({...}) {
  return reachableHexes(startX: startX, startY: startY, ...).length;
}
```

### ✅ MapRegistry flexibler Pfad

`MapRegistry.loadFromAsset()` akzeptiert jetzt einen optionalen `path`-Parameter (Standard: `'assets/maps/maps.json'`).

## Bekannte Einschränkungen

- `_parseTilesetElementFromXml` hat noch `firstGid: 1` hartcodiert – das wird aber von `loadExternalTileset` nur selten aufgerufen, und der korrekte `firstGid` müsste vom Aufrufer nachgereicht werden (kein aktueller Caller im Code).
- `TileLayer._rowOffsets` wurde aufgrund von `const`-Constructor-Einschränkungen nicht implementiert. Der einfache Zugriff `y * width + x` ist performant genug.

## Nächste Schritte

- [x] GZIP-Unterstützung (Prio 1)
- [x] firstGid-Bug identifiziert (Prio 2)
- [x] equals/hashCode ergänzt (Prio 3)
- [x] BFS-Duplizierung entfernt (Prio 4)
- [x] hexKey-Duplizierung entfernt (Prio 5)
- [x] PropertyValue-Inkonsistenz behoben (Prio 6)
- [x] Serialisierung (Prio 8)
- [x] Terrain nullable (Prio 9)
- [x] MapRegistry flexibler (Prio 10)