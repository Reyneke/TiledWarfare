# Fog of War

> **Datum:** 2. August 2026
> **Kontext:** Sprint "Better Maps" – Fokus auf das Fog-of-War-Modul

In diesem Modul wurde der Fog of War eingeführt, aber bisher wenig tatsächlich genutzt, da es eine längerwierige Fehlersuche in einem anderen Teil des Projektes gab. Dieses soll sich nun ändern.

---

## Aktueller Stand

### Wie ist der Fog of War derzeitig implementiert?

Der Fog of War ist als eigenständiger Service in `lib/services/fog_of_war.dart` implementiert:

**Klasse:** `FogOfWarService`

**Zwei Sichtbarkeitsebenen:**

| Ebene | Beschreibung | Lebensdauer |
|-------|-------------|-------------|
| `visibleHexes` | Hex-Felder, die in der **aktuellen Runde** von mindestens einer freundlichen Einheit eingesehen werden können | Wird bei jedem `computeVisibility()`-Aufruf neu berechnet |
| `revealedHexes` | Hex-Felder, die **jemals** von einer freundlichen Einheit gesehen wurden ("aufgedeckt") | Kumulativ, wird nie kleiner |

**Kern-API:**

| Methode | Zweck |
|---------|-------|
| `computeVisibility({friendlyTokens, terrainMap, terrainConfigs})` | Berechnet die Sichtbarkeit für die aktuelle Runde neu |
| `reset()` | Setzt den gesamten Fog-of-War-Zustand zurück (z. B. beim Laden einer neuen Karte) |
| `isVisible(hexKey)` | Prüft, ob ein Hex-Feld aktuell sichtbar ist |
| `isRevealed(hexKey)` | Prüft, ob ein Hex-Feld jemals aufgedeckt wurde |
| `getVisibleEnemies(enemyTokens)` | Gibt alle gegnerischen Tokens auf sichtbaren Feldern zurück |
| `getRevealedEnemies(enemyTokens)` | Gibt alle gegnerischen Tokens auf aufgedeckten Feldern zurück (für Ghost-Darstellung) |

**Sichtbarkeits-Algorithmus:**

1. **BFS-Erkundung:** Für jeden freundlichen Token wird eine Breitensuche von seinem Standort aus gestartet, begrenzt durch `fieldOfView` (Sichtweite in Hex-Feldern). Die Sichtweite wird auf `maxFieldOfView = 50` begrenzt (siehe Problem 5).
2. **Line-of-Sight (LoS):** Für jedes Kandidaten-Hex wird `hasLineOfSight()` aufgerufen – eine Cube-Koordinaten-basierte DDA (angepasster Bresenham für Hex-Gitter).
3. **Terrain-Blockade:** Gelände mit `blocksVision == true` (z. B. `wall`, `ruin`, `forest`) blockiert die Sicht. Das blockierende Feld selbst ist noch sichtbar, aber dahinterliegende Felder werden nicht erkundet.
4. **LoS-Cache:** Ergebnisse werden innerhalb einer Berechnung gecached (inkl. Symmetrie-Ausnutzung: LoS von A→B = LoS von B→A).
5. **BFS-Queue:** Verwendet `Queue.removeFirst()` (O(1)) statt `List.removeAt(0)` (O(n)) für optimale Performance.

**Eingabeparameter:**

- `friendlyTokens` – Liste aller freundlichen Tokens. Nur lebende Tokens (`woundValue > 0`) tragen zur Sicht bei.
- `terrainMap` – Lookup-Map von `hexKey → TerrainType`.
- `terrainConfigs` – Konfiguration pro TerrainType (definiert `blocksVision`).

### Wie sollte er sich darstellen?

Die Dokumentation in `fog_of_war.dart` beschreibt die gewünschte Darstellung:

```dart
if (fog.isVisible(hexKey)) { /* zeichne hell */ }
else if (fog.isRevealed(hexKey)) { /* zeichne dunkel */ }
else { /* zeichne schwarz */ }
```

- **Sichtbar** → normal gezeichnet (hell)
- **Aufgedeckt, aber nicht sichtbar** → dunkel/abgedunkelt gezeichnet (50% schwarzes Overlay)
- **Weder sichtbar noch aufgedeckt** → schwarz (komplett verdeckt)

**Aktueller Implementierungsstand:** Die visuelle Darstellung ist **implementiert**:

- `lib/widgets/widget_map_loader.dart` – `_drawFogOfWar()` zeichnet das Overlay im `_HexMapPainter`
- `lib/screens/screen_main.dart` – instanziiert den `FogOfWarService` und reicht ihn an `WidgetMapLoader` und `WidgetCaretaker` weiter
- `lib/widgets/widget_caretaker.dart` – `_computeFogOfWar()` ruft `computeVisibility()` zu Beginn jeder Runde auf

### Wird er bereits für den Spieler sichtbar dargestellt?

**Ja!** Der Fog of War ist jetzt vollständig in die Spiel-UI integriert:

- ✅ **Visuelle Darstellung:** `_HexMapPainter._drawFogOfWar()` überzeichnet nicht sichtbare Felder mit 50% schwarzem Overlay und nicht aufgedeckte Felder komplett schwarz
- ✅ **Runden-Integration:** `WidgetCaretaker._computeFogOfWar()` ruft `computeVisibility()` zu Beginn jeder Runde auf
- ✅ **KI-Integration:** `ObjectHost` berücksichtigt den Fog of War bei Bewegung und Angriffen (`_filterVisibleTargets()`)
- ✅ **Ghost-Darstellung:** Gegner auf aufgedeckten, aber nicht sichtbaren Feldern werden mit 40% Opazität als Ghost angezeigt
- ✅ **Service-Weitergabe:** `ScreenMain` instanziiert den Service und reicht ihn an alle Komponenten weiter

---

## Features

Das Fog-of-War-Modul bietet aktuell folgende Features:

### ✅ Implementiert

| # | Feature | Details |
|---|---------|---------|
| 1 | **Zwei Sichtbarkeitsebenen** | `visibleHexes` (aktuell) + `revealedHexes` (kumulativ) |
| 2 | **Per-Token-Sichtweite** | Jeder Token hat ein `fieldOfView`-Attribut (Default: 3 Hex-Felder) |
| 3 | **Terrain-basierte Sichtblockade** | `TerrainConfig.blocksVision` für `wall`, `ruin`, `forest` |
| 4 | **Line-of-Sight-Prüfung** | Cube-Koordinaten-DDA für präzise Sichtlinien auf Hex-Gittern |
| 5 | **LoS-Caching** | Performance-Optimierung mit Symmetrie-Ausnutzung |
| 6 | **Sichtbare Gegner abfragen** | `getVisibleEnemies()` für KI/Gameplay-Logik |
| 7 | **Reset-Funktion** | Für Kartenwechsel und Spiel-Neustart |
| 8 | **Tote Einheiten tragen nicht zur Sicht bei** | `woundValue <= 0` wird übersprungen |
| 9 | **Kartenrand-Sicherheit** | `isInBounds()`-Prüfung verhindert Out-of-Bounds-Fehler |
| 10 | **Umfassende Tests** | 18 Tests in `test/fog_of_war_test.dart` |
| 11 | **Visuelle Darstellung** | `_HexMapPainter._drawFogOfWar()` überzeichnet nicht sichtbare Felder |
| 12 | **Runden-Integration** | `computeVisibility()` wird zu Beginn jeder Runde aufgerufen |
| 13 | **KI-Integration** | `ObjectHost._filterVisibleTargets()` – KI greift nur sichtbare Ziele an |
| 14 | **Ghost-Darstellung** | `getRevealedEnemies()` + 40% Opacity-Overlay für Gegner auf aufgedeckten Feldern |
| 15 | **BFS-Queue optimiert** | `Queue.removeFirst()` (O(1)) statt `List.removeAt(0)` (O(n)) |
| 16 | **`fieldOfView` begrenzt** | `maxFieldOfView = 50` verhindert Performance-Probleme |
| 17 | **Kapselung** | `visibleHexes`/`revealedHexes` sind privat mit unveränderlichen Gettern |
| 18 | **Event/Callback bei Sichtbarkeitsänderung** | `ChangeNotifier` + `visibilityVersion` + automatisches Neuzeichnen im Painter |

### ❌ Noch nicht implementiert

| # | Feature | Beschreibung |
|---|---------|-------------|
| 1 | **Performance-Tests in der CI** | Benchmark-Tests sind in `nightly.yml` und `release.yml` integriert (Stand: August 2026) |

---

## Probleme

### ✅ Problem 1 (behoben): Keine Integration in die Spiel-UI

Der `FogOfWarService` war vollständig implementiert, aber es gab **keine einzige Verwendung** außerhalb der Tests. Das bedeutet:

- Der Spieler sieht immer die komplette Karte (kein Fog of War)
- `computeVisibility()` wird nie aufgerufen
- `isVisible()` / `isRevealed()` werden nie abgefragt
- `getVisibleEnemies()` wird nie von der KI genutzt

**Lösung (umgesetzt):**

| Datei | Änderung |
|-------|----------|
| `lib/screens/screen_main.dart` | `FogOfWarService` instanziieren und an `WidgetMapLoader` + `WidgetCaretaker` weiterreichen |
| `lib/widgets/widget_map_loader.dart` | `fogOfWarService`-Parameter + `_drawFogOfWar()` im `_HexMapPainter` |
| `lib/widgets/widget_caretaker.dart` | `_computeFogOfWar()` zu Beginn jeder Runde aufrufen |
| `lib/objects/object_host.dart` | `_filterVisibleTargets()` für KI-Verhalten |

### ✅ Problem 2 (behoben): BFS-Queue verwendet `removeAt(0)`

**Vorher:** `removeAt(0)` auf einer `List` ist **O(n)** – bei großen Karten und vielen Tokens kann das die Performance beeinträchtigen.

**Lösung (umgesetzt):** `Queue` aus `dart:collection` mit `removeFirst()` (O(1)):

```dart
import 'dart:collection';

final queue = Queue<(int x, int y, int distance)>();
queue.add((tokenHexX, tokenHexY, 0));

while (queue.isNotEmpty) {
  final (currentX, currentY, distance) = queue.removeFirst();
  // ...
}
```

### ✅ Problem 3 (behoben): `visibleHexes` und `revealedHexes` sind public

**Vorher:** Die Sets waren mit `@visibleForTesting` markiert, aber **public**. Jeder Code konnte sie direkt mutieren.

**Lösung (umgesetzt):** Private Felder mit unveränderlichen Gettern:

```dart
final Set<int> _visibleHexes = {};
final Set<int> _revealedHexes = {};

@visibleForTesting
Set<int> get visibleHexes => Set.unmodifiable(_visibleHexes);

@visibleForTesting
Set<int> get revealedHexes => Set.unmodifiable(_revealedHexes);
```

### ✅ Problem 4 (behoben): Kein Event/Callback bei Sichtbarkeitsänderung

**Lösung (umgesetzt):** `FogOfWarService` ist ein `ChangeNotifier` mit einem `visibilityVersion`-Zähler. Bei jeder Sichtbarkeitsänderung wird `_visibilityVersion++` und `notifyListeners()` aufgerufen. Der `_WidgetMapLoaderState` lauscht via `addListener(_onFogOfWarChanged)` und löst `setState` aus. Der `_HexMapPainter` friert die Versionsnummer beim Bau ein (`_fogVisibilityVersion`) und vergleicht sie in `shouldRepaint()` mit dem alten Painter – so wird die Karte automatisch neu gezeichnet, sobald sich die Sichtbarkeit ändert.

**Beteiligte Dateien:**
| Datei | Änderung |
|-------|----------|
| `lib/services/fog_of_war.dart` | `visibilityVersion`-Zähler + `notifyListeners()` in `computeVisibility()` und `reset()` |
| `lib/widgets/widget_map_loader.dart` | `_onFogOfWarChanged()`-Listener + `_fogVisibilityVersion`-Vergleich in `shouldRepaint()` |

### ✅ Problem 5 (behoben): `fieldOfView` ist nicht begrenzt

**Vorher:** `fieldOfView` konnte beliebig groß sein. Bei sehr großen Werten (z. B. 100) würde die BFS über die gesamte Karte laufen – potenziell teuer bei großen Karten.

**Lösungsansatz (umgesetzt):** Eine statische Obergrenze `maxFieldOfView` in `FogOfWarService`:

```dart
/// Maximale Sichtweite in Hex-Feldern, um die BFS-Erkundung zu begrenzen.
///
/// Verhindert, dass ein sehr großer [ObjectToken.fieldOfView] die gesamte
/// Karte erkundet und die Performance beeinträchtigt. Der Wert ist bewusst
/// großzügig gewählt (größer als jede realistische Karten-Diagonale),
/// sodass er im Normalfall nie erreicht wird.
static const int maxFieldOfView = 50;
```

In `computeVisibility()` wird der Wert geclampft:

```dart
fieldOfView: token.fieldOfView.clamp(0, maxFieldOfView),
```

**Effekt:** Auch bei `fieldOfView = 1000` wird die BFS auf maximal 50 Hex-Felder begrenzt. Die Karten-Diagonale der größten Karten (30×30) beträgt ~42 Hex-Felder, sodass der Wert im Normalfall nie erreicht wird.

### ✅ Problem 6 (behoben): Fog of War wird nicht immer bei Tokenbewegung geupdated

**Ursache:** Zwei Probleme verhinderten eine zuverlässige Aktualisierung:

1. **`_HexMapPainter.shouldRepaint()` verglich die Live-Versionsnummern** beider Painter. Da beide Painter dieselbe `FogOfWarService`-Instanz referenzieren, waren die Versionsnummern immer identisch → `shouldRepaint` gab immer `false` zurück, und die Karte wurde nie neu gezeichnet.

2. **`_computeFogOfWar()` wurde innerhalb des `setState`-Callbacks von `_handleDragEnd()` aufgerufen.** Der `notifyListeners()`-Aufruf im Fog-Service löste einen verschachtelten `setState` aus, was zu unzuverlässigen Updates führen konnte.

**Lösung (umgesetzt):**

| Datei | Änderung |
|-------|----------|
| `lib/widgets/widget_map_loader.dart` | `_HexMapPainter` friert die Fog-Versionsnummer beim Bau ein (`_fogVisibilityVersion`) und vergleicht sie in `shouldRepaint()` mit dem alten Painter |
| `lib/widgets/widget_caretaker.dart` | `_computeFogOfWar()` wird **nach** dem `setState`-Callback aufgerufen, um verschachtelte `setState`-Aufrufe zu vermeiden |

### ✅ Problem 7 (behoben): Layout unzentriert

**Ursache:** Die Karte war bündig mit dem linken Rand (`Positioned.fill` ohne Padding). Tokens, die links spawnen, wurden von der Info-Panel-Box (CombatActions) verdeckt.

**Lösung (umgesetzt):**

| Datei | Änderung |
|-------|----------|
| `lib/screens/screen_main.dart` | 240px linkes Padding für `WidgetMapLoader` und `WidgetCaretaker` – die Karte beginnt rechts neben dem Info-Panel |
| `lib/screens/screen_main.dart` | `_focusCameraOn()` berücksichtigt die 240px Panel-Breite bei der Kamera-Zentrierung |
| `lib/widgets/widget_caretaker.dart` | `_getVisibleMapRect()` verwendet die LayoutBuilder-Constraints (`_lastConstraints`) statt `context.size`/`MediaQuery` – korrektes Viewport-Culling im gepaddeten Bereich |
| `lib/widgets/widget_caretaker.dart` | Info-Panel wird mit `left: -232` in die 240px-Gutter-Spalte positioniert – **nicht** über der Karte |

**Layout-Entscheidung (beantwortet):**

- **Info-Panel (CombatActions):** Sitzt jetzt in der **240px-Gutter-Spalte** links (Screen-x: 8..228) – die Karte beginnt bei x=240. Das Panel verdeckt **keine** Karteninhalte mehr.
- **Rundentimer (oben rechts):** Bleibt bewusst als **HUD-Overlay** über der Karte (Screen-x: rechts oben). Das ist der Standard in Strategiespielen (z. B. XCOM, Fire Emblem) – der Timer ist eine permanente Statusanzeige und soll immer sichtbar sein, auch beim Scrollen/Zoomen. Er verdeckt nur einen kleinen Bereich oben rechts, der für Gameplay selten kritisch ist.

---

## Offene Fragen

### ✅ Frage 1 (beantwortet): Wie soll der Fog of War visuell dargestellt werden?

**Gewählte Option:** **(b) Canvas-Clipping** – `_HexMapPainter._drawFogOfWar()` zeichnet pro Hex ein abgedunkeltes/schwarzes Overlay mittels `canvas.clipPath(hexPath)`.

### ✅ Frage 2 (beantwortet): Wann soll `computeVisibility()` aufgerufen werden?

**Gewählte Option:** **(a) Zu Beginn jeder Runde** – `WidgetCaretaker._computeFogOfWar()` wird in `_startNewRound()` aufgerufen.

### ✅ Frage 3 (beantwortet): Soll der Fog of War die KI beeinflussen?

**Gewählte Option:** **(a) Ja** – `ObjectHost._filterVisibleTargets()` filtert Ziele, die nicht auf sichtbaren/aufgedeckten Feldern stehen.

### ✅ Frage 4 (beantwortet): Soll `revealedHexes` beim Kartenwechsel zurückgesetzt werden?

**Gewählte Option:** **(a) Ja** – `reset()` wird beim Laden einer neuen Karte aufgerufen.

### ✅ Frage 5 (beantwortet): Wie soll mit Tokens auf nicht-sichtbaren Feldern umgegangen werden?

**Gewählte Option:** **(b) Ghost-Darstellung** – Gegner auf aufgedeckten, aber nicht sichtbaren Feldern werden mit 40% Opazität angezeigt. Die Position wird über `getRevealedEnemies()` ermittelt.

---

## Mögliche Erweiterungen

### ✅ Erweiterung 1 (umgesetzt): Visuelle Darstellung im Karten-Renderer

**Status:** ✅ **Umgesetzt**

- `lib/widgets/widget_map_loader.dart` – `_drawFogOfWar()` im `_HexMapPainter`
- Sichtbare Felder: kein Overlay
- Aufgedeckte Felder: 50% schwarzes Overlay (`Color(0x80000000)`)
- Verdeckte Felder: komplett schwarz (`Color(0xFF000000)`)

### ✅ Erweiterung 2 (umgesetzt): BFS-Queue optimieren

**Status:** ✅ **Umgesetzt**

`lib/services/fog_of_war.dart` verwendet jetzt `Queue` aus `dart:collection` mit `removeFirst()` (O(1)) statt `List.removeAt(0)` (O(n)).

### ✅ Erweiterung 3 (umgesetzt): `visibleHexes`/`revealedHexes` kapseln

**Status:** ✅ **Umgesetzt**

Private Felder (`_visibleHexes`, `_revealedHexes`) mit unveränderlichen Gettern (`Set.unmodifiable`) für Tests.

### ✅ Erweiterung 4 (umgesetzt): KI-Integration

**Status:** ✅ **Umgesetzt**

- `lib/objects/object_host.dart` – `setFogOfWarService()` + `fogOfWarService`-Feld
- `_filterVisibleTargets()` filtert Ziele auf nicht sichtbaren/aufgedeckten Feldern
- Greift in `moveAllZombiesTowardsTargets()` und `performAllZombieAttacks()`

### ✅ Erweiterung 5 (umgesetzt): Runden-Integration

**Status:** ✅ **Umgesetzt**

- `lib/widgets/widget_caretaker.dart` – `_computeFogOfWar()` wird in `_startNewRound()` aufgerufen
- Verwendet `fogOfWarService` + `terrainMap` aus dem Widget

### ✅ Erweiterung 6 (umgesetzt): Ghost-Darstellung für Tokens

**Status:** ✅ **Umgesetzt**

- `lib/services/fog_of_war.dart` – neue Methode `getRevealedEnemies()`
- `lib/widgets/widget_caretaker.dart` – `_ghostTokenPositions` + 40% Opacity-Overlay
- Ghost-Positionen werden nach jeder Sichtbarkeits-Berechnung aktualisiert

### ✅ Erweiterung 7 (umgesetzt): Performance-Tests

**Status:** ✅ **Umgesetzt**

- `test/fog_of_war_test.dart` – neue Performance-Gruppe mit 4 Tests:
  - `computeVisibility` auf 30×30-Karte mit 20 Tokens (< 1 Sekunde)
  - `fieldOfView` wird auf `maxFieldOfView` geclampft
  - `getRevealedEnemies` liefert Gegner auf aufgedeckten Feldern
  - `getRevealedEnemies` liefert nichts für Gegner auf verdeckten Feldern

### ✅ Erweiterung 8 (umgesetzt): Event/Callback bei Sichtbarkeitsänderung

**Status:** ✅ **Umgesetzt**

- `FogOfWarService` ist ein `ChangeNotifier` mit `visibilityVersion`-Zähler
- `_WidgetMapLoaderState` lauscht via `addListener(_onFogOfWarChanged)` und löst `setState` aus
- `_HexMapPainter.shouldRepaint()` vergleicht die eingefrorene `_fogVisibilityVersion` mit dem alten Painter
- Die Karte wird automatisch neu gezeichnet, sobald sich die Sichtbarkeit ändert (kein manuelles `setState` mehr nötig)

---

## Zusammenfassung

| Bereich | Status |
|---------|--------|
| **Service-Implementierung** | ✅ Vollständig (`FogOfWarService` in `lib/services/fog_of_war.dart`) |
| **Tests** | ✅ 18 Tests in `test/fog_of_war_test.dart` |
| **Visuelle Darstellung** | ✅ Implementiert (`_HexMapPainter._drawFogOfWar()`) |
| **Spiel-Integration** | ✅ Implementiert (`ScreenMain` + `WidgetCaretaker`) |
| **KI-Integration** | ✅ Implementiert (`ObjectHost._filterVisibleTargets()`) |
| **Runden-Integration** | ✅ Implementiert (`_computeFogOfWar()` in `_startNewRound()`) |
| **Ghost-Darstellung** | ✅ Implementiert (`getRevealedEnemies()` + 40% Opacity) |
| **Performance** | ✅ BFS-Queue O(1), `maxFieldOfView = 50`, Performance-Tests |
| **Kapselung** | ✅ Private Felder mit unveränderlichen Gettern |

**Verbleibende offene Punkte:**

1. 🟢 **Performance-Tests in die CI integrieren** – Benchmark-Tests wurden in `nightly.yml` und `release.yml` ergänzt (Analyze & Test-Job)
