# Verbesserungsvorschläge für Bugs 1–4

Die folgenden Verbesserungen wurden basierend auf einer Cline-Code-Review der Bugfix-Commits vorgeschlagen.  
Jeder Vorschlag bezieht sich auf die **aktuelle Codebasis** (HEAD), nicht auf das Bug-Dokument selbst.

---

## 1. `object_player.dart` — Combat Resolution Refactoring

**Problem:** `performAction()` enthält eine ~146 Zeilen lange tief verschachtelte if/else-Kette mit 7+ Verzweigungsebenen (Attack Fumble → Defense Critical → Attack Critical → Defense Fumble → Attack Miss → Comparison → Tie-Breaker). Dies ist schwer zu testen, zu lesen und zu warten (SRP-Verletzung).

**Vorgeschlagenes Refactoring:** Extraktion der Kampfberechnung in fokussierte, single-responsibility Methoden:

```dart
CombatResult performAction({...}) {
  // ... Würfel-Logik ...
  final result = _resolveCombat(
    attacker: attacker, defender: defender,
    effectiveAttackValue: ..., effectiveDefenseValue: ...,
    attackRoll: ..., attackSuccess: ..., attackFumble: ..., attackCritical: ...,
    defenseRoll: ..., defenseSuccess: ..., defenseFumble: ..., defenseCritical: ...,
  );
  defender.timesAttackedThisTurn++;
  return result;
}

// Neue, extrahierte Methoden:
CombatResult _resolveCombat({...})       // Dispatcher für Spezialfälle
CombatResult _handleAttackerFumble(...)   // Patzer Angreifer
CombatResult _handleDefenderCritical(...) // Kritischer Erfolg Verteidiger
CombatResult _handleAttackerCritical(...) // Kritischer Erfolg Angreifer
CombatResult _handleDefenderFumble(...)   // Patzer Verteidiger
CombatResult _handleMiss(...)             // Verfehlt
CombatResult _resolveNormalCombat({...})  // Vergleichswert-System
```

**Vorteil:** Jede Methode ist unabhängig testbar, lesbar und änderbar. `performAction()` selbst bleibt als schlanker ~30-Zeiler erhalten.

---

## 2. `screen_main.dart` — Memory Leak in `_focusCameraOn`

**Problem:** Jedes Mal, wenn der Spieler einen Token antippt (Token-Auswahl → Kamera-Fokus), erzeugt `_focusCameraOn()` einen neuen `AnimationController`, aber **disposed ihn nie**. Bei mehrfachem Tappen in einer Runde entsteht ein Memory Leak.

**Fix:** Den aktiven AnimationController in einem Feld speichern, vor Neuerstellung disposten, und einen `addStatusListener` zum Auto-Dispose bei Animation-Ende hinzufügen.

```dart
AnimationController? _focusAnimationController;

void _focusCameraOn(Offset mapPosition) {
  _focusAnimationController?.dispose(); // Vorherigen disposten!
  // ...
  final animationController = AnimationController(vsync: this, duration: ...);
  _focusAnimationController = animationController;
  // ...
  animationController.addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      animationController.dispose();
      if (_focusAnimationController == animationController) {
        _focusAnimationController = null;
      }
    }
  });
  animationController.forward();
}
```

**Vorteil:** Verhindert Memory Leaks bei mehrfachem Token-Auswählen.

---

## 3. `screen_battle_result.dart` — Dead Code `statusBefore`

**Problem:** `_CharacterResult` sammelt und speichert `statusBefore` (vom Typ `CharacterStatus`), aber dieser Wert wird **nirgendwo in der UI angezeigt**. Es ist ein toter Datenpunkt, der nur Komplexität hinzufügt.

**Fix:** `statusBefore` aus `_CharacterResult` entfernen.

```dart
class _CharacterResult {
  // statusBefore entfernt
  final String name;
  final String characterType;
  final bool wasAlive;
  final int oldLevel;
  final int newLevel;
  final int xpGained;
  final bool leveledUp;
}
```

**Vorteil:** Saubereres Datenmodell, weniger Speicherverbrauch, keine unnötige Abhängigkeit von `CharacterStatus`.

---

## 4. `widget_caretaker.dart` — Duplicate Game-Over Checking

**Problem:** Sowohl `_executeActionOnTarget()` als auch `_executeFocusFireOnTarget()` enthalten identische 7-Zeilen-Blöcke zur Spielende-Prüfung und zum automatischen Zug-Ende.

**Fix:** Extraktion in eine gemeinsame Methode `_handlePostCombatState()`:

```dart
bool _handlePostCombatState() {
  if (_host.isDefeated) {
    _isGameOver = true;
    _statusMessage = 'Spieler hat gewonnen! Alle Gegner besiegt.';
    setState(() {});
    return true; // Spiel beendet
  }
  _checkAutoEndPlayerTurn();
  return false; // Spiel läuft weiter
}
```

Beide Aufrufer ersetzen ihre Blöcke durch:
```dart
if (_handlePostCombatState()) return;
```

**Vorteil:** DRY-Prinzip, konsistentes Verhalten, Änderungen an der Post-Combat-Logik nur an einer Stelle.

---

## 5. `widget_caretaker.dart` — Frame-Rate Dependent Animation

**Problem:** `_animateTokens()` verwendet `currentPos + diff * 0.25` pro Frame. Dies macht die Animationsgeschwindigkeit von der Bildwiederholrate abhängig (schneller auf 120 Hz, langsamer auf 60 Hz). Zusätzlich verwendet es `token._animationStart`, das auf `ObjectToken` nicht existiert.

**Fix:** Stattdessen den normierten Fortschritt `[0..1]` des `AnimationController` verwenden, der bereits eine feste Dauer von 300ms hat:

```dart
void _animateTokens() {
  final progress = _tokenAnimationController?.value ?? 0.0;
  final t = 1.0 - (1.0 - progress) * (1.0 - progress); // ease-out
  
  for (final renderInfo in _allTokens) {
    final token = renderInfo.token;
    if (token.targetPosition == null) continue;
    
    if (!_tokenAnimationStarts.containsKey(token)) {
      _tokenAnimationStarts[token] = token.position;
    }
    
    token.position = Offset.lerp(
      _tokenAnimationStarts[token]!,
      token.targetPosition!, t,
    )!;
    
    if (progress >= 1.0) {
      token.position = token.targetPosition!;
      token.targetPosition = null;
      _tokenAnimationStarts.remove(token);
    }
  }
}
```

**Vorteil:** Konsistente Animationsgeschwindigkeit auf allen Displays, keine nicht existierenden Felder.

1. Karte wieder linkszentriert.
2. Bewegungsaanimation von host Tokens endet nicht, sondern loopt ewig. Dadurch hören die Tokens nicht auf sich zu bewegen.
3. Kampfergebnis zeigt immer noch "0 Überlebende" und "0 Gefallene". Plus nach klick auf "weiter" endet man im ScreenStart.