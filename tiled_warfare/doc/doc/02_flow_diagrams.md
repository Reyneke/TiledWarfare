# Ablaufpläne

## 1. Spielstart (App-Initialisierung)

```
main()
  │
  ├─ WidgetsFlutterBinding.ensureInitialized()
  │
  └─ runApp(MainApp)
        │
        └─ MainApp.build()
              │
              └─ MaterialApp(theme, darkTheme, home: ScreenMain)
                    │
                    └─ ScreenMain.build()
                          │
                          ├─ AppBar (Titel + Theme-Umschalter)
                          │
                          └─ Stack
                                ├─ WidgetMapLoader (Hintergrund)
                                │     │
                                │     ├─ initState()
                                │     │     ├─ TransformationController → Callback
                                │     │     └─ _loadMap()
                                │     │           │
                                │     │           ├─ TMX-Datei laden & parsen
                                │     │           ├─ Tile-Daten extrahieren
                                │     │           ├─ Tileset-Bild laden
                                │     │           ├─ Spawnpunkte parsen → Callback
                                │     │           └─ Kartendimensionen → Callback
                                │     │
                                │     └─ build()
                                │           └─ InteractiveViewer
                                │                 └─ CustomPaint(_HexMapPainter)
                                │
                                └─ WidgetCaretaker (Vordergrund)
                                      │
                                      ├─ initState()
                                      │     ├─ _initializeGameObjects()
                                      │     │     ├─ Spawnpunkte auswählen
                                      │     │     ├─ 3x Line Cooks spawnen
                                      │     │     ├─ 1x Dough Dumpster spawnen
                                      │     │     └─ Start-Zombies spawnen
                                      │     │
                                      │     └─ addPostFrameCallback → _startNewRound()
                                      │
                                      └─ build()
                                            ├─ Transform(matrix) → Token-Overlay
                                            ├─ Info-Panel (selektierter Token)
                                            └─ Status-Panel (Runde, Initiative, etc.)
```

## 2. Rundenablauf

```
_startNewRound()
  │
  ├─ _currentRound++
  │
  ├─ _resetRoundState()
  │     ├─ Für jeden Line Cook: movementValue reset, hasActed = false
  │     └─ Für jeden Dumpster & Zombie: movementValue reset, hasActed = false
  │
  ├─ Initiative-Würfe
  │     ├─ _player.rollInitiative() → W100
  │     └─ _host.rollInitiative() → W100
  │
  ├─ Vergleich
  │     ├─ Spieler > Host → _isPlayerTurn = true
  │     ├─ Host > Spieler → _isHostTurn = true
  │     └─ Gleichstand → Münzwurf / gleiche Reihenfolge
  │
  ├─ Wenn _isHostTurn:
  │     └─ _executeHostTurn()
  │           ├─ _executeHostSpawning()
  │           │     └─ Dumpster.spawnZombies() → 1w6 neue Zombies
  │           │
  │           ├─ _executeHostMovement()
  │           │     └─ moveAllZombiesTowardsLineCooks()
  │           │           └─ Pro Zombie: nächstes Ziel finden → 1 Hex-Schritt
  │           │
  │           ├─ _executeHostAttacks()
  │           │     └─ performAllZombieAttacks()
  │           │           └─ Pro Zombie in Reichweite: Nahkampf-Angriff
  │           │
  │           ├─ _removeDeadTokens()
  │           │
  │           ├─ _checkGameOver()
  │           │
  │           └─ _startNewRound() (rekursiv)
  │
  └─ setState() → UI aktualisieren
```

## 3. Spieler-Zug (Interaktion)

```
Spieler tippt auf Karte
  │
  └─ _handleTap(tapPosition)
        │
        ├─ _findTokenAtPosition(tapPosition)
        │     └─ Hitbox-Prüfung für alle Tokens
        │
        ├─ Wenn _pendingAction != null (Targeting-Modus):
        │     └─ _handleTapInTargetingMode(tappedToken)
        │           ├─ Wenn targetierbar: _executeActionOnTarget()
        │           └─ Sonst: abbrechen
        │
        ├─ Wenn Token getroffen:
        │     └─ _selectedToken = tappedToken
        │
        └─ Sonst: Deselektieren

Spieler zieht Token (Drag & Drop)
  │
  ├─ _handleDragStart()
  │     └─ Token unter Startposition finden → _draggedToken setzen
  │
  ├─ _handleDragUpdate(delta)
  │     └─ _dragOffset += delta (skaliert mit Zoom)
  │
  └─ _handleDragEnd()
        ├─ Neue Position = token.position + _dragOffset
        ├─ _snapToNearestFreeHex() → nächstes freies Hex-Feld
        ├─ Entfernungsprüfung (≤ movementValue)
        ├─ Bewegungspunkte abziehen
        ├─ Token.position = snappedPosition
        └─ _checkAutoEndPlayerTurn()

Spieler langer Druck → Kontextmenü
  │
  └─ _showContextMenu()
        ├─ Info anzeigen (Werte des Tokens)
        ├─ Nahkampf auswählen → _enterTargetingMode(melee)
        └─ Fernkampf auswählen → _enterTargetingMode(ranged)
```

## 4. Kampfablauf (Combat)

```
performAction(action, attacker, defender, distance)
  │
  ├─ Effektiven Angriffswert bestimmen
  │     ├─ Nahkampf: attackValue (unverändert)
  │     └─ Fernkampf: attackValue − Malus (0/10/20 basierend auf Entfernung)
  │
  ├─ Angreifer würfelt W100
  │     ├─ ≤ 5  → kritischer Erfolg
  │     ├─ > 90 → Patzer
  │     └─ sonst → normal
  │
  ├─ Verteidiger würfelt W100
  │     ├─ ≤ 5  → kritischer Erfolg
  │     ├─ > 90 → Patzer
  │     └─ sonst → normal
  │
  └─ Ergebnisbestimmung (siehe combat_rules.md)
        ├─ Patzer Angreifer → Selbstschaden (halber damageValue)
        ├─ Kritisch Verteidiger → Gegenangriff (halber Schaden)
        ├─ Kritisch Angreifer → doppelter Schaden
        ├─ Patzer Verteidiger → doppelter Schaden
        ├─ Angreifer trifft, Verteidiger verfehlt → Schaden
        ├─ Beide treffen → Vergleichswert-Vergleich
        │     ├─ Angreifer besser → Schaden
        │     ├─ Verteidiger besser → kein Schaden
        │     └─ Gleichstand → Münzwurf (W100 > 51)
        └─ Beide verfehlen → nichts
```

## 5. Zombie-Verhalten (KI)

```
moveAllZombiesTowardsLineCooks(targets)
  │
  └─ Pro Zombie:
        ├─ Nächstgelegenen Line Cook finden (Pixel-Distanz)
        ├─ Hex-Koordinaten von Zombie & Ziel ermitteln
        ├─ Differenz (dx, dy) berechnen
        ├─ Besten Nachbarn wählen (minimiert Distanz zum Ziel)
        └─ Zombie.position = neues Hex-Zentrum

performAllZombieAttacks(player)
  │
  └─ Pro Zombie:
        └─ Pro Line Cook:
              ├─ Distanz ≤ rangeValue + 1?
              │     └─ Ja: Nahkampf-Angriff ausführen
              │
              ├─ Wenn Line Cook stirbt:
              │     ├─ 50% Chance: neuer Zombie erscheint
              │     └─ 25% Chance: neuer Dough Dumpster erscheint
              │
              └─ Wenn Zombie stirbt: aus Liste entfernen
```

## 6. Viewport-Culling (Performance)

```
_buildTokenWidgets()
  │
  ├─ _getVisibleMapRect()
  │     ├─ Bildschirm-Ecken in Karten-Koordinaten umrechnen
  │     └─ Umschließendes Rechteck + 200px Rand
  │
  └─ Für jeden Token:
        ├─ Position im sichtbaren Bereich?
        │     ├─ Ja: Widget zeichnen
        │     └─ Nein: Überspringen (Culling)
        │
        └─ Für erreichbare Felder & Highlights: gleiches Culling