# Abhängigkeits- und Einflussdiagramm

## Import-Abhängigkeiten (welche Klasse importiert welche)

```
main.dart
  └─ main_app.dart

main_app.dart
  ├─ screen_main.dart
  └─ app_theme.dart

screen_main.dart
  ├─ app_theme.dart
  ├─ widget_caretaker.dart
  ├─ widget_map_loader.dart
  ├─ services/terrain_service.dart
  ├─ services/map_exceptions.dart
  └─ utils/hex_grid.dart

screen_restaurant.dart
  ├─ models/map_data.dart (MapMeta)
  ├─ services/map_registry.dart
  ├─ services/profile_storage.dart
  ├─ objects/object_profile.dart
  ├─ theme/app_theme.dart
  └─ l10n/app_localizations.dart

map_registry.dart (services/)
  ├─ dart:convert
  ├─ flutter/services.dart
  └─ models/map_data.dart (MapMeta)

widget_map_loader.dart
  ├─ flutter/material.dart
  ├─ flutter/services.dart
  ├─ dart:ui
  ├─ models/map_data.dart
  ├─ services/map_parser.dart
  └─ utils/hex_grid.dart

map_parser.dart (services/)
  ├─ dart:convert
  ├─ dart:io (zlib)
  ├─ dart:typed_data
  ├─ flutter/services.dart
  ├─ xml/xml.dart
  └─ models/map_data.dart

map_data.dart (models/)
  ├─ dart:typed_data
  └─ flutter/foundation.dart
  (now also contains MapMeta – no additional imports needed)

widget_caretaker.dart
  ├─ dart:collection
  ├─ dart:math
  ├─ flutter/material.dart
  ├─ objects/object_dough_dumpster.dart
  ├─ objects/object_dough_zombie.dart
  ├─ objects/object_host.dart
  ├─ objects/object_line_cook.dart
  ├─ objects/object_player.dart
  └─ objects/object_token.dart

object_player.dart
  ├─ dart:math
  ├─ objects/object_line_cook.dart
  └─ objects/object_token.dart

object_host.dart
  ├─ dart:math
  ├─ dart:ui
  ├─ fuzzylogic.dart (fuzzy_logic/lib/)
  ├─ objects/object_dough_dumpster.dart
  ├─ objects/object_dough_zombie.dart
  ├─ objects/object_line_cook.dart
  ├─ objects/object_player.dart
  ├─ objects/object_token.dart
  └─ random_name_generator

object_line_cook.dart
  ├─ random_name_generator
  └─ objects/object_token.dart

object_dough_zombie.dart
  ├─ random_name_generator
  └─ objects/object_token.dart

object_dough_dumpster.dart
  ├─ dart:math
  ├─ objects/object_dough_zombie.dart
  └─ objects/object_token.dart

object_token.dart
  └─ dart:ui (nur Offset)

app_theme.dart
  ├─ flutter/material.dart
  └─ google_fonts
```

## Einflussdiagramm (welche Klasse beeinflusst welche)

```
ObjectToken (Basis-Klasse)
  │
  ├─→ ObjectLineCook: Erbt alle Eigenschaften, setzt Default-Werte
  ├─→ ObjectDoughZombie: Erbt alle Eigenschaften, setzt Default-Werte
  └─→ ObjectDoughDumpster: Erbt alle Eigenschaften, setzt Default-Werte
        │
        └─→ ObjectHost: Verwaltet Dumpster + Zombies, steuert KI
              │
              ├─→ WidgetCaretaker: Nutzt Host für KI-Züge
              └─→ HostPersonality: Bestimmt KI-Verhalten via Fuzzy Logic
                    │
                    ├─→ Aggressiveness: Fuzzy-Variable
                    ├─→ RiskTolerance: Fuzzy-Variable
                    └─→ TacticalComplexity: Fuzzy-Variable

ObjectPlayer (Singleton)
  │
  ├─→ WidgetCaretaker: Nutzt Player für Spieler-Züge
  └─→ ObjectHost: Nutzt Player für Kampfberechnungen
        │
        └─→ CombatResult: Ergebnis eines Kampfes

MapParser (Interface)
  │
  ├─→ TmxParser: XML-Parser für TMX-Dateien
  └─→ TmjParser: JSON-Parser für TMJ-Dateien
        │
        └─→ MapData: Geparste Kartendaten (via parse())

WidgetMapLoader
  │
  ├─→ MapParser (Interface): Nutzt Parser-Instanz via forPath()
  │     ├─→ TmxParser: .tmx-Dateien
  │     └─→ TmjParser: .tmj-Dateien
  ├─→ MapData: Verarbeitet geparste Kartendaten
  ├─→ HexGrid: Nutzt Hex-Berechnungen für Painter
  ├─→ ScreenMain: Liefert Kartendaten via Callbacks
  └─→ _HexMapPainter: Zeichnet die Karte (multi-layer, multi-tileset, Viewport-Culling)

MapRegistry (Service)
  │
  ├─→ MapMeta: Produziert MapMeta-Instanzen aus maps.json
  └─→ ScreenRestaurant: Nutzt MapRegistry für Map-Auswahl

ScreenRestaurant
  │
  ├─→ ScreenMain: Startet Spiel mit ausgewählter Map (tmxPath)
  ├─→ MapRegistry: Lädt Kartenliste
  ├─→ ObjectProfile: Verwaltet Personal + Team-Zusammenstellung
  └─→ AppTheme: Darstellung

WidgetCaretaker (Zentrale Spiel-Logik)
  │
  ├─→ ScreenMain: Kind-Widget, erhält Parameter
  ├─→ ObjectPlayer: Steuert Spieler-Einheiten
  ├─→ ObjectHost: Steuert KI-Einheiten
  ├─→ HexGrid: Hex-Gitter-Berechnungen (übergeben von ScreenMain)
  ├─→ _BfsVisitedSet: BFS-Optimierung
  ├─→ _TokenRenderInfo: Darstellungs-Metadaten
  └─→ _TokenWidget: Visuelle Darstellung

ScreenMain
  │
  ├─→ MainApp: Wird als home verwendet
  ├─→ HexGrid: Erstellt aus Kartendaten, übergibt an Kinder
  └─→ AppTheme: Nutzt Theme für UI

MainApp
  ├─→ ScreenStart: Startbildschirm (Profil-Auswahl)
  └─→ AppTheme: Konfiguriert Light/Dark Mode
```

## Datenfluss (zur Laufzeit)

```
TMX-Datei / TMJ-Datei (assets/maps/...)
  │
  ▼
MapParser.forPath(path) → TmxParser / TmjParser
  │
  ▼
parser.loadFromAsset(path) → MapData
  │
  ▼
WidgetMapLoader._loadMap()
  │
  ├─→ _loadTilesetImages(MapData, basePath) → Tileset-Bilder (multi-tileset, indiziert nach firstGid)
  ├─→ _extractSpawnPoints(MapData) → Spawnpunkte (konfigurierbar via MapLoadConfig)
  ├─→ Kartendimensionen → ScreenMain._onMapLoaded()
  │     └─→ HexGrid erstellen → ObjectHost.setHexGrid()
  ├─→ TransformationController → ScreenMain._onTransformationControllerCreated()
  └─→ Spawnpunkte → ScreenMain._onSpawnPointsParsed()
                        │
                        ▼
                   WidgetCaretaker (via Parameter)
                        │
                        ├─→ _initializeGameObjects()
                        │     ├─→ ObjectPlayer.spawnLineCook() × 3
                        │     └─→ ObjectHost.doughDumpsterList.add()
                        │           └─→ ObjectDoughDumpster.spawnZombies()
                        │
                        ├─→ _startNewRound()
                        │     ├─→ ObjectPlayer.rollInitiative()
                        │     ├─→ ObjectHost.rollInitiative()
                        │     └─→ ggf. _executeHostTurn()
                        │
                        ├─→ Spieler-Interaktion (Tap/Drag)
                        │     ├─→ _handleTap() → _selectedToken / Targeting
                        │     └─→ _handleDragEnd() → Bewegung + Snap-to-Grid
                        │
                        └─→ _buildTokenWidgets()
                              └─→ _TokenWidget (Darstellung)
```

## Schlüssel-Beziehungen

| Beziehung | Typ | Beschreibung |
|-----------|-----|-------------|
| ObjectToken → ObjectLineCook | Vererbung | Line Cook ist ein spezialisierter Token |
| ObjectToken → ObjectDoughZombie | Vererbung | Dough Zombie ist ein spezialisierter Token |
| ObjectToken → ObjectDoughDumpster | Vererbung | Dough Dumpster ist ein spezialisierter Token |
| ObjectPlayer → ObjectLineCook | 1:n | Ein Spieler hat mehrere Line Cooks |
| ObjectHost → ObjectDoughDumpster | 1:n | Ein Host hat mehrere Dough Dumpster |
| ObjectDoughDumpster → ObjectDoughZombie | 1:n | Ein Dumpster hat mehrere Zombies |
| WidgetCaretaker → ObjectPlayer | Nutzung | Caretaker nutzt Player für Spieler-Aktionen |
| WidgetCaretaker → ObjectHost | Nutzung | Caretaker nutzt Host für KI-Aktionen |
| ScreenMain → WidgetMapLoader | Komposition | ScreenMain enthält MapLoader |
| ScreenMain → WidgetCaretaker | Komposition | ScreenMain enthält Caretaker |
| ObjectHost → HostPersonality | Komposition | Host hat eine Fuzzy-Persönlichkeit |
| HostPersonality → EnneagramProfile | Komposition | Persönlichkeit basiert auf Enneagramm |
| WidgetMapLoader → MapParser | Nutzung | MapLoader nutzt Parser via Interface |
| MapParser → MapData | Produktion | Parser erzeugt MapData-Instanzen |
| WidgetMapLoader → MapData | Nutzung | MapLoader verwendet Kartendaten |
| ScreenMain → HexGrid | Erzeugung | ScreenMain erstellt HexGrid aus Kartendaten |
| ScreenRestaurant → MapRegistry | Nutzung | ScreenRestaurant lädt Kartenliste für Auswahl |
| ScreenRestaurant → ScreenMain | Navigation | Übergibt MapMeta.tmxPath an ScreenMain |
| MapRegistry → MapMeta | Produktion | Erzeugt MapMeta-Instanzen aus maps.json |
