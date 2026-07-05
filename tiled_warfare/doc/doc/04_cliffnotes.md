# Cliffnotes für ADHS'ler & Personen auf dem Spektrum

## 🎯 Das Spiel in 3 Sätzen

**Tiled Warfare** ist ein Rundenstrategie-Spiel auf einer Hex-Karte. Du steuerst 3 Köche (Line Cooks) gegen Teig-Zombies, die von Mülltonnen (Dough Dumpsters) gespawnt werden. Ziel: Alle Gegner besiegen, bevor deine Köche sterben.

## 📁 Wo ist was?

| Datei | Was drin ist |
|-------|-------------|
| `lib/main.dart` | Startpunkt – hier beginnt alles |
| `lib/main_app.dart` | Das Haupt-Fenster (MaterialApp) |
| `lib/screens/screen_main.dart` | Der Bildschirm: Karte + Overlay |
| `lib/widgets/widget_map_loader.dart` | Lädt die Karte aus der TMX-Datei |
| `lib/widgets/widget_caretaker.dart` | **Das Herzstück** – Tokens, Runden, Kämpfe |
| `lib/objects/object_token.dart` | Basis-Klasse für alle Einheiten |
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
| Token | Farbe | HP | Angriff | Bewegung | Besonderheit |
|-------|-------|----|---------|----------|-------------|
| Line Cook (LC) | Blau | 3 | 80 | 3 | Kann Nah- & Fernkampf |
| Dough Zombie (DZ) | Rot | 3 | 40 | 1 | Nur Nahkampf |
| Dough Dumpster (DD) | Lila | 50 | 0 | 0 | Spawnt 1w6 Zombies/Runde |

## 🔄 Typischer Spielfluss

```
App starten → Karte laden → 3 Köche spawnen → Runde 1 beginnt
                                                      │
    ┌─────────────────────────────────────────────────┘
    │
    ▼
Initiative würfeln → Wer gewinnt, fängt an
    │
    ├─ Spieler-Zug:
    │     ├─ Klick auf Koch → auswählen
    │     ├─ Koch ziehen → bewegen (grüne Felder = erreichbar)
    │     ├─ Langer Druck → Kontextmenü
    │     │     ├─ Info: Werte anzeigen
    │     │     ├─ Nahkampf: rote Highlights → Ziel antippen
    │     │     └─ Fernkampf: wie Nahkampf, aber weiter
    │     └─ "Zug beenden"-Button
    │
    └─ KI-Zug (automatisch):
          ├─ Mülltonnen spawnen Zombies
          ├─ Zombies bewegen sich auf Köche zu
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

1. **Karte lädt nicht** → Prüfe `assets/maps/street_battle.tmx` und Tileset-Pfad
2. **Tokens unsichtbar** → Prüfe Viewport-Culling in `_getVisibleMapRect()`
3. **Bewegung funktioniert nicht** → Prüfe `_snapToNearestFreeHex()` und BFS-Logik
4. **Kampf-Logik falsch** → Prüfe `performAction()` in `object_player.dart`
5. **KI macht nichts** → Prüfe `_executeHostTurn()` und `_isHostTurn`

## 📚 Dateien, die man kennen sollte (nach Wichtigkeit)

1. **`widget_caretaker.dart`** (1857 Zeilen) – 90% der Spiel-Logik
2. **`object_player.dart`** (286 Zeilen) – Kampfsystem
3. **`object_host.dart`** (518 Zeilen) – KI-Verhalten
4. **`widget_map_loader.dart`** (279 Zeilen) – Karten-Rendering
5. **`combat_rules.md`** (187 Zeilen) – Regelwerk