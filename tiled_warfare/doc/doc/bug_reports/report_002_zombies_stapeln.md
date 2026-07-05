# Bug Report #002: Zombies stapeln sich aufeinander

**Status: GEFIXT** – Siehe Fix-Abschnitt unten.

## Beschreibung

Der Host spawnt, laut Log, eine große Anzahl Zombies. Es sind jedoch deutlich weniger Zombies sichtbar, als geloggt werden. Die Zombies stapeln sich auf denselben Hex-Feldern, sodass sie unsichtbar untereinander liegen.

## Reproduktionsschritte

1. Spiel starten
2. Mehrere Runden abwarten (Host-Züge beobachten)
3. Log-Nachrichten zeigen z. B. "spawniert 6 neue Zombies"
4. Auf der Karte sind aber nur 1–2 neue Zombies sichtbar

## Erwartetes Verhalten

Jeder Zombie sollte auf einem eigenen, freien Hex-Feld spawnen. Wenn keine freien Felder in der Nähe des Dumpsters vorhanden sind, sollten Zombies auf weiter entfernte freie Felder ausweichen.

## Tatsächliches Verhalten

Zombies spawnen auf denselben Hex-Feldern und stapeln sich unsichtbar übereinander.

## Fehlerursachen (analysiert)

### Ursache 1: Keine Kollisionsprüfung beim Spawning
**Datei:** `lib/objects/object_host.dart`, Zeilen 460–489 (Original)

```dart
final neighborOffsets = <({int dx, int dy})>[
  (dx: 0, dy: -1), (dx: -1, dy: 0),
  (dx: 1, dy: 0), (dx: 0, dy: 1),
  (dx: -1, dy: -1), (dx: 1, dy: 1),
];
for (int i = 0; i < newZombies.length; i++) {
  if (i < neighborOffsets.length) {
    final offset = neighborOffsets[i];
    newZombies[i].position = _hexToPixel(
      x: (dumpsterHex.x + offset.dx).clamp(0, 50),
      y: (dumpsterHex.y + offset.dy).clamp(0, 50),
    );
  } else {
    newZombies[i].position = dumpster.position; // ← STAPELUNG!
  }
}
```

**Probleme:**
1. Es gibt nur **6 Nachbar-Offsets**, aber `spawnZombies()` erzeugt **1w6 (1–6) Zombies**. Bei 6 Zombies belegt jeder genau einen Nachbarplatz – das geht noch auf.
2. **ABER**: `performAllDumpsterSpawning()` wurde **jede Runde** aufgerufen (nicht alle 2 Runden). Nach mehreren Runden sind die Nachbarfelder bereits besetzt, aber es wurde **nicht geprüft, ob ein Feld frei ist**.
3. Wenn `i >= 6` (was bei aufeinanderfolgenden Runden kumulativ passiert), fielen Zombies auf `dumpster.position` zurück – **alle auf denselben Punkt**.
4. Es gab **keine Prüfung**, ob ein Nachbar-Hex bereits von einem anderen Zombie belegt ist.

### Ursache 2: Keine Kollisionsprüfung bei der Bewegung
**Datei:** `lib/objects/object_host.dart`, Zeilen 275–351 (Original)

Die Bewegung (`_moveZombieTowardsTarget()`) prüfte **nicht**, ob das Ziel-Hex-Feld bereits von einem anderen Zombie belegt ist. Mehrere Zombies, die auf dasselbe Ziel zusteuern, landeten daher auf demselben Hex-Feld.

### Ursache 3: Initiales Spawning hatte nur 4 Offsets
**Datei:** `lib/widgets/widget_caretaker.dart`, Zeilen 309–326 (Original)

Es gab nur **4 Nachbar-Offsets** (statt 6). `spawnZombies()` erzeugt 1w6 Zombies. Bei 5–6 Zombies fielen die überschüssigen direkt auf den Dumpster.

### Ursache 4: Spawning fand jede Runde statt
**Datei:** `lib/widgets/widget_caretaker.dart`, Zeile 500–505 (Original)

`performAllDumpsterSpawning()` wurde **jede Runde** aufgerufen, obwohl der Kommentar "alle 2 Runden" besagte. Die Bevölkerung explodierte exponentiell.

## 🔧 Angewandte Fixes

### Fix 1: Spiralförmige Suche beim Spawning (ObjectHost)
`performAllDumpsterSpawning()` verwendet jetzt `_findFreeHexNear()` + `_buildOccupiedHostHexes()`, um für jeden neuen Zombie ein freies Hex-Feld zu finden. Zombies werden nicht mehr auf bereits belegte Felder gesetzt, und der `occupied`-Set wird nach jedem platzierten Zombie aktualisiert.

### Fix 2: Kollisionsprüfung bei der Bewegung (ObjectHost)
`_moveZombieTowardsTarget()` baut jetzt vor der Bewegung den `_buildOccupiedHostHexes()`-Set auf und überspringt belegte Nachbar-Felder bei der Wegfindung.

### Fix 3: Spiralförmige Suche beim initialen Spawning (WidgetCaretaker)
`_initializeGameObjects()` verwendet jetzt `_findFreeHexNearCaretaker()` für die initiale Zombie-Platzierung, mit korrekten Karten-Grenzen (`mapWidth`, `mapHeight`) und spiralförmiger Suche.

### Fix 4: Spawning nur alle 2 Runden (WidgetCaretaker)
`_executeHostSpawning()` prüft jetzt `if (_currentRound % 2 != 0) return;` – Spawning findet nur in **geraden Runden** statt.

## Betroffene Dateien (nach Fix)

| Datei | Änderung |
|-------|----------|
| `lib/objects/object_host.dart` | Neue Methoden `_buildOccupiedHostHexes()`, `_findFreeHexNear()`, angepasst `performAllDumpsterSpawning()` und `_moveZombieTowardsTarget()` |
| `lib/widgets/widget_caretaker.dart` | Neue Methode `_findFreeHexNearCaretaker()`, angepasst `_initializeGameObjects()` und `_executeHostSpawning()` |

## Priorität

**Hoch** – Zombies, die unsichtbar aufeinander stapeln, führen zu einer großen Diskrepanz zwischen geloggter und tatsächlicher Anzahl.

## Gemeldet von / Gefixt von

Code-Analyse basierend auf Projektdokumentation (Stand: Juli 2026)