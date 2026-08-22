# 8. Tile-Layer-System ✅ Implementiert

## Umsetzung (Juli 2026)

### Typisiertes Layer-System (`lib/models/map_data.dart`)

Neuer `LayerPurpose`-Enum mit sechs Werten:
- `ground` – Boden-Ebene
- `collision` – Kollisions-Ebene
- `decorative` – Dekorations-Ebene
- `decorativeUpper` – Obere Dekorations-Ebene
- `terrain` – Gelände-Ebene
- `unknown` – Fallback für unbekannte Layer

**Features:**
- ✅ Unterstützung für mehrere Layer (Boden-, Dekorations-, Kollisions-Ebene)
- ✅ Jeder Layer kann eigene Tiles haben (via `TileLayer.tileData`)
- ✅ Layer können für bestimmte Zwecke markiert werden (via `LayerPurpose`)
- ✅ Automatische Zuordnung: Layer-Name → Purpose via `LayerPurpose.fromLayerName()`
- ✅ Standard-Namenszuordnung in `LayerPurpose.defaultLayerNames`
- ✅ `TileLayer.purpose` – typsicherer Lookup, cached beim ersten Zugriff

### Effiziente Layer-Lookups (O(1))

- `MapData._layerIndexByName` – vorberechneter `Map<String, int>`-Index
- `MapData.layerByName(name)` – O(1)-Lookup über den Index
- `MapData.layerByPurpose(purpose)` – O(1)-Lookup über Purpose
- `MapData.layerByPurposeWithMapping()` – Lookup mit benutzerdefinierter Namenszuordnung

### Refaktorierte Kollisionsberechnung

- `MapData.computeCollisionTiles(hexGrid)` – verwendet now `layerByPurpose(LayerPurpose.collision)`
- Alte Signatur `computeCollisionTiles(String, HexGrid)` als `@Deprecated` erhalten
- Neue Methode: `computeCollisionTilesByName()` für benannte Layer (Rückwärtskompatibilität)

### Verbesserungen am TileLayer

- `TileLayer.isEmpty` – Property für schnelle Prüfung auf leere Layer
- `TileLayer.copyWith()` – Factory für Layer-Transformationen
- `TileLayer.purpose` – typsicherer Purpose, berechnet beim ersten Zugriff

### Optimierungen im `_HexMapPainter`

- `_drawLayer()` verwendet jetzt `mapData.layerByName(layerName)` (O(1) statt O(n))
- `shouldRepaint()` prüft zusätzlich `TileLayer.purpose`-Änderungen

### Änderungen im `terrain_service.dart`

- `buildAllBlockedFields()` verwendet die neue `computeCollisionTiles(hexGrid)`-Signatur
- Der `collisionLayerName`-Parameter bleibt für Rückwärtskompatibilität erhalten

### Dateien

| Datei | Änderung |
|-------|----------|
| `lib/models/map_data.dart` | + `LayerPurpose`-Enum, + O(1)-Layer-Index, + neue Lookup-Methoden |
| `lib/widgets/widget_map_loader.dart` | Verwendet `layerByName()` und neue `computeCollisionTiles()`-Signatur |
| `lib/services/terrain_service.dart` | Aktualisierter Aufruf von `computeCollisionTiles()` |