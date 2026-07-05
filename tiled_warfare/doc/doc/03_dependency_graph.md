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
  └─ widget_map_loader.dart

widget_map_loader.dart
  ├─ flutter/material.dart
  ├─ flutter/services.dart
  ├─ dart:ui
  └─ xml/xml.dart

widget_caretaker.dart
  ├─ dart:collection
  ├─ dart:math
  ├─ flutter/material.dart
  ├─ object_dough_dumpster.dart
  ├─ object_dough_zombie.dart
  ├─ object_host.dart
  ├─ object_line_cook.dart
  ├─ object_player.dart
  └─ object_token.dart

object_player.dart
  ├─ dart:math
  ├─ object_line_cook.dart
  └─ object_token.dart

object_host.dart
  ├─ dart:math
  ├─ dart:ui
  ├─ fuzzylogic.dart (fuzzy_logic/lib/)
  ├─ object_dough_dumpster.dart
  ├─ object_dough_zombie.dart
  ├─ object_line_cook.dart
  ├─ object_player.dart
  ├─ object_token.dart
  └─ random_name_generator

object_line_cook.dart
  ├─ random_name_generator
  └─ object_token.dart

object_dough_zombie.dart
  ├─ random_name_generator
  └─ object_token.dart

object_dough_dumpster.dart
  ├─ dart:math
  ├─ object_dough_zombie.dart
  └─ object_token.dart

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

WidgetMapLoader
  │
  ├─→ ScreenMain: Liefert Kartendaten via Callbacks
  └─→ _HexMapPainter: Zeichnet die Karte

WidgetCaretaker (Zentrale Spiel-Logik)
  │
  ├─→ ScreenMain: Kind-Widget, erhält Parameter
  ├─→ ObjectPlayer: Steuert Spieler-Einheiten
  ├─→ ObjectHost: Steuert KI-Einheiten
  ├─→ _HexUtils: Hex-Gitter-Berechnungen
  ├─→ _BfsVisitedSet: BFS-Optimierung
  ├─→ _TokenRenderInfo: Darstellungs-Metadaten
  └─→ _TokenWidget: Visuelle Darstellung

ScreenMain
  │
  ├─→ MainApp: Wird als home verwendet
  └─→ AppTheme: Nutzt Theme für UI

MainApp
  └─→ AppTheme: Konfiguriert Light/Dark Mode
```

## Datenfluss (zur Laufzeit)

```
TMX-Datei (assets/maps/street_battle.tmx)
  │
  ▼
WidgetMapLoader._loadMap()
  │
  ├─→ Kartendimensionen → ScreenMain._onMapLoaded()
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