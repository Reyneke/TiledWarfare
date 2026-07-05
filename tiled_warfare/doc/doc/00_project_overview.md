# Tiled Warfare – Projektübersicht

## Was ist Tiled Warfare?

Tiled Warfare ist ein **hexagonales Rundenstrategie-Spiel**, das mit **Flutter** entwickelt wurde. Der Spieler steuert "Line Cooks" (Köche) im Kampf gegen "Dough Zombies" (Teig-Zombies), die von "Dough Dumpsters" (Teig-Mülltonnen) gespawnt werden. Das Spiel läuft auf einer TMX-basierten Hex-Karte.

## Technologie-Stack

| Komponente       | Technologie                          |
|------------------|--------------------------------------|
| Framework        | Flutter (Dart)                       |
| Kartenformat     | TMX (Tile Map XML)                   |
| Grafiken         | Custom Tileset (PNG)                 |
| KI-Logik         | Fuzzy Logic Systems Library          |
| Namensgenerator  | random_name_generator                |
| Schriftarten     | Google Fonts (Poppins, Lato)         |

## Projektstruktur

```
lib/
├── main.dart                    # Einstiegspunkt
├── main_app.dart                # Root-Widget (MaterialApp)
├── screens/
│   └── screen_main.dart         # Hauptbildschirm (Karte + Overlay)
├── widgets/
│   ├── widget_map_loader.dart   # Lädt und rendert die TMX-Karte
│   └── widget_caretaker.dart    # Verwaltet Tokens, Runden, Kampf
├── objects/
│   ├── object_token.dart        # Basis-Klasse für alle Einheiten
│   ├── object_line_cook.dart    # Spieler-Einheit (Line Cook)
│   ├── object_dough_zombie.dart # Gegner-Einheit (Dough Zombie)
│   ├── object_dough_dumpster.dart# Gegner-Spawner (Dough Dumpster)
│   ├── object_player.dart       # Spieler-Steuerung + Kampfsystem
│   └── object_host.dart         # KI-Gegner-Steuerung + Fuzzy-Persönlichkeit
├── theme/
│   └── app_theme.dart           # Light/Dark Theme + Typografie
└── fuzzy_logic/                 # Fuzzy Logic Beispiele & Tests
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

1. **Hex-Gitter**: Die Karte verwendet ein Pointy-Top-Hex-Gitter mit `staggeraxis="y"` und `staggerindex="odd"` (odd-r).
2. **Runden-System**: Jede Runde beginnt mit einem Initiative-Wurf (W100). Der Gewinner beginnt.
3. **Kampf-System**: W100-basiertes Unterwürfel-System mit kritischen Erfolgen (≤5) und Patzern (>90).
4. **Bewegung**: Einheiten haben Bewegungspunkte und rasten auf dem Hex-Gitter ein (Snap-to-Grid).
5. **KI**: Der Host hat eine Fuzzy-Logik-Persönlichkeit basierend auf 12 Enneagramm-Profilen.