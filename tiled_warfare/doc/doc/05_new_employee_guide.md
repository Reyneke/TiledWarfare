# Leitfaden für neue Mitarbeiter

## Willkommen bei Tiled Warfare!

Dieses Dokument hilft dir, dich schnell im Projekt zurechtzufinden. Es ist als schrittweiser Einstieg konzipiert – lies es der Reihe nach.

---

## 1. Erste Schritte

### 1.1 Projekt klonen & ausführen

```bash
git clone https://github.com/Reyneke/TiledWarfare.git
cd tiled_warfare
flutter pub get
flutter run
```

**Voraussetzungen:**
- Flutter SDK (aktuelle stabile Version)
- Dart SDK
- Ein Emulator oder physisches Gerät

### 1.2 Projektstruktur verstehen

Das Projekt folgt einer einfachen Struktur:

```
lib/               → Quellcode
  main.dart        ← HIER STARTET DIE APP
  main_app.dart    ← Root-Widget
  models/          ← Datenmodelle (MapData, TileLayer, TerrainType, etc.)
  services/        ← Dienste (Parser, TerrainService, FogOfWarService, etc.)
  screens/         ← Bildschirme
  widgets/         ← Wieder-verwendbare UI-Komponenten
  objects/         ← Spiel-Logik (Modelle)
  utils/           ← Hilfsfunktionen (HexGrid)
  theme/           ← Design-System
  fuzzy_logic/     ← KI-Logik (Beispiele + Tests)
assets/            → Ressourcen (Bilder, Karten)
doc/               → Dokumentation
```

### 1.3 Empfohlene Lektüre-Reihenfolge

| Schritt | Datei | Warum? |
|---------|-------|--------|
| 1 | `doc/doc/00_project_overview.md` | Projekteinordnung |
| 2 | `doc/doc/04_cliffnotes.md` | Schnellüberblick |
| 3 | `lib/main.dart` + `lib/main_app.dart` | Einstiegspunkt verstehen |
| 4 | `lib/screens/screen_main.dart` | Hauptbildschirm |
| 5 | `lib/models/map_data.dart` + `lib/services/map_parser.dart` | Karten-Datenmodell & Parser |
| 6 | `lib/services/terrain_service.dart` | **Geländesystem** (TerrainService, BFS, parseTerrain) |
| 7 | `lib/services/fog_of_war.dart` | **Fog of War** (Sichtbarkeitsberechnung) |
| 8 | `lib/widgets/widget_map_loader.dart` | Karte laden & rendern (nutzt Parser) |
| 9 | `lib/utils/hex_grid.dart` | Zentrale Hex-Gitter-Berechnungen |
| 10 | `lib/objects/object_token.dart` | Basis-Klasse Token (mit fieldOfView) |
| 11 | `lib/widgets/widget_caretaker.dart` | **Spiel-Logik (größte Datei)** |
| 12 | `lib/objects/object_player.dart` | Kampfsystem |
| 13 | `lib/objects/object_host.dart` | KI-Verhalten |
| 14 | `doc/rules/combat_rules.md` | Regelwerk |

---

## 2. Architektur-Entscheidungen

### 2.1 Warum Singletons für Player und Host?

`ObjectPlayer` und `ObjectHost` sind als **Singleton** implementiert, weil es im Spiel immer genau einen Spieler und einen Host gibt. Das vereinfacht den Zugriff aus verschiedenen Widgets (z. B. WidgetCaretaker nutzt beide).

```dart
// Zugriff überall möglich:
final player = ObjectPlayer();
final host = ObjectHost();
```

### 2.2 Warum ein separates Datenmodell und Parser?

Die Karten-Daten wurden aus `WidgetMapLoader` in ein separates **Datenmodell** (`lib/models/map_data.dart`) und **Parser-Interface** (`lib/services/map_parser.dart`) ausgelagert. Vorteile:
- **Trennung von Concerns**: Parsing-Logik ist unabhängig vom Widget
- **Wiederverwendbarkeit**: Parser können ohne Widget-Kontext getestet werden
- **Erweiterbarkeit**: Neue Encodings oder Kartenformate können leicht hinzugefügt werden
- **TMJ-Support**: JSON-Format wird neben TMX (XML) unterstützt

### 2.3 Warum Callbacks statt Vererbung?

`WidgetMapLoader` gibt seine Daten (Kartendimensionen, Spawnpunkte, TransformationController, Terrain-Daten) über **Callbacks** an `ScreenMain` weiter, statt Teil einer großen Widget-Hierarchie zu sein. Das hält die Komponenten entkoppelt und testbar.

### 2.4 Warum ein CustomPainter für die Karte?

Die Hex-Karte wird mit `_HexMapPainter` (ein `CustomPainter`) gezeichnet, weil:
- Performance: Nur ein Widget statt hunderter einzelner Tile-Widgets
- Flexibilität: Direkter Zugriff auf Canvas-API für Hex-Gitter
- Einfachheit: Die Hex-Positionierung ist im Painter zentralisiert

### 2.5 Warum Viewport-Culling?

Große Karten (z. B. 30×30) können hunderte Tokens enthalten. Viewport-Culling stellt sicher, dass nur Tokens im sichtbaren Bereich gezeichnet werden. Das verbessert die Performance drastisch.

### 2.6 Warum BFS für Bewegung?

Die Bewegung verwendet **Breadth-First Search** (BFS), um:
1. Alle erreichbaren Felder innerhalb der Bewegungspunkte zu finden
2. Geländekosten (z. B. Wald 1.5×, Sumpf 3×) zu berücksichtigen
3. Belegte Felder als Hindernisse zu behandeln
4. Pfadfindung für `_snapToNearestFreeHex` zu ermöglichen

Der BFS ist im `TerrainService` als `effectiveMovementRange()` und `reachableHexes()` implementiert.

### 2.7 Warum Cube-Koordinaten für Line-of-Sight?

Line-of-Sight verwendet **Cube-Koordinaten-DDA** (angepasster Bresenham), weil:
- Genauer auf dem Hex-Gitter als Pixel-basiertes Raycasting
- Keine Rundungsfehler durch Pixel→Hex-Rückkonvertierung
- Einheitlich mit der Hex-Distanzberechnung

### 2.8 Warum zwei Ebenen für Fog of War?

Der `FogOfWarService` unterscheidet zwischen **visible** (aktuell sichtbar) und **revealed** (jemals gesehen):
- **visible**: Wird pro Runde neu berechnet, berücksichtigt Token-Bewegung
- **revealed**: Akkumuliert über Runden, bleibt dauerhaft sichtbar
- Erlaubt "Fog of War vs. Fog of Exploration" – aufgedeckte Karte bleibt sichtbar

---

## 3. Typische Aufgaben

### 3.1 Neuen Token-Typ hinzufügen

1. Neue Datei in `lib/objects/` erstellen (z. B. `object_chef.dart`)
2. Von `ObjectToken` erben:
```dart
class ObjectChef extends ObjectToken {
  ObjectChef() : super(
    name: "Chef",
    imagePath: "assets/images/token/token_chef.png",
    attackValue: 90,
    defenseValue: 50,
    movementValue: 4,
    damageValue: 3,
    rangeValue: 2,
    fieldOfView: 5, // Sichtweite in Hex-Feldern
  );
}
```
3. Token im `WidgetCaretaker` integrieren:
   - In `_initializeGameObjects()` spawnen
   - In `_allTokens` / `_buildAllTokens()` aufnehmen
   - In `_TokenWidget._getTokenColor()` und `_getTokenLabel()` Farbe/Label hinzufügen

### 3.2 Neue Karte hinzufügen

1. TMX- oder TMJ-Datei in `assets/maps/<name>/` ablegen (eigenes Unterverzeichnis pro Karte)
2. Tileset-Bild(er) in `assets/maps/<name>/` ablegen
3. Optionales Vorschaubild in `assets/maps/<name>/` ablegen (z. B. `preview.png`)
4. Eintrag in `assets/maps/maps.json` hinzufügen:
   ```json
   {
     "mapPath": "assets/maps/<name>",
     "title": "Meine Karte",
     "previewPath": "assets/maps/<name>/preview.png",
     "tmxPath": "assets/maps/<name>/meine_karte.tmx"
   }
   ```
   - `previewPath` kann `null` sein (dann wird ein Icon angezeigt)
   - `title` wird im UI für die Kartenauswahl verwendet
5. Spawnpunkte in der Kartendatei als Objectgroup "Spawns" definieren
6. **Layer-Struktur** (empfohlen für neue Karten):
   - `ground` (TileLayer) – Bodenbelag
   - `decoration` (TileLayer) – Dekoration
   - `collision` (TileLayer) – Kollisions-Tiles (optional)
   - `spawns` (ObjectGroup) – Spawnpunkte
   - `Gelaendetypen` (ObjectGroup) – Geländetypen (optional)
7. Die Layer-Namen können über `MapLoadConfig` angepasst werden
8. Über den `onTerrainParsed`-Callback von `WidgetMapLoader` werden die
   Geländedaten und das Kollisions-Set an das übergeordnete Widget übergeben
9. Die Karte erscheint automatisch im `ScreenRestaurant` – keine Code-Änderungen nötig

### 3.3 Kampfregeln ändern

1. `object_player.dart` → `performAction()` anpassen
2. `doc/rules/combat_rules.md` aktualisieren
3. Tests in `fuzzy_logic/test/` prüfen/ergänzen

### 3.4 KI-Verhalten anpassen

1. `object_host.dart` → `_moveZombieTowardsTarget()` oder `performAllZombieAttacks()` ändern
2. Enneagramm-Profile in `EnneagramProfile.all` erweitern
3. Fuzzy-Regeln in `HostPersonality.initializeRules()` anpassen

### 3.5 Neuen Geländetyp hinzufügen

1. `TerrainType`-Enum in `lib/models/map_data.dart` erweitern
2. `TerrainConfig.defaults`-Map ergänzen
3. `TerrainType.fromString()` in der switch-Anweisung ergänzen

---

## 4. Coding-Standards

### 4.1 Namenskonventionen

| Element | Konvention | Beispiel |
|---------|-----------|----------|
| Dateien | snake_case | `object_line_cook.dart` |
| Klassen | PascalCase | `ObjectLineCook` |
| Methoden | camelCase | `spawnLineCook()` |
| Private Member | _camelCase | `_loadMap()` |
| Konstanten | camelCase (oder SCREAMING_SNAKE) | `_hostTileWidth` |
| Datei-Präfix | `object_`, `widget_`, `screen_` | `object_player.dart` |

### 4.2 Dokumentation

- Öffentliche Klassen/Methoden: `///` Dart-Doc-Kommentare
- Private Methoden: `///` oder `//` Kommentare (nach Ermessen)
- Komplexe Logik: Kommentare in natürlicher Sprache (deutsch oder englisch)
- TODOs: Mit Ticket-Nummer oder Autor, z. B. `// TODO(#123): Implementieren`

### 4.3 State-Management

- Aktuell: **setState()** in StatefulWidgets
- Kein Provider, Riverpod, Bloc etc. (noch nicht nötig)
- Für Theme: `ValueNotifier<ThemeMode>` in `AppTheme`

### 4.4 Tests

Tests befinden sich in `lib/fuzzy_logic/test/` sowie in `test/fog_of_war_test.dart` (Fog of War). Für neue Funktionen sollten Tests ergänzt werden.

---

## 5. Fehlerbehebung (FAQ)

### "Ich sehe die Karte nicht"
- Prüfe, ob `assets/maps/street_battle.tmx` existiert
- Prüfe, ob der Tileset-Pfad korrekt ist
- Prüfe die Flutter-Konsole auf Fehler

### "Tokens werden nicht angezeigt"
- Prüfe `_isLoading` und `_error` in WidgetMapLoader
- Prüfe Viewport-Culling: Zoome ganz heraus
- Prüfe `_allTokens` in WidgetCaretaker
- Prüfe Fog-of-War-Status (Token könnte auf unsichtbarem Feld stehen)

### "Bewegung rastet nicht ein"
- Prüfe `_snapToNearestFreeHex()` in WidgetCaretaker
- Prüfe BFS in `TerrainService.effectiveMovementRange()`
- Prüfe `_isHexFieldFree()` und `_getOccupiedHexFields()`

### "Geländekosten werden ignoriert"
- Prüfe, ob die "Gelaendetypen"-Objektgruppe in der TMX existiert
- Prüfe die `type`-Werte (müssen mit `TerrainType.fromString()` übereinstimmen)
- Prüfe `TerrainConfig.defaults` in `map_data.dart`

### "Fog of War zeigt zu viel / zu wenig"
- Prüfe `fieldOfView`-Werte der Tokens
- Prüfe `hasLineOfSight()` im FogOfWarService
- Prüfe `blocksVision`-Flags der Geländetypen
- Prüfe `debugPrint`-Ausgaben bei `computeVisibility()`

### "Der Kampf funktioniert nicht"
- Prüfe `performAction()` in `object_player.dart`
- Prüfe die Kampfregeln in `doc/rules/combat_rules.md`
- Prüfe `CombatResult`-Ausgabe

### "Die KI macht nichts"
- Prüfe `_isHostTurn` in WidgetCaretaker
- Prüfe `_executeHostTurn()` → `_executeHostMovement()` etc.
- Prüfe `doughDumpsterList` in ObjectHost

---

## 6. Weiterführende Informationen

| Ressource | Beschreibung |
|-----------|-------------|
| `doc/doc/00_project_overview.md` | Projektübersicht |
| `doc/doc/01_class_diagram.md` | Klassendiagramm |
| `doc/doc/02_flow_diagrams.md` | Ablaufpläne |
| `doc/doc/03_dependency_graph.md` | Abhängigkeitsdiagramm |
| `doc/doc/04_cliffnotes.md` | Cliffnotes (kurz & knapp) |
| `doc/todo/feat_better_maps/3_terrain_system.md` | Detaillierte Terrain-System-Doku |
| `doc/todo/feat_better_maps/4_Kartenauswahl.md` | Kartenauswahl: maps.json, MapMeta, MapRegistry |
| `doc/rules/combat_rules.md` | Vollständige Kampfregeln |
| `pubspec.yaml` | Abhängigkeiten und Metadaten |

---

## 7. Ansprechpartner

Bei Fragen zum Projekt wende dich an deinen Team-Lead oder erstelle ein Issue im GitHub-Repository.