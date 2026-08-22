# Aktueller Stand: Map-System

## Intro
Unser bisheriges Laden und der Aufbau der Map ist noch recht rudimentär. Es wird zwar eine tmx Datei geladen und interpretiert, aber es fehlen noch jede Menge Dinge. Dies soll sich ändern, daher ist es zuerst praktisch zu wissen, wie der aktuelle Stand gerade ist, sowohl laut Dokumentation, wie auch tatsächlich.

## Stand

### 1. Ladevorgang
**Aktuelle Implementierung** (`widgets/widget_map_loader.dart`):
- Eine einzelne `.tmx`-Datei wird geladen (Default: `assets/maps/map0/street_battle.tmx`)
- Parsen per XML-Parser (`package:xml`)
- CSV-kodierte Tile-Daten werden als 2D-Liste (`List<List<int>>`) interpretiert
- Das Tileset wird aus einer referenzierten `.tsx`-Datei geladen (Pfad relativ zum TMX-Verzeichnis)
- Das Tileset-Bild (`.png`) wird per `rootBundle.load()` geladen und als `ui.Image` dekodiert
- Die Karte wird als `CustomPaint`-Widget mit einem `_HexMapPainter` gezeichnet
- Fallback-Mechanismus: Falls TSX-Laden fehlschlägt, wird ein hardcodierter Bildpfad (`Thespazztikone_tilemaps_005_neu.png`) verwendet

**Datenformat** (`assets/maps/map0/street_battle.tmx`):
- 30×30 Hex-Karte (staggeraxis="y", staggerindex="odd")
- 32×32 Pixel pro Tile
- Single Layer (CSV-enkodiert, alle Tiles ID 121 → einheitlicher Grasboden)
- Tileset: 160 Tiles (16 Spalten), Bild 512×320 Pixel
- `firstgid=1` → Tile-ID 1 ist das erste Tile im Tileset → `tileId - 1` für den Index

### 2. Besondere Punkte
- **Spawnpunkte**: Werden aus der TMX-Objektgruppe `"Spawns"` geparst
  - `spawn_player1` bis `spawn_player4`: Spielerstartpositionen (Pixel-Koordinaten)
  - `spawn_monster`: Monsterstartposition
  - Spieler-Spawns werden zufällig ausgewählt, Monster-Spawns verwenden den ersten Eintrag
- **Terrain-Typen**: TMX enthält eine `"Gelaendetypen"`-Objektgruppe mit einer `"Ruine"`-Region (Rechteck 361×138 bis 597×304 Pixel). Wird jedoch im Code **nicht ausgewertet**.
- **Hex-Koordinaten**: Pixel↔Hex-Umrechnung in `widget_caretaker.dart` dupliziert die Logik aus `widget_map_loader.dart` (duplizierte Hex-Logik in `_hexToPixel()`, `_pixelToHex()`; `_HexUtils`-Klasse für Cube-Koordinaten, Distanz, Nachbarsuche)

### 3. Unterstützte Geländetypen (laut Regelwerk)
- Derzeit: **nur normales Terrain** (einheitliches Gras-Tile 121)
- Die `"Gelaendetypen"`-Objektgruppe wird zwar in der TMX definiert, aber im Code nicht verarbeitet
- Es gibt keine Kollisionserkennung für Gelände (keine blockierten Tiles)
- Keine Bewegungskosten pro Geländetyp

### 4. Erkannte Probleme & Lücken

#### a) Mehrere Karten / Kartenauswahl
- `assets/maps/maps.json` definiert ein Kartenverzeichnis, wird aber **nirgends im Code verwendet**
- Keine Kartenauswahl im UI (ScreenMain hat hardcodierten mapPath)
- Es existiert nur eine Karte (`map0`)

#### b) Hex-Geometrie dupliziert
- `_hexToPixel()` existiert sowohl in `WidgetMapLoader` (Zeile 298-302) als auch in `WidgetCaretaker` (Zeile 688-698)
- `_pixelToHex()` existiert in `WidgetCaretaker` (Zeile 707-726), aber nicht im Map-Loader
- Keine zentrale Utility-Klasse für Hex-Operationen → bei Änderungen müssen beide Stellen angepasst werden

#### c) Eingeschränktes TMX-Parsing
- Nur CSV-Encoding unterstützt (kein Base64, kein Zlib-komprimiert)
- Nur **ein** Layer wird unterstützt (`.findElements('layer').first`)
- Nur **ein** Tileset wird unterstützt (`.findElements('tileset').first`)
- Keine Unterstützung für TMJ (JSON-Format von Tiled)
- Objektgruppen werden nur für Spawns und hartcodierten Namen `"Spawns"` ausgewertet

#### d) Fehlende Terrain-Verarbeitung
- Terrain-Objektgruppe (`"Gelaendetypen"`) wird nicht verarbeitet
- Keine Bewegungskostenmodifikation durch Gelände
- Keine Sichtbarkeitsmodifikation durch Gelände (z. B. Ruinen blockieren Sichtlinie)
- Keine Kollisions-Tiles (Tile-IDs, die nicht betreten werden können)

#### e) Tileset-Fallback ist unsauber
- `catch (_)` beim TSX-Laden fängt **alle** Fehler, auch echte Programmierfehler (z. B. NullPointerExceptions)
- Fallback-Bildpfad ist hardcodiert statt aus der TMX-Konfiguration

#### f) Performance-Optimierung fehlt
- `_HexMapPainter.paint()` malt jedes Tile einzeln, auch außerhalb des sichtbaren Bereichs (kein Viewport-Culling)
- `shouldRepaint()` prüft nur Referenzidentität von `tilesetImage` und `tileData` → bei neu geladener Karte wird immer neu gemalt
- Kein Flutter-`RepaintBoundary` um die Karte → jedes SetState im Elternwidget löst Neuzeichnen aus

## Verbesserungen (Vorschläge)

### 1. Zentralisierte Hex-Utility
Eine gemeinsame Utility-Klasse für alle Hex-Konvertierungen (`pixelToHex`, `hexToPixel`, `neighborOffsets`, `distance`, `hexKey`) – entfernt die Duplizierung zwischen `WidgetMapLoader` und `WidgetCaretaker`.

### 2. Robusteres TMX-Parsing
- Unterstützung für Base64- und Zlib-kodierte Layer-Daten
- Unterstützung für mehrere Layer (z. B. Boden + Dekoration + Kollision)
- Unterstützung für mehrere Tilesets pro Karte (mit korrektem firstgid-Mapping)
- Unterstützung für TMJ (JSON-Format)
- Objektgruppen generisch parsen und per Konfiguration auswerten

### 3. Terrain-System
- Auswerten der `"Gelaendetypen"`-Objektgruppe zur Laufzeit
- Definieren von Bewegungskosten pro Geländetyp (z. B. Ruine = doppelte Kosten)
- Definieren von Sichtbarkeitsregeln pro Geländetyp (deckt Ruinen Sicht?)
- Kollisions-Tiles (Tile-IDs in der TMX, die blockieren)

### 4. Kartenauswahl
- `maps.json` im Code auslesen und im UI eine Kartenauswahl anbieten
- Vorschaubilder für Karten (`previewPath` unterstützen)

### 5. Performance
- Viewport-Culling im `_HexMapPainter`: nur Tiles im sichtbaren Bereich zeichnen
- `RepaintBoundary` um die Karte setzen
- Optional: Einsatz von `Canvas.saveLayer()` / `Canvas.clipRect()` für effizienteres Zeichnen

### 6. Fehlerbehandlung
- Spezifische Exceptions fangen statt `catch (_)` (z. B. `FormatException`, `LoadException`)
- Fallback-Pfad aus der TMX-Konfiguration ableiten statt hardcodiert

### 7. Datenmodell
- Ein `MapData`-Modell erstellen, das alle Karteninformationen kapselt (Tiles, Layer, Tilesets, Objektgruppen, Terrain-Typen)
- Serialisierung/Deserialisierung für mehrere Formate (TMX, TMJ)

### 8. Tile-Layer-System
- Unterstützung für mehrere Layer (Boden-Ebene, Dekorations-Ebene, Kollisions-Ebene)
- Jeder Layer kann eigene Tiles haben
- Layer können für bestimmte Zwecke markiert werden (z. B. "collision", "terrain", "decorative")