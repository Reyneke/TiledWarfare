# Klassendiagramm

## Übersicht

```
┌─────────────────────────────────────────────────────────────────┐
│                        ObjectToken                              │
│  (Basis-Klasse für alle Einheiten)                              │
├─────────────────────────────────────────────────────────────────┤
│  + name: String                                                 │
│  + imagePath: String                                            │
│  + woundValue: int                                              │
│  + attackValue: int                                             │
│  + defenseValue: int                                            │
│  + movementValue: int                                           │
│  + damageValue: int                                             │
│  + rangeValue: int                                              │
│  + position: Offset                                             │
│  + hasActed: bool                                               │
└──────────────────────┬──────────────────────────────────────────┘
                       │ extends
          ┌────────────┼─────────────┬──────────────────┐
          ▼            ▼             ▼                  ▼
┌─────────────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────────┐
│  ObjectLineCook │ │ObjectDough│ │ObjectDough   │ │ (Zukünftige  │
│  (Spieler)      │ │Zombie    │ │Dumpster      │ │  Token-Typen)│
├─────────────────┤ ├──────────┤ ├──────────────┤ │              │
│  attack: 80     │ │ attack:40│ │ wound: 50    │ │              │
│  defense: 40    │ │ defense:40│ │ attack: 0    │ │              │
│  movement: 3    │ │ movement:1│ │ movement: 0  │ │              │
│  damage: 2      │ │ damage: 1 │ │ damage: 0    │ │              │
│  range: 3       │ │ range: 0  │ │ range: 0     │ │              │
└────────┬────────┘ └──────────┘ └──────┬───────┘ └──────────────┘
         │                              │
         │ 1..*                         │ 1
         │                              │
         ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ObjectPlayer                             │
│  (Singleton – Spieler-Steuerung)                                │
├─────────────────────────────────────────────────────────────────┤
│  + lineCookList: List<ObjectLineCook>                           │
│  + spawnLineCook(): ObjectLineCook                              │
│  + removeLineCook(cook): void                                   │
│  + upgradeLineCook(cook, ...): void                             │
│  + getAvailableActions(cook): List<CombatAction>                │
│  + rollInitiative(): int                                        │
│  + performAction(action, attacker, defender, distance): Combat  │
│    Result                                                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ObjectHost                                │
│  (Singleton – KI-Gegner-Steuerung)                              │
├─────────────────────────────────────────────────────────────────┤
│  + name: String                                                 │
│  + enneagramProfile: EnneagramProfile                           │
│  + personality: HostPersonality                                 │
│  + doughDumpsterList: List<ObjectDoughDumpster>                 │
│  + spawnDoughDumpster(): ObjectDoughDumpster                    │
│  + moveAllZombiesTowardsLineCooks(targets): void                │
│  + performAllZombieAttacks(player): List<String>                │
│  + performAllDumpsterSpawning(): List<String>                   │
│  + rollInitiative(): int                                        │
│  + isDefeated: bool                                             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        WidgetCaretaker                           │
│  (StatefulWidget – Token-Verwaltung & Spiel-Logik)              │
├─────────────────────────────────────────────────────────────────┤
│  + tileWidth, tileHeight: int                                   │
│  + mapWidth, mapHeight: int                                     │
│  + transformationController: TransformationController           │
│  + spawnPoints: List<(name, x, y)>                              │
├─ Intern ────────────────────────────────────────────────────────┤
│  - _player: ObjectPlayer                                        │
│  - _host: ObjectHost                                            │
│  - _selectedToken: ObjectToken?                                 │
│  - _pendingAction: CombatAction?                                │
│  - _targetableEnemies: Set<ObjectToken>                         │
│  - _currentRound: int                                           │
│  - _isPlayerTurn, _isHostTurn, _isGameOver: bool                │
│  - _hexToPixel(), _pixelToHex()                                 │
│  - _handleTap(), _handleDragStart/Update/End()                  │
│  - _enterTargetingMode(), _executeActionOnTarget()              │
│  - _startNewRound(), _endPlayerTurn(), _executeHostTurn()       │
│  - _buildTokenWidgets(), _buildStatusPanel()                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        WidgetMapLoader                           │
│  (StatefulWidget – Karten-Ladung & -Rendering)                  │
├─────────────────────────────────────────────────────────────────┤
│  + onMapLoaded: Callback                                        │
│  + onTransformationControllerCreated: Callback                  │
│  + onSpawnPointsParsed: Callback                                │
├─ Intern ────────────────────────────────────────────────────────┤
│  - _tilesetImage: ui.Image?                                     │
│  - _tileData: List<List<int>>?                                  │
│  - _loadMap(): Future<void>                                     │
│  - _HexMapPainter (CustomPainter)                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ScreenMain                                │
│  (StatefulWidget – Hauptbildschirm)                             │
├─────────────────────────────────────────────────────────────────┤
│  - _tileWidth, _tileHeight: int                                 │
│  - _mapWidth, _mapHeight: int                                   │
│  - _mapTransformationController: TransformationController?      │
│  - _spawnPoints: List<(name, x, y)>                             │
│  - _onMapLoaded(), _onTransformationControllerCreated()         │
│  - _onSpawnPointsParsed()                                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        MainApp                                   │
│  (StatefulWidget – Root-Widget)                                 │
├─────────────────────────────────────────────────────────────────┤
│  + build(): MaterialApp mit Theme & ScreenMain                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        AppTheme                                  │
│  (Abstract – Theme-Konfiguration)                               │
├─────────────────────────────────────────────────────────────────┤
│  + lightTheme, darkTheme: ThemeData                             │
│  + baseTextTheme: TextTheme (Google Fonts)                      │
│  + themeModeNotifier: ValueNotifier<ThemeMode>                  │
└─────────────────────────────────────────────────────────────────┘
```

## Hilfsklassen

| Klasse              | Zweck                                              |
|---------------------|----------------------------------------------------|
| `CombatAction`      | Enum: `melee`, `ranged`                            |
| `CombatResult`      | Datenklasse für Kampfergebnisse (hit, damage, ...) |
| `EnneagramProfile`  | 12 Enneagramm-Persönlichkeitsprofile               |
| `HostPersonality`   | Fuzzy-Logik-basierte Persönlichkeitsbewertung      |
| `Aggressiveness`    | Fuzzy-Variable (0–100)                             |
| `RiskTolerance`     | Fuzzy-Variable (0–100)                             |
| `TacticalComplexity`| Fuzzy-Variable (0–100)                             |
| `_HexUtils`         | Hex-Gitter-Hilfsfunktionen (odd-r)                 |
| `_BfsVisitedSet`    | Optimiertes Set für BFS-Besuchsmarkierungen        |
| `_TokenRenderInfo`  | Kapselt Token + Metadaten für Darstellung          |
| `_TokenWidget`      | Widget zur Darstellung eines Tokens auf der Karte  |
| `_HexMapPainter`    | CustomPainter für das Zeichnen der Hex-Karte       |