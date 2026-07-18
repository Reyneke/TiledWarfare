Es gibt ein paar Bugs, die aufgefallen sind:
1. Tokens unter der Kontrolle des Hosts scheinen immer noch in der Lage zu sein auf Tokens, die vom Spieler kontrolliert werden, zu stacken. Warum?
2. Am Ende eines Spiels, landet der Spieler im Startbildschirm, anstelle im Restaurantbildschirm.
3. Es sieht aus, als wenn Berletzungen und dergleichen am Ende eines Spiels nicht korrekt zwischen "screen_main.dart" und "screen_restaurant.dart" übertragen werden, da ich sie im "screen_restaurant.dart" nicht sehe. Warum?

---

## Ursachenanalyse und Lösungen

### Bug 1: Host-Tokens stacken auf Spieler-Tokens

**Ursache:**
In `object_host.dart` (`performAllDumpsterSpawning()`, Zeile ~572) wird `_buildOccupiedHostHexes()` **ohne** den Parameter `playerUnits` aufgerufen:
```dart
final occupied = _buildOccupiedHostHexes(); // Fehlt: playerUnits: targets
```

Das bedeutet, dass die Spieler-Einheiten beim Spawning neuer Zombies **nicht als belegte Felder** berücksichtigt werden. Zombies können daher direkt auf Spieler-Tokens spawnen.

**Vergleich:** In `_moveZombieTowardsTarget()` (Zeile ~311) wird `_buildOccupiedHostHexes(playerUnits: targets)` korrekt mit Spieler-Einheiten aufgerufen, weshalb die Bewegung selbst die Kollision vermeidet – nur das Spawning nicht.

**Fix:**
```dart
final occupied = _buildOccupiedHostHexes(playerUnits: targets);
```
wobei `targets` als Parameter an `performAllDumpsterSpawning()` übergeben werden muss.

### Bug 2: Navigation zum Startbildschirm statt Restaurant

**Ursache:**
In `widget_caretaker.dart`, Methode `_returnToRestaurant()` (Zeile ~1201-1206):
```dart
Navigator.of(context).popUntil((route) => route.isFirst);
```
`popUntil(route.isFirst)` geht zurück zur **ersten Route** im Navigator-Stack, also zu `ScreenStart` (Startbildschirm). Der Route-Stack ist:
1. ScreenStart (erste Route)
2. ScreenRestaurant
3. ScreenMain

Stattdessen sollte nur eine Ebene zurück navigiert werden, zurück zu `ScreenRestaurant`.

**Fix:**
`Navigator.of(context).pop()` verwenden statt `popUntil(route.isFirst)`.

### Bug 3: Verletzungen nicht im Restaurant sichtbar

**Ursache:**
Dies ist eine Folge von **Bug 2**. Da `_returnToRestaurant()` zum Startbildschirm navigiert, wird `ScreenRestaurant` vom Navigator-Stack entfernt (`disposed`). Der Spieler sieht die Verletzungen nicht, weil er **nicht auf dem Restaurant-Bildschirm landet**.

Die Datenübertragung selbst **funktioniert korrekt**:
1. `_updateProfileAfterBattle()` in `widget_caretaker.dart` ruft `profile.syncUnitsAfterBattle(player.unitList)` auf
2. `ObjectProfile.syncUnitsAfterBattle()` aktualisiert die Wundwerte im Singleton und führt Rettungswürfe durch
3. `profile.saveToStorage()` persistiert die Daten

Zusätzlich: Der `onGameOver`-Callback aus `ScreenMain._onGameOver()` (`widget.onGameOver`) wird **nie aufgerufen**, weil `widget_caretaker.dart` den Callback nirgends aufruft (weder beim Spielersieg noch bei Niederlage). Allerdings ist das unkritisch, weil `_returnToRestaurant()` selbst `_updateProfileAfterBattle()` aufruft.

**Fix:**
Durch die Behebung von Bug 2 (Navigation direkt zurück zu ScreenRestaurant) wird auch Bug 3 behoben. Der Spieler landet nach dem Gefecht auf dem Restaurant-Bildschirm, der die aktuellen Daten aus dem `ObjectProfile`-Singleton anzeigt (`setState(() {})` in `_goToBattle()` aktualisiert die Ansicht).

**Zusätzliche Optimierung:**
`widget.onGameOver` sollte aufgerufen werden, wenn der `_returnToRestaurant`-Vorgang abgeschlossen ist, damit ScreenMain seinen Zustand ordentlich bereinigen kann.
