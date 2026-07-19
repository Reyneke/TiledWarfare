# Cliffnotes für ADHS'ler & Personen auf dem Spektrum

## 🎯 Das Spiel in 3 Sätzen

**Tiled Warfare** ist ein Rundenstrategie-Spiel auf einer Hex-Karte. Du steuerst 3 Köche (Line Cooks) gegen Teig-Zombies, die von Mülltonnen (Dough Dumpsters) gespawnt werden. Ziel: Alle Gegner besiegen, bevor deine Köche sterben – unterstützt durch ein Geländesystem mit Bewegungskosten und Fog of War.

## 📁 Wo ist was?

| Datei | Was drin ist |
|-------|-------------|
| `lib/main.dart` | Startpunkt – hier beginnt alles |
| `lib/main_app.dart` | Das Haupt-Fenster (MaterialApp) |
| `lib/screens/screen_main.dart` | Der Bildschirm: Karte + Overlay |
| `lib/models/map_data.dart` | Datenmodell (MapData, TileLayer, TilesetInfo, TerrainType, TerrainConfig) |
| `lib/services/map_parser.dart` | TMX/TMJ-Parser (Interface + Implementierung) |
| `lib/services/terrain_service.dart` | **Geländesystem**: TerrainService, parseTerrain, Bewegungskosten-BFS, Passierbarkeit |
| `lib/services/fog_of_war.dart` | **Fog of War**: Sichtbarkeitsberechnung (visible + revealed hexes) |
| `lib/utils/hex_grid.dart` | **Zentrale Hex-Utility**: Pixel↔Hex, Distanz, Nachbarn, belegte Felder |
| `lib/widgets/widget_map_loader.dart` | Lädt und rendert die Karte (TMX/TMJ) |
| `lib/widgets/widget_caretaker.dart` | **Das Herzstück** – Tokens, Runden, Kämpfe |
| `lib/objects/object_token.dart` | Basis-Klasse für alle Einheiten (inkl. `fieldOfView`) |
| `lib/objects/object_line_cook.dart` | Deine Köche (Angriff 80, Bewegung 3) |
| `lib/objects/object_dough_zombie.dart` | Zombies (Angriff 40, Bewegung 1) |
| `lib/objects/object_dough_dumpster.dart` | Mülltonnen (50 HP, spawnen Zombies) |
| `lib/objects/object_player.dart` | Deine Steuerung + Kampf-Logik |
| `lib/objects/object_host.dart` | KI-Gegner + Fuzzy-Persönlichkeit |
| `lib/theme/app_theme.dart` | Light/Dark Mode + Schriftarten |
| `doc/rules/combat_rules.md` | Vollständige Kampfregeln |

## 🧠 Wichtige Konzepte (kurz)

### Hex-Gitter (odd-r)
- Pointy-Top-Hexagone, staggeraxis="y", staggerindex="odd"
- Ungerade Zeilen sind um eine halbe Tile-Breite nach rechts versetzt
- Jedes Hex hat 6 Nachbarn

### Gelände-System
- 7 Geländetypen: normal, ruin, forest, water, wall, openGround, swamp
- Jeder Typ hat Bewegungskosten (1×–3×) und kann Sicht blockieren
- `TerrainService` berechnet effektive Bewegungsreichweite via BFS
- Kollisions-Tiles aus Tile-Layern + Token-Positionen blockieren Bewegung

### Fog of War
- Jeder Token hat `fieldOfView` (Sichtweite in Hex-Feldern, Default: 3)
- **Zwei Ebenen**: `visible` (aktuelle Runde) + `revealed` (jemals gesehen)
- Wände und Ruinen blockieren die Sicht (das Hindernis selbst ist sichtbar)
- Tote Tokens tragen nicht zur Sicht bei
- `getVisibleEnemies()` filtert Gegner auf sichtbaren Feldern

### Kampf (W100-System)
- **W100** = Würfel 1–100
- **Erfolg** = gewürfelte Zahl ≤ dein Wert
- **Kritisch** = ≤ 5 (doppelter Schaden)
- **Patzer** = > 90 (du nimmst Schaden)
- **Vergleich**: Wer seinen Wert besser unterwürfelt, gewinnt

### Runden
1. Jede Runde: Initiative-Wurf (W100) für beide Seiten
2. Höherer Wert beginnt
3. Spieler: Tokens bewegen (Drag & Drop) + angreifen (Kontextmenü)
4. KI: Zombies bewegen + angreifen
5. Nächste Runde

### Token-Typen
| Token | Farbe | HP | Angriff | Bewegung | Sicht | Besonderheit |
|-------|-------|----|---------|----------|-------|-------------|
| Line Cook (LC) | Blau | 3 | 80 | 3 | 4 | Kann Nah- & Fernkampf |
| Dough Zombie (DZ) | Rot | 3 | 40 | 1 | 2 | Nur Nahkampf |
| Dough Dumpster (DD) | Lila | 50 | 0 | 0 | 3 | Spawnt 1w6 Zombies/Runde |

## 🔄 Typischer Spielfluss

```
App starten → Karte laden (ink. Gelände + Kollision) → 3 Köche spawnen → Runde 1 beginnt
                                                       │
    ┌──────────────────────────────────────────────────┘
    │
    ▼
Initiative würfeln → Wer gewinnt, fängt an
    │
    ├─ Spieler-Zug (mit Fog of War):
    │     ├─ Nur sichtbare (visible) Gegner werden angezeigt
    │     ├─ Klick auf Koch → auswählen
    │     ├─ Koch ziehen → bewegen (grüne Felder = erreichbar, Geländekosten!)
    │     ├─ Langer Druck → Kontextmenü
    │     │     ├─ Info: Werte anzeigen
    │     │     ├─ Nahkampf: rote Highlights → Ziel antippen
    │     │     └─ Fernkampf: wie Nahkampf, aber weiter
    │     └─ "Zug beenden"-Button
    │
    └─ KI-Zug (automatisch):
          ├─ Mülltonnen spawnen Zombies
          ├─ Zombies bewegen sich auf Köche zu (mit Geländekosten)
          └─ Zombies greifen an (wenn in Reichweite)
```

## ⚡ Wichtige Hotkeys / Interaktionen

| Aktion | Eingabe |
|--------|---------|
| Token auswählen | Einfacher Klick |
| Token bewegen | Ziehen (Drag & Drop) |
| Kontextmenü | Langer Druck |
| Angriff ausführen | Kontextmenü → Nahkampf/Fernkampf → Ziel antippen |
| Zug beenden | Button im Status-Panel (oben rechts) |
| Zoomen | Zwei-Finger-Geste / Mausrad |
| Scrollen | Wischen / Ziehen |
| Theme wechseln | Sonne/Mond-Icon in der AppBar |

## 🐛 Bekannte Eigenheiten

- **Singletons**: ObjectPlayer und ObjectHost sind Singletons – es gibt nur eine Instanz
- **Zufall**: Jeder Spielstart hat einen anderen Seed (Mikrosekunden)
- **Zombie-Spawning**: Alle 2 Runden spawnen Dumpster 1w6 Zombies
- **Tote Köche**: Wenn ein Koch stirbt, 50% Chance auf neuen Zombie, 25% auf neuen Dumpster
- **Cache**: WidgetCaretaker cached viel (Token-Listen, erreichbare Felder, Viewport) – bei Bugs `_invalidateCache()` prüfen

## 🔍 Debug-Tipps

1. **Karte lädt nicht** → Prüfe `assets/maps/street_battle.tmx` (oder .tmj) und Tileset-Pfad. Validiere das Format mit `MapParser.forPath()`.
2. **Tokens unsichtbar** → Prüfe Viewport-Culling in `_getVisibleMapRect()` oder Fog-of-War-Status
3. **Bewegung funktioniert nicht** → Prüfe `_snapToNearestFreeHex()` und BFS-Logik im `TerrainService`
4. **Kampf-Logik falsch** → Prüfe `performAction()` in `object_player.dart`
5. **KI macht nichts** → Prüfe `_executeHostTurn()` und `_isHostTurn`
6. **Fog of War zeigt nichts** → Prüfe `computeVisibility()` im `FogOfWarService`

## 📚 Dateien, die man kennen sollte (nach Wichtigkeit)

1. **`widget_caretaker.dart`** (1857 Zeilen) – 90% der Spiel-Logik
2. **`terrain_service.dart`** — Geländesystem, Bewegungskosten-BFS, parseTerrain
3. **`fog_of_war.dart`** — Fog of War (visible + revealed hexes)
4. **`object_player.dart`** (286 Zeilen) – Kampfsystem
5. **`object_host.dart`** (518 Zeilen) – KI-Verhalten
6. **`widget_map_loader.dart`** (334 Zeilen) – Karten-Ladung, Multi-Tileset, Multi-Layer
7. **`map_parser.dart`** – TMX/TMJ-Parser (CSV, Base64, Zlib)
8. **`map_data.dart`** – Datenmodell (MapData, TileLayer, TerrainType, TerrainConfig)
9. **`hex_grid.dart`** – Zentrale Hex-Utility
10. **`combat_rules.md`** (187 Zeilen) – Regelwerk