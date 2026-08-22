# Tiled Warfare – Projektübersicht

## Was ist Tiled Warfare?

Tiled Warfare ist ein **hexagonales Rundenstrategie-Spiel**, das mit **Flutter** entwickelt wurde. Der Spieler steuert "Line Cooks" (Köche) im Kampf gegen "Dough Zombies" (Teig-Zombies), die von "Dough Dumpsters" (Teig-Mülltonnen) gespawnt werden. Das Spiel läuft auf einer TMX-basierten Hex-Karte mit Geländesystem und Fog of War.

## Technologie-Stack

| Komponente       | Technologie                          |
|------------------|--------------------------------------|
| Framework        | Flutter (Dart)                       |
| Kartenformat     | TMX (Tile Map XML) + TMJ (JSON)      |
| Grafiken         | Custom Tilesets (PNG)                |
| KI-Logik         | Fuzzy Logic Systems Library          |
| Namensgenerator  | random_name_generator                |
| Schriftarten     | Google Fonts (Poppins, Lato)         |

## Projektstruktur

```
lib/
├── main.dart                    # Einstiegspunkt
├── main_app.dart                # Root-Widget (MaterialApp)
├── models/
│   ├── map_data.dart            # Datenmodell (MapData, MapMeta, TileLayer,
│   │                            #   LayerPurpose, TilesetInfo, TerrainType,
│   │                            #   TerrainConfig)
│   └── ...                      # Weitere Modelle (match_record, profile_data)
├── services/
│   ├── map_registry.dart        # Lädt maps.json, stellt verfügbare Karten bereit
│   ├── map_parser.dart          # Parser-Interface + TMX/TMJ-Parser
│   ├── terrain_service.dart     # Geländesystem (TerrainService, parseTerrain,
│   │                            #   Bewegungskosten-BFS, Kollisionserkennung)
│   ├── fog_of_war.dart          # Nebel des Krieges (FogOfWarService)
│   └── ...                      # Weitere Services (crash_logger, profile_storage)
├── screens/
│   ├── screen_restaurant.dart   # Restaurant-Bildschirm (Personal + Kartenauswahl)
│   └── screen_main.dart         # Hauptbildschirm (Karte + Overlay)
├── widgets/
│   ├── widget_map_loader.dart   # Lädt und rendert die Karte (TMX/TMJ)
│   └── widget_caretaker.dart    # Verwaltet Tokens, Runden, Kampf
├── objects/
│   ├── object_token.dart        # Basis-Klasse für alle Einheiten (mit fieldOfView)
│   ├── object_line_cook.dart    # Spieler-Einheit (Line Cook)
│   ├── object_dough_zombie.dart # Gegner-Einheit (Dough Zombie)
│   ├── object_dough_dumpster.dart# Gegner-Spawner (Dough Dumpster)
│   ├── object_player.dart       # Spieler-Steuerung + Kampfsystem
│   └── object_host.dart         # KI-Gegner-Steuerung + Fuzzy-Persönlichkeit
├── utils/
│   └── hex_grid.dart            # Zentrale Hex-Gitter-Berechnungen
├── theme/
│   └── app_theme.dart           # Light/Dark Theme + Typografie
└── fuzzy_logic/                 # Fuzzy Logic Bibliothek & Beispiele
doc/
├── rules/
│   └── combat_rules.md          # Vollständige Kampfregeln
└── doc/                         # Diese Dokumentation
    ├── 00_project_overview.md   # Diese Datei
    ├── 01_class_diagram.md      # Klassendiagramm
    ├── 02_flow_diagrams.md      # Ablaufpläne
    ├── 03_dependency_graph.md   # Abhängigkeits-/Einflussdiagramm
    ├── 04_cliffnotes.md         # Cliffnotes für ADHS'ler & Spektrum
    └── 05_new_employee_guide.md # Zusammenfassung für neue Mitarbeiter
```

## Kernkonzepte

0. **Tile-Layer-System**: Die Karte unterstützt mehrere Tile-Layer (Boden, Dekoration, Kollision), die über den `LayerPurpose`-Enum typsicher klassifiziert werden. Layer-Lookups erfolgen in O(1) über einen vorberechneten Index. Siehe `doc/todo/feat_better_maps/8_tile_layer_system.md`.
1. **Hex-Gitter**: Die Karte verwendet ein Pointy-Top-Hex-Gitter mit `staggeraxis="y"` und `staggerindex="odd"` (odd-r). Berechnungen erfolgen zentral über `HexGrid` (`lib/utils/hex_grid.dart`) – inklusive A\*-Pfadfindung (`findPath()`).
2. **Karten-Parsing**: TMX (XML) und TMJ (JSON) werden über das `MapParser`-Interface mit `TmxParser` und `TmjParser` geparst. Das Datenmodell (`lib/models/map_data.dart`) kapselt alle Karteninformationen. Unterstützt Polygon-Geometrie (`MapObject.points`), Base64/GZip, CSV, Multi-Layer und Objektgruppen mit typisierten Properties.
3. **Gelände-System**: Die Karte unterstützt Geländetypen (normal, ruin, forest, water, wall, openGround, swamp) mit individuellen Bewegungskosten und Sichtbarkeitsregeln. Zentral verwaltet durch `TerrainService` (`lib/services/terrain_service.dart`).
4. **Fog of War**: Jeder Token hat eine `fieldOfView`-Eigenschaft (Sichtweite in Hex-Feldern). Der `FogOfWarService` (`lib/services/fog_of_war.dart`) berechnet pro Runde die sichtbaren Felder unter Berücksichtigung von Line-of-Sight und Sichtbarrieren.
5. **Runden-System**: Jede Runde beginnt mit einem Initiative-Wurf (W100). Der Gewinner beginnt.
6. **Kampf-System**: W100-basiertes Unterwürfel-System mit kritischen Erfolgen (≤5) und Patzern (>90).
7. **Bewegung**: Einheiten haben Bewegungspunkte und rasten auf dem Hex-Gitter ein (Snap-to-Grid). Die effektive Reichweite wird vom `TerrainService` unter Berücksichtigung von Geländekosten berechnet.
8. **Kartenauswahl**: Verfügbare Karten werden aus `assets/maps/maps.json` geladen. `MapRegistry` (`lib/services/map_registry.dart`) parst die JSON-Datei und stellt `MapMeta`-Objekte bereit. Im `ScreenRestaurant` kann der Spieler vor dem Kampf eine Karte auswählen; die Auswahl wird via `MapMeta.tmxPath` an `ScreenMain` übergeben.
9. **KI**: Der Host hat eine Fuzzy-Logik-Persönlichkeit basierend auf 12 Enneagramm-Profilen.

## Services

| Service | Beschreibung | Datei |
|---------|-------------|-------|
| `MapParser` | Interface für Karten-Parsing (TMX, TMJ) | `lib/services/map_parser.dart` |
| `LayerPurpose` | Enum für typsichere Layer-Klassifizierung (ground, collision, decorative, ...) | `lib/models/map_data.dart` |
| `TerrainService` | Geländekonfiguration, Bewegungskosten-BFS, Passierbarkeit | `lib/services/terrain_service.dart` |
| `MapRegistry` | Lädt `maps.json`, parsed verfügbare Karten in `List<MapMeta>` | `lib/services/map_registry.dart` |
| `FogOfWarService` | Sichtbarkeitsberechnung (visible + revealed) | `lib/services/fog_of_war.dart` |