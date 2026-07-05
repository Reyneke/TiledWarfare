# Bug Report #001: Zombie wird nach Tod durch neuen Zombie ersetzt

## Beschreibung

Wenn ein bereits angeschlagener Zombie (aktuelle `woundValue` < Startwert) erfolgreich angegriffen wird und seine `woundValue` dabei unter 0 sinkt, wird er bei der nächsten Aktion des Spielers nicht zuverlässig vom Spielfeld entfernt. Stattdessen erscheint ein neuer Zombie an seiner Stelle oder in der Nähe, sodass es aussieht, als wäre der Zombie ersetzt worden.

## Reproduktionsschritte

1. Einen Zombie durch vorherige Kämpfe auf `woundValue ≤ 2` reduzieren
2. Den Zombie mit einem Line Cook angreifen (Nahkampf oder Fernkampf)
3. Beobachten, dass der Zombie-Schaden korrekt berechnet wird
4. **Bei der nächsten Aktion** (z. B. nächster Angriff oder Bewegung eines anderen Tokens) erscheint ein neuer Zombie auf dem Spielfeld

## Erwartetes Verhalten

Ein Zombie mit `woundValue ≤ 0` sollte sofort vom Spielfeld entfernt werden und nicht wieder erscheinen.

## Tatsächliches Verhalten

Nach dem Tod eines Zombies erscheint bei der nächsten Spielaktion ein neuer Zombie, als wäre der ursprüngliche Zombie ersetzt worden.

## Fehlerursachen (analysiert)

### Ursache 1: Zombie-Spawning in `performAllZombieAttacks()`
**Datei:** `lib/objects/object_host.dart`, Zeilen 360–456

Wenn ein Zombie während des Host-Zugs einen Line Cook angreift und **beide sterben** (Zombie durch Patzer/kritische Verteidigung, Cook durch Treffer), passiert Folgendes:

1. Zombie erleidet Selbstschaden → `woundValue ≤ 0` (Zeile 403)
2. Zombie wird zu `zombiesToRemove` hinzugefügt (Zeile 405)
3. `break` beendet die innere Schleife (Zeile 406)
4. **ABER**: Der Spieler-Token ist ebenfalls tot → die Spawning-Logik (50% neuer Zombie / 25% neuer Dumpster) in Zeile 414–437 wird **trotzdem** ausgeführt, weil `break` erst nach dieser Logik kommt

**Problem:** Der `break` in Zeile 406 verhindert nur weitere Angriffe des toten Zombies. Die Spawning-Logik in den Zeilen 414–437 wurde bereits vor dem `break` ausgeführt (sie ist im selben Schleifendurchlauf davor). Dadurch entsteht ein neuer Zombie aus den Überresten des Line Cooks, während der ursprüngliche Zombie stirbt.

### Ursache 2: Cache-Timing in WidgetCaretaker
**Datei:** `lib/widgets/widget_caretaker.dart`, Zeilen 761–767

```dart
List<_TokenRenderInfo> get _allTokens {
  if (_cacheDirty || _cachedAllTokens == null) {
    _cachedAllTokens = _buildAllTokens();
    _cacheDirty = false;
  }
  return _cachedAllTokens!;
}
```

Wenn `_allTokens` während des Builds vor `_removeDeadTokens()` aufgerufen wird, könnte der Zombie mit `woundValue ≤ 0` noch im gecachten Token-Listing auftauchen. Der Build-Prozess in `_handleTap()` ruft `setState()` auf → Build → `_buildTokenWidgets()` → `_allTokens`. Wenn der Cache zu diesem Zeitpunkt noch nicht invalidiert wurde, wird der tote Zombie noch angezeigt.

**Problem:** Der Cache (`_cacheDirty`) wird durch `_invalidateCache()` zurückgesetzt, aber `_removeDeadTokens()` ruft `_invalidateCache()` auf (Zeile 1096). Wenn zwischen `woundValue`-Änderung und Cache-Invalidierung ein Build stattfindet, wird der tote Zombie noch gezeichnet.

### Ursache 3: `_removeDeadTokens()` wird nicht bei jeder Aktion aufgerufen
**Datei:** `lib/widgets/widget_caretaker.dart`, Zeile 913–964

```dart
void _handleDragEnd() {
  // ...
  _draggedToken!.position = snappedPosition;
  // ...
  _invalidateCache();
  _checkAutoEndPlayerTurn();
}
```

`_removeDeadTokens()` wird in `_executeActionOnTarget()` (Zeile 1045) aufgerufen, aber **NICHT** in `_handleDragEnd()`. Ein Zombie, der bereits `woundValue ≤ 0` hat (z. B. durch einen früheren Patzer), wird durch `_invalidateCache()` zwar aus dem Render-Cache entfernt, aber **nicht** aus `dumpster.zombieList` gelöscht.

**Problem:** Die `_removeDeadTokens()`-Methode (Zeile 1075–1097) wird nur bei Angriffs-Aktionen aufgerufen, nicht bei Bewegungen. Wenn ein Zombie zwischenzeitlich stirbt (z. B. durch Patzer beim Verteidigen), wird er erst beim nächsten Angriff tatsächlich aus der Liste entfernt. Bis dahin kann er bei `_buildAllTokens()` wieder auftauchen, wenn der Cache invalidiert wurde.

### Ursache 4 (primär): Zombie-Spawning alle 2 Runden
**Datei:** `lib/objects/object_host.dart`, Zeilen 460–489

```dart
List<String> performAllDumpsterSpawning() {
  // ...
  for (final dumpster in doughDumpsterList.toList()) {
    final newZombies = dumpster.spawnZombies();
    // ...
  }
}
```

Diese Methode wird in `_executeHostSpawning()` (WidgetCaretaker Zeile 500–505) aufgerufen, welche Teil von `_executeHostTurn()` ist (Zeile 465–497). Der Spawning-Log im Code (Zeile 472) kommentiert "alle 2 Runden" – tatsächlich wird `performAllDumpsterSpawning()` **jede Runde** aufgerufen, in der der Host am Zug ist.

Dough Dumpster spawnen 1w6 Zombies pro Spawning-Durchlauf. Wenn also ein Zombie stirbt, spawnen die Dumpster in der nächsten Runde einfach neue Zombies nach. **Aus Spielersicht sieht das aus wie eine Ersetzung des toten Zombies.**

## Lösungsvorschläge

### Fix 1: Zombie-Tod vor Spawning-Logik prüfen (ObjectHost)
In `performAllZombieAttacks()` sollte nach dem Angriff zuerst geprüft werden, ob der **angreifende Zombie** gestorben ist. Wenn ja, sollte `break` sofort erfolgen, ohne die Spawning-Logik für den getöteten Line Cook auszulösen.

### Fix 2: `_removeDeadTokens()` in `_handleDragEnd()` aufrufen (WidgetCaretaker)
Nach einer Bewegung sollte ebenfalls `_removeDeadTokens()` aufgerufen werden, um sicherzustellen, dass zwischenzeitlich gestorbene Tokens tatsächlich entfernt werden.

### Fix 3: Spawning-Intervall korrigieren (WidgetCaretaker)
`performAllDumpsterSpawning()` sollte nicht jede Runde aufgerufen werden, sondern nur alle 2 Runden, wie im Kommentar angegeben. Dazu müsste ein Zähler eingeführt werden.

## Betroffene Dateien

| Datei | Zeilen | Relevanz |
|-------|--------|----------|
| `lib/objects/object_host.dart` | 360–456 | Hoch – Spawning-Logik nach Zombie-Tod |
| `lib/widgets/widget_caretaker.dart` | 761–767 | Mittel – Cache-Timing |
| `lib/widgets/widget_caretaker.dart` | 1075–1097 | Mittel – Fehlender Aufruf von `_removeDeadTokens()` |
| `lib/widgets/widget_caretaker.dart` | 500–505 | Niedrig – Spawning-Intervall |

## Priorität

**Hoch** – Das Verhalten ist irreführend für den Spieler und beeinträchtigt das Spielerlebnis erheblich. Zombies, die scheinbar nicht sterben, untergraben das Vertrauen in die Kampfmechanik.

## Gemeldet von

Code-Analyse basierend auf Projektdokumentation (Stand: Juli 2026)