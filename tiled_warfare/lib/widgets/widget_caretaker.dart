import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/boss_monsters/object_dough_dumpster.dart';
import 'package:tiled_warfare/objects/monsters/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_token.dart';
/// Das WidgetCaretaker-Widget ist für das Erstellen und Verwalten von Objekten
/// auf der Karte zuständig. Es enthält die Logik für das Platzieren von
/// Einheiten, das Aktualisieren ihrer Positionen und das Anzeigen von
/// Informationen über sie.
///
/// Es arbeitet mit [ObjectPlayer] (für die Spieler-Einheiten) und [ObjectHost]
/// (für die gegnerischen Einheiten) zusammen und zeichnet alle Tokens als
/// Overlay auf die Hex-Karte.
///
/// Die Tokens werden über einen [TransformationController] mit der Karte
/// synchronisiert, sodass sie beim Zoomen und Scrollen der Karte ebenfalls
/// skaliert und verschoben werden.
///
/// Tokens blockieren ihre Hex-Felder: Es kann sich immer nur ein Token auf
/// einem Feld befinden. Beim Ziehen eines Tokens wird beim Loslassen
/// automatisch das nächstgelegene freie Hex-Feld gesucht und der Token
/// rastet dort ein (Snap-to-Grid).
///
/// Tokens, die außerhalb des sichtbaren Viewports liegen, werden automatisch
/// ausgeblendet (Viewport-Culling), um Performance zu optimieren und
/// Darstellungsfehler zu vermeiden.
/// 
class WidgetCaretaker extends StatefulWidget {
  /// Die Pixel-Maße eines einzelnen Karten-Tiles (Breite).
  final int tileWidth;

  /// Die Pixel-Maße eines einzelnen Karten-Tiles (Höhe).
  final int tileHeight;

  /// Die Anzahl der Spalten der Karte.
  final int mapWidth;

  /// Die Anzahl der Zeilen der Karte.
  final int mapHeight;

  /// Der [TransformationController] des [InteractiveViewer] der Karte,
  /// um die Token-Positionen mit dem Zoom/Scroll der Karte zu synchronisieren.
  final TransformationController transformationController;

  /// Die geparsten Spawnpunkte aus der Map.
  /// Jeder Spawnpunkt hat einen Namen (z. B. "spawn_player1", "spawn_monster")
  /// und Pixel-Koordinaten (x, y) aus der TMX-Datei.
  final List<({String name, double x, double y})> spawnPoints;

  const WidgetCaretaker({
    super.key,
    required this.tileWidth,
    required this.tileHeight,
    required this.mapWidth,
    required this.mapHeight,
    required this.transformationController,
    this.spawnPoints = const [],
  });


  @override
  State<WidgetCaretaker> createState() => _WidgetCaretakerState();
}

/// Hex-Gitter-Hilfsfunktionen für odd-r (staggeraxis="y", staggerindex="odd").
///
/// Nachbar-Offsets für odd-r:
/// - Gerade y: Nachbarn bei (-1,-1), (0,-1), (-1,0), (1,0), (-1,1), (0,1)
/// - Ungerade y: Nachbarn bei (0,-1), (1,-1), (-1,0), (1,0), (0,1), (1,1)
class _HexUtils {
  const _HexUtils._();

  /// Erstellt eine eindeutige Kennung für ein Hex-Feld (x, y).
  static int hexKey(int x, int y, int mapWidth) => y * mapWidth + x;

  /// Konvertiert Offset-Koordinaten (odd-r) in Cube-Koordinaten.
  static ({int x, int y, int z}) offsetToCube(int x, int y) {
    final cubeX = x - (y & ~1) ~/ 2;
    final cubeZ = y;
    final cubeY = -cubeX - cubeZ;
    return (x: cubeX, y: cubeY, z: cubeZ);
  }

  /// Berechnet die Hex-Gitter-Entfernung zwischen zwei Hex-Koordinaten
  /// auf einem Pointy-Top-Hex-Gitter mit staggeraxis="y", staggerindex="odd".
  static int distance({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
  }) {
    final cube1 = offsetToCube(x1, y1);
    final cube2 = offsetToCube(x2, y2);
    final dx = (cube1.x - cube2.x).abs();
    final dy = (cube1.y - cube2.y).abs();
    final dz = (cube1.z - cube2.z).abs();
    return [dx, dy, dz].reduce((a, b) => a > b ? a : b);
  }

  /// Gibt die Nachbar-Offsets für odd-r Hex-Gitter zurück.
  static List<({int dx, int dy})> neighborOffsets(int y) {
    if (y % 2 == 0) {
      return [
        (dx: -1, dy: -1),
        (dx: 0, dy: -1),
        (dx: -1, dy: 0),
        (dx: 1, dy: 0),
        (dx: -1, dy: 1),
        (dx: 0, dy: 1),
      ];
    } else {
      return [
        (dx: 0, dy: -1),
        (dx: 1, dy: -1),
        (dx: -1, dy: 0),
        (dx: 1, dy: 0),
        (dx: 0, dy: 1),
        (dx: 1, dy: 1),
      ];
    }
  }
}

class _WidgetCaretakerState extends State<WidgetCaretaker> {
  /// Der Spieler (Singleton).
  final ObjectPlayer _player = ObjectPlayer();

  /// Der Host (Gegner-Steuerung).
  final ObjectHost _host = ObjectHost();

  /// Der aktuell ausgewählte Token (für Info-Anzeige und Aktionen).
  ObjectToken? _selectedToken;

  /// Die aktuell vorgemerkte Kampfaktion (Targeting-Modus).
  /// Solange nicht null, wartet das Spiel auf einen Klick auf ein Ziel.
  CombatAction? _pendingAction;

  /// Alle feindlichen Tokens, die für die ausstehende Aktion als Ziel
  /// in Frage kommen (im Targeting-Modus hervorgehoben).
  Set<ObjectToken> _targetableEnemies = {};

  /// Gibt an, ob gerade ein Drag-Vorgang läuft.
  bool _isDragging = false;

  /// Die Offset-Verschiebung während eines Drags.
  Offset _dragOffset = Offset.zero;

  /// Der Token, der gerade gezogen wird.
  ObjectToken? _draggedToken;

  /// Die Hex-Position (x, y), an der der Drag-Vorgang begonnen hat.
  /// Wird verwendet, um die Bewegung auf [ObjectToken.movementValue] zu begrenzen.
  ({int x, int y})? _dragStartHex;

  /// Cache-Dirty-Flags: Werden auf true gesetzt, wenn sich der Zustand ändert,
  /// und nach der Neuberechnung zurückgesetzt. So vermeiden wir wiederholte
  /// teure Berechnungen innerhalb eines Build-Durchlaufs.
  bool _cacheDirty = true;
  List<_TokenRenderInfo>? _cachedAllTokens;
  Set<int>? _cachedOccupiedFields;
  Set<int>? _cachedReachableFields;
  ObjectToken? _cachedReachableToken;
  int? _cachedReachableMovement;
  Rect? _cachedVisibleRect;

  // ──────────────────────────────────────────────
  // Runden- und Initiativsystem
  // ──────────────────────────────────────────────

  /// Die aktuelle Runde (beginnt bei 1).
  int _currentRound = 0;

  /// Ob der Spieler am Zug ist.
  bool _isPlayerTurn = true;

  /// Ob der Host am Zug ist.
  bool _isHostTurn = false;

  /// Ob das Spiel beendet ist (eine Seite hat verloren).
  bool _isGameOver = false;

  /// Nachricht über den Initiativwurf (für UI-Anzeige).
  String? _initiativeMessage;

  /// Nachricht über den aktuellen Spielstatus (für UI-Anzeige).
  String? _statusMessage;

  /// Der nächste Snackbar-Schlüssel, um das Stapeln von Snackbars zu vermeiden.
  int _snackBarKey = 0;

  @override
  void initState() {
    super.initState();
    _initializeGameObjects();
    // Auf Änderungen der Transformation (Zoom/Scroll) lauschen,
    // um die Token-Positionen zu aktualisieren
    widget.transformationController.addListener(_onTransformationChanged);

    // Nach der Initialisierung die erste Runde starten
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNewRound();
    });
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_onTransformationChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WidgetCaretaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Falls die Spawnpunkte nachgeladen wurden (oder sich geändert haben),
    // die Spielobjekte neu initialisieren
    if (widget.spawnPoints != oldWidget.spawnPoints && widget.spawnPoints.isNotEmpty) {
      _initializeGameObjects();
      setState(() {});
    }
  }

  /// Wird bei jeder Änderung der Karten-Transformation aufgerufen.
  void _onTransformationChanged() {
    // Viewport-Cache ungültig machen, da sich die Transformation geändert hat
    _cachedVisibleRect = null;
    setState(() {});
  }

  /// Markiert alle gecachten Werte als ungültig, sodass sie beim nächsten
  /// Zugriff neu berechnet werden.
  void _invalidateCache() {
    _cacheDirty = true;
    _cachedAllTokens = null;
    _cachedOccupiedFields = null;
    _cachedReachableFields = null;
    _cachedReachableToken = null;
    _cachedReachableMovement = null;
    // _cachedVisibleRect wird separat invalidiert (via _onTransformationChanged)
  }

  /// Rechnet einen Bildschirm-Punkt (z. B. Tap-Position) in die
  /// Karten-Koordinaten um, indem die inverse Transformation des
  /// [InteractiveViewer] angewendet wird.
  Offset _screenToMap(Offset screenPoint) {
    final matrix = widget.transformationController.value;
    // Verwende MatrixUtils für die inverse Transformation
    final inverseMatrix = Matrix4.tryInvert(matrix);
    if (inverseMatrix == null) return screenPoint;
    final transformed = MatrixUtils.transformPoint(inverseMatrix, screenPoint);
    return transformed;
  }

  /// Initialisiert die Spielobjekte: platziert Start-Einheiten auf der Karte.
  ///
  /// Nutzt die vom Spieler via [ScreenRestaurant] ausgewählten Einheiten aus
  /// [ObjectPlayer.unitList] und positioniert sie auf den Spawnpunkten der Map.
  /// Falls [ObjectPlayer.unitList] noch leer ist (z. B. beim ersten Start ohne
  /// Restaurant-Verwaltung), werden 3 Standard-Line-Cooks erzeugt.
  /// Falls keine Spawnpunkte in der Map definiert sind, werden Fallback-
  /// Positionen verwendet.
  void _initializeGameObjects() {
    // Mit hochauflösendem Zeitstempel seeden, damit jeder Spielstart
    // eine andere Zufallsauswahl ergibt (auch bei schnellen Neustarts)
    final random = Random(DateTime.now().microsecondsSinceEpoch);
    // Vorherige Host-Objekte entfernen, falls diese Methode erneut aufgerufen wird
    _host.doughDumpsterList.clear();
    _baseMovementValues.clear();

    // ── Spieler-Einheiten initialisieren ──────────────────────────────
    // Die unitList wurde bereits von ScreenRestaurant via selectTeamForBattle()
    // befüllt. Falls sie noch leer ist (z. B. Direktstart ohne Restaurant),
    // legen wir 3 Standard-Line-Cooks an.
    if (_player.unitList.isEmpty) {
      for (int i = 0; i < 3; i++) {
        _player.spawnLineCook();
      }
    }

    // Spieler-Spawnpunkte (mit "spawn_player" im Namen) finden
    final playerSpawns = widget.spawnPoints
        .where((sp) => sp.name.startsWith('spawn_player'))
        .toList();

    Offset playerSpawnPosition;
    if (playerSpawns.isNotEmpty) {
      final chosenSpawn = playerSpawns[random.nextInt(playerSpawns.length)];
      playerSpawnPosition = Offset(chosenSpawn.x, chosenSpawn.y);
    } else {
      // Fallback: linke Seite der Karte
      playerSpawnPosition = _hexToPixel(x: 2, y: 5);
    }

    // Vorhandene Spieler-Einheiten um den gewählten Spawnpunkt positionieren
    final playerUnits = _player.unitList;
    for (int i = 0; i < playerUnits.length; i++) {
      final unit = playerUnits[i];
      // Für Apprentice und Line Cook gleichermaßen positionieren
      // Leichter Versatz, damit die Tokens nicht exakt übereinander liegen
      unit.position = Offset(
        playerSpawnPosition.dx + (i - (playerUnits.length - 1) / 2) * widget.tileWidth * 0.5,
        playerSpawnPosition.dy + (i - (playerUnits.length - 1) / 2) * widget.tileHeight * 0.5,
      );
    }

    // Monster-Spawnpunkte (mit "spawn_monster" im Namen) finden
    final monsterSpawns = widget.spawnPoints
        .where((sp) => sp.name.startsWith('spawn_monster'))
        .toList();

    // Gegnerische Dough Dumpster am Monster-Spawnpunkt platzieren
    final dumpster = ObjectDoughDumpster();
    if (monsterSpawns.isNotEmpty) {
      dumpster.position = Offset(monsterSpawns[0].x, monsterSpawns[0].y);
    } else {
      dumpster.position = _hexToPixel(x: 25, y: 5);
    }
    _host.doughDumpsterList.add(dumpster);

    // Start-Zombies vom Dumpster spawnen lassen – verteilt um den Dumpster herum
    // auf freien Hex-Feldern, um Stapelung zu vermeiden
    final zombies = dumpster.spawnZombies();
    final dumpsterHex = _pixelToHex(dumpster.position);
    // Alle belegten Felder ermitteln (Dumpster selbst + bereits platzierte Zombies)
    final occupied = <int>{};
    occupied.add(dumpsterHex.y * widget.mapWidth + dumpsterHex.x);
    for (int i = 0; i < zombies.length; i++) {
      // Spiralförmig nach einem freien Feld in der Nähe des Dumpsters suchen
      final freePos = _findFreeHexNearCaretaker(
        startX: dumpsterHex.x,
        startY: dumpsterHex.y,
        occupied: occupied,
        mapWidth: widget.mapWidth,
        mapHeight: widget.mapHeight,
      );
      zombies[i].position = freePos;
      // Neu platzierten Zombie als belegt markieren
      final zh = _pixelToHex(freePos);
      occupied.add(zh.y * widget.mapWidth + zh.x);
    }

    _invalidateCache();
  }

  /// Setzt die Bewegungspunkte aller Einheiten auf ihre Basiswerte zurück.
  /// Verwaltet die Initialwerte über eine Map, da ObjectToken.movementValue
  /// mutable ist und während des Spiels verbraucht wird.
  final Map<ObjectToken, int> _baseMovementValues = {};

  /// Speichert den Basis-Bewegungswert eines Tokens (wird bei der ersten
  /// Runde von [_startNewRound] automatisch ermittelt).
  void _storeBaseMovementValue(ObjectToken token) {
    if (!_baseMovementValues.containsKey(token)) {
      _baseMovementValues[token] = token.movementValue;
    }
  }

  /// Setzt den Bewegungswert und das hasActed-Flag eines Tokens zurück.
  void _resetTokenRoundState(ObjectToken token) {
    _storeBaseMovementValue(token);
    token.movementValue = _baseMovementValues[token]!;
    token.hasActed = false;
  }

  /// Kombinierte Methode zum Zurücksetzen von Bewegungspunkten und
  /// hasActed-Flag aller Einheiten für eine neue Runde.
  void _resetRoundState() {
    // Spieler-Einheiten
    for (final cook in _player.unitList) {
      _resetTokenRoundState(cook);
    }
    // Gegnerische Dough Dumpster und deren Zombies
    for (final dumpster in _host.doughDumpsterList) {
      _resetTokenRoundState(dumpster);
      for (final zombie in dumpster.zombieList) {
        _resetTokenRoundState(zombie);
      }
    }
  }

  // ──────────────────────────────────────────────
  // Runden- und Initiativsystem
  // ──────────────────────────────────────────────

  /// Startet eine neue Runde mit Initiativwurf.
  ///
  /// Gemäß Abschnitt 7 der Kampfregeln wird zu Beginn jeder Runde für jede
  /// Seite ein Initiative-Wurf mit einem W100 durchgeführt. Die Seite mit
  /// dem höheren Ergebnis beginnt die Runde.
  void _startNewRound() {
    if (_isGameOver) return;

    _currentRound++;

    // Bewegungspunkte und hasActed-Flag aller Einheiten zurücksetzen
    _resetRoundState();

    // Initiativwürfe für beide Seiten
    final playerInitiative = _player.rollInitiative();
    final hostInitiative = _host.rollInitiative();

    String message;
    if (playerInitiative > hostInitiative) {
      _isPlayerTurn = true;
      _isHostTurn = false;
      message = 'Runde $_currentRound: Spieler hat Initiative ($playerInitiative vs. $hostInitiative)';
    } else if (hostInitiative > playerInitiative) {
      _isPlayerTurn = false;
      _isHostTurn = true;
      message = 'Runde $_currentRound: Host hat Initiative ($hostInitiative vs. $playerInitiative)';
    } else {
      // Gleichstand: Münzwurf (W100 > 51 → gleiche Reihenfolge wie letzte Runde)
      // In der ersten Runde beginnt der Spieler bei Gleichstand
      if (_currentRound == 1) {
        _isPlayerTurn = true;
        _isHostTurn = false;
        message = 'Runde $_currentRound: Gleichstand – Spieler beginnt (erste Runde)';
      } else {
        // Beide gleich – behalte die aktuelle Reihenfolge bei
        message = 'Runde $_currentRound: Gleichstand – gleiche Reihenfolge wie zuvor';
      }
    }

    _initiativeMessage = message;
    _statusMessage = _isPlayerTurn ? 'Spieler ist am Zug' : 'Host ist am Zug';

    _invalidateCache();

    // Wenn der Host die Initiative hat, führt er sofort seinen Zug aus
    if (_isHostTurn) {
      _executeHostTurn();
    }

    setState(() {});
  }

  /// Beendet den Zug des Spielers und übergibt an den Host.
  void _endPlayerTurn() {
    if (_isGameOver) return;

    _isPlayerTurn = false;
    _isHostTurn = true;
    _statusMessage = 'Host ist am Zug';

    // Auswahl zurücksetzen
    _selectedToken = null;

    setState(() {});

    // Host-Zug mit kurzer Verzögerung ausführen, damit der Spieler
    // die Statusänderung sehen kann
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _executeHostTurn();
      }
    });
  }

  /// Prüft Spielende-Bedingungen (eine Seite besiegt).
  /// Gibt true zurück, wenn das Spiel beendet ist.
  bool _checkGameOver() {
    if (_host.isDefeated) {
      _isGameOver = true;
      _statusMessage = 'Spieler hat gewonnen! Alle Gegner besiegt.';
      return true;
    }
    if (_player.unitList.isEmpty) {
      _isGameOver = true;
      _statusMessage = 'Host hat gewonnen! Alle Spieler-Einheiten besiegt.';
      return true;
    }
    return false;
  }

  /// Führt den Zug des Hosts aus.
  ///
  /// Der Host bewegt alle Zombies auf die Line Cooks zu und führt
  /// Angriffe aus, wenn Zombies in Reichweite sind.
  void _executeHostTurn() {
    if (_isGameOver) return;
    if (_checkGameOver()) {
      setState(() {});
      return;
    }

    // 0. Dough Dumpster spawnen neue Zombies (alle 2 Runden)
    _executeHostSpawning();

    // 1. Zombies bewegen
    _executeHostMovement();

    // 2. Zombies angreifen lassen
    _executeHostAttacks();

    // 3. Tote Einheiten entfernen
    _removeDeadTokens();

    // 4. Prüfen, ob der Spieler noch Einheiten hat
    if (_checkGameOver()) {
      setState(() {});
      return;
    }

    // 5. Host-Zug beenden, neue Runde starten
    _isHostTurn = false;
    _isPlayerTurn = true;
    _statusMessage = 'Spieler ist am Zug';

    // Nächste Runde starten
    _startNewRound();
  }

  /// Führt das Spawning neuer Zombies durch den Host aus.
  /// Spawning findet nur in geraden Runden statt (alle 2 Runden),
  /// damit die Spieler-Zombie-Population nicht explodiert.
  void _executeHostSpawning() {
    // Nur in geraden Runden spawnen (alle 2 Runden)
    if (_currentRound % 2 != 0) return;
    
    final spawnLogs = _host.performAllDumpsterSpawning();
    for (final log in spawnLogs) {
      _showMessage(log);
    }
  }

  /// Führt die Bewegung aller Host-Zombies aus.
  void _executeHostMovement() {
    _host.moveAllZombiesTowardsTargets(_player.unitList);
  }

  /// Führt die Angriffe aller Host-Zombies aus.
  void _executeHostAttacks() {
    final combatLogs = _host.performAllZombieAttacks(_player);
    for (final log in combatLogs) {
      _showMessage(log);
    }
  }

  /// Rechnet Hex-Gitter-Koordinaten (x, y) in Pixel-Koordinaten um.
  ///
  /// Verwendet die gleiche Logik wie [_HexMapPainter] in [WidgetMapLoader]:
  /// - staggeraxis="y", staggerindex="odd"
  /// - Ungerade Zeilen sind um tileWidth/2 nach rechts versetzt.
  Offset _hexToPixel({required int x, required int y}) {
    final double pixelX;

    if (y % 2 == 1) {
      pixelX = (x * widget.tileWidth).toDouble() + widget.tileWidth / 2;
    } else {
      pixelX = (x * widget.tileWidth).toDouble();
    }
    final pixelY = y * (widget.tileHeight * 3.0 / 4.0);

    return Offset(pixelX, pixelY);
  }

  /// Rechnet Pixel-Koordinaten in die nächstgelegenen Hex-Gitter-Koordinaten
  /// (x, y) um. Dies ist die Umkehrung von [_hexToPixel].
  ///
  /// Verwendet die gleiche Logik wie [_HexMapPainter] in [WidgetMapLoader]:
  /// - staggeraxis="y", staggerindex="odd"
  /// - Ungerade Zeilen sind um tileWidth/2 nach rechts versetzt.
  ({int x, int y}) _pixelToHex(Offset pixel) {
    // Zunächst die ungefähre y-Zeile bestimmen
    final approxY = (pixel.dy / (widget.tileHeight * 3.0 / 4.0)).round();

    // y auf gültigen Bereich begrenzen
    final y = approxY.clamp(0, widget.mapHeight - 1);

    // x basierend auf y (gerade/ungerade Zeile) berechnen
    int x;
    if (y % 2 == 1) {
      x = ((pixel.dx - widget.tileWidth / 2) / widget.tileWidth).round();
    } else {
      x = (pixel.dx / widget.tileWidth).round();
    }

    // x auf gültigen Bereich begrenzen
    x = x.clamp(0, widget.mapWidth - 1);

    return (x: x, y: y);
  }

  /// Findet ein freies Hex-Feld in der Nähe eines Ausgangs-Hex.
  /// Durchsucht spiralförmig beginnend beim Start-Hex, bis ein freies Feld
  /// gefunden wird oder der maximale Radius erreicht ist.
  /// Gibt das erste freie Hex als Pixel-Position zurück.
  /// Verwendet mapWidth und mapHeight für Kartenbegrenzung und
  /// hexKey = y * mapWidth + x für die occupied-Prüfung.
  Offset _findFreeHexNearCaretaker({
    required int startX,
    required int startY,
    required Set<int> occupied,
    int maxRadius = 12,
    required int mapWidth,
    required int mapHeight,
  }) {
    // Prüfe, ob das Start-Hex selbst frei ist
    if (!occupied.contains(startY * mapWidth + startX)) {
      return _hexToPixel(x: startX, y: startY);
    }

    // Spiralförmige Suche
    for (int radius = 1; radius <= maxRadius; radius++) {
      // Obere Kante
      for (int dx = -radius; dx <= radius; dx++) {
        final x = startX + dx;
        final y = startY - radius;
        if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight &&
            !occupied.contains(y * mapWidth + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
      // Untere Kante
      for (int dx = -radius; dx <= radius; dx++) {
        final x = startX + dx;
        final y = startY + radius;
        if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight &&
            !occupied.contains(y * mapWidth + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
      // Linke Kante (ohne Ecken)
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        final x = startX - radius;
        final y = startY + dy;
        if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight &&
            !occupied.contains(y * mapWidth + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
      // Rechte Kante (ohne Ecken)
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        final x = startX + radius;
        final y = startY + dy;
        if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight &&
            !occupied.contains(y * mapWidth + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
    }

    // Fallback: Start-Position zurückgeben
    return _hexToPixel(x: startX, y: startY);
  }

  /// Gibt die Hex-Gitter-Koordinaten (x, y) für einen Token zurück,
  /// basierend auf seiner aktuellen Pixel-Position.
  ({int x, int y}) _getTokenHex(ObjectToken token) {
    return _pixelToHex(token.position);
  }

  /// Baut eine Menge aller aktuell belegten Hex-Felder auf.
  /// Ein Feld gilt als belegt, wenn dort ein lebender Token steht.
  /// Der [excludeToken] wird dabei nicht berücksichtigt (z. B. der
  /// gerade gezogene Token).
  ///
  /// Das Ergebnis wird gecached, da diese Methode mehrfach pro Frame
  /// aufgerufen werden kann.
  Set<int> _getOccupiedHexFields({ObjectToken? excludeToken}) {
    if (excludeToken != null || _cacheDirty || _cachedOccupiedFields == null) {
      // Wenn ein excludeToken angegeben ist, können wir nicht cachen
      return _buildOccupiedHexFields(excludeToken: excludeToken);
    }
    return _cachedOccupiedFields!;
  }

  Set<int> _buildOccupiedHexFields({ObjectToken? excludeToken}) {
    final occupied = <int>{};

    for (final renderInfo in _allTokens) {
      final token = renderInfo.token;
      if (token.woundValue <= 0) continue;
      if (token == excludeToken) continue;

      final hex = _getTokenHex(token);
      occupied.add(_HexUtils.hexKey(hex.x, hex.y, widget.mapWidth));
    }

    return occupied;
  }

  /// Prüft, ob ein bestimmtes Hex-Feld (x, y) frei ist (kein lebender Token
  /// darauf steht). Der [excludeToken] wird ignoriert.
  bool _isHexFieldFree(int x, int y, {ObjectToken? excludeToken}) {
    final occupied = _getOccupiedHexFields(excludeToken: excludeToken);
    return !occupied.contains(_HexUtils.hexKey(x, y, widget.mapWidth));
  }

  /// Prüft, ob ein Ziel-Hex-Feld vom Start-Hex-Feld aus über einen freien
  /// Pfad erreichbar ist (BFS, blockiert durch belegte Felder).
  /// Dies stellt sicher, dass Tokens belegte Felder wie unüberwindbare
  /// Hindernisse umgehen müssen, anstatt einfach auf ein freies Feld zu
  /// springen, das durch blockierte Felder abgeschnitten ist.
  bool _isHexFieldReachable({
    required int startX,
    required int startY,
    required int targetX,
    required int targetY,
    int maxSteps = 20,
    ObjectToken? excludeToken,
  }) {
    if (startX == targetX && startY == targetY) return true;

    final occupied = _buildOccupiedHexFields(excludeToken: excludeToken);
    visited.reset();
    final queue = Queue<({int x, int y, int steps})>();
    queue.add((x: startX, y: startY, steps: maxSteps));
    visited.add(_HexUtils.hexKey(startX, startY, widget.mapWidth));
    final targetKey = _HexUtils.hexKey(targetX, targetY, widget.mapWidth);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.steps <= 0) continue;

      for (final offset in _HexUtils.neighborOffsets(current.y)) {
        final nx = current.x + offset.dx;
        final ny = current.y + offset.dy;
        if (nx < 0 || nx >= widget.mapWidth || ny < 0 || ny >= widget.mapHeight) continue;
        final key = _HexUtils.hexKey(nx, ny, widget.mapWidth);
        if (visited.contains(key)) continue;
        visited.add(key);
        if (key == targetKey) return true;
        if (occupied.contains(key)) continue;
        queue.add((x: nx, y: ny, steps: current.steps - 1));
      }
    }

    return false;
  }

  /// Ein schnelles Set für BFS-Besuchsmarkierungen, das Wiederverwendung
  /// ermöglicht, ohne jedes Mal ein neues Set zu allozieren.
  final _BfsVisitedSet visited = _BfsVisitedSet();

  /// Findet das nächstgelegene freie und erreichbare Hex-Feld zu einer
  /// Pixel-Position. Durchsucht die Umgebung spiralförmig, beginnend beim
  /// nächstgelegenen Hex-Feld, und gibt die Pixel-Position des ersten freien
  /// und erreichbaren Feldes zurück.
  ///
  /// Ein Feld ist nur erreichbar, wenn ein freier Pfad vom Start-Hex-Feld
  /// des [excludeToken] dorthin existiert (belegte Felder werden als
  /// unüberwindbare Hindernisse behandelt, die umgangen werden müssen).
  ///
  /// Falls kein geeignetes Feld gefunden wird, wird die ursprüngliche
  /// Pixel-Position zurückgegeben.
  Offset _snapToNearestFreeHex(Offset pixel, {ObjectToken? excludeToken}) {
    final approxHex = _pixelToHex(pixel);

    // Hex-Position des Tokens vor der Bewegung
    final ({int x, int y})? startHex =
        excludeToken != null ? _getTokenHex(excludeToken) : null;

    // Prüfen, ob das angenäherte Feld bereits frei und erreichbar ist
    if (_isHexFieldFree(approxHex.x, approxHex.y, excludeToken: excludeToken)) {
      if (startHex == null ||
          _isHexFieldReachable(
            startX: startHex.x,
            startY: startHex.y,
            targetX: approxHex.x,
            targetY: approxHex.y,
            excludeToken: excludeToken,
          )) {
        return _hexToPixel(x: approxHex.x, y: approxHex.y);
      }
    }

    // Spiralförmige Suche im Umkreis von bis zu 10 Feldern
    const maxRadius = 10;
    for (int radius = 1; radius <= maxRadius; radius++) {
      // Obere und untere Kante
      for (int dx = -radius; dx <= radius; dx++) {
        // Obere Kante: y = approxHex.y - radius
        final result = _checkSpiralEdge(
          approxHex.x + dx,
          approxHex.y - radius,
          startHex: startHex,
          excludeToken: excludeToken,
        );
        if (result != null) return result;

        // Untere Kante: y = approxHex.y + radius
        final resultBottom = _checkSpiralEdge(
          approxHex.x + dx,
          approxHex.y + radius,
          startHex: startHex,
          excludeToken: excludeToken,
        );
        if (resultBottom != null) return resultBottom;
      }

      // Linke und rechte Kante (ohne Ecken, die schon oben/unten abgedeckt sind)
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        // Linke Kante: x = approxHex.x - radius
        final resultLeft = _checkSpiralEdge(
          approxHex.x - radius,
          approxHex.y + dy,
          startHex: startHex,
          excludeToken: excludeToken,
        );
        if (resultLeft != null) return resultLeft;

        // Rechte Kante: x = approxHex.x + radius
        final resultRight = _checkSpiralEdge(
          approxHex.x + radius,
          approxHex.y + dy,
          startHex: startHex,
          excludeToken: excludeToken,
        );
        if (resultRight != null) return resultRight;
      }
    }

    // Kein freies Feld gefunden – ursprüngliche Pixel-Position zurückgeben
    return _hexToPixel(x: approxHex.x, y: approxHex.y);
  }

  /// Prüft ein einzelnes Hex-Feld auf Freiheit und Erreichbarkeit.
  /// Gibt die Pixel-Position zurück, wenn das Feld geeignet ist, sonst null.
  Offset? _checkSpiralEdge(
    int x,
    int y, {
    ({int x, int y})? startHex,
    ObjectToken? excludeToken,
  }) {
    if (x < 0 || x >= widget.mapWidth || y < 0 || y >= widget.mapHeight) return null;
    if (!_isHexFieldFree(x, y, excludeToken: excludeToken)) return null;
    if (startHex != null &&
        !_isHexFieldReachable(
          startX: startHex.x,
          startY: startHex.y,
          targetX: x,
          targetY: y,
          excludeToken: excludeToken,
        )) {
      return null;
    }
    return _hexToPixel(x: x, y: y);
  }

  /// Gibt alle Tokens zurück, die auf der Karte angezeigt werden sollen.
  /// Das Ergebnis wird gecached, um wiederholte Iterationen zu vermeiden.
  List<_TokenRenderInfo> get _allTokens {
    if (_cacheDirty || _cachedAllTokens == null) {
      _cachedAllTokens = _buildAllTokens();
      _cacheDirty = false;
    }
    return _cachedAllTokens!;
  }

  List<_TokenRenderInfo> _buildAllTokens() {
    final tokens = <_TokenRenderInfo>[];

    // Spieler-Einheiten (nur lebende)
    for (final cook in _player.unitList) {
      if (cook.woundValue <= 0) continue;
      tokens.add(_TokenRenderInfo(
        token: cook,
        isPlayerUnit: true,
      ));
    }

    // Gegnerische Dough Dumpster (nur lebende)
    for (final dumpster in _host.doughDumpsterList) {
      if (dumpster.woundValue <= 0) continue;
      tokens.add(_TokenRenderInfo(
        token: dumpster,
        isPlayerUnit: false,
      ));
    }

    // Zombies aus allen Dumpstern (nur lebende)
    for (final dumpster in _host.doughDumpsterList) {
      for (final zombie in dumpster.zombieList) {
        if (zombie.woundValue <= 0) continue;
        tokens.add(_TokenRenderInfo(
          token: zombie,
          isPlayerUnit: false,
        ));
      }
    }

    return tokens;
  }

  /// Behandelt einen Tap auf die Karte.
  /// - Im Targeting-Modus wird ein angeklickter targetierbarer Gegner angegriffen.
  /// - Im Normalmodus wird ein Token ausgewählt oder die Auswahl aufgehoben.
  void _handleTap(Offset tapPosition) {
    // Nur im Spieler-Zug
    if (!_isPlayerTurn || _isGameOver) return;

    setState(() {
      // Prüfen, ob ein Token angetippt wurde
      final tappedToken = _findTokenAtPosition(tapPosition);

      if (_pendingAction != null && tappedToken != null) {
        _handleTapInTargetingMode(tappedToken);
      } else if (tappedToken != null) {
        // Normalmodus: Token auswählen
        _selectedToken = tappedToken;
      } else {
        // Nichts getroffen – Deselektieren
        _selectedToken = null;
        _pendingAction = null;
        _targetableEnemies = {};
      }
    });
  }

  /// Findet den Token an einer gegebenen Karten-Position (oder null).
  ObjectToken? _findTokenAtPosition(Offset mapPosition) {
    for (final renderInfo in _allTokens) {
      final token = renderInfo.token;
      // Host-Tokens (Gegner) haben eine etwas größere Hitbox,
      // um dem Spieler das Zielen zu erleichtern
      final double hitboxSize = renderInfo.isPlayerUnit
          ? widget.tileWidth.toDouble()
          : widget.tileWidth.toDouble() * 1.3;
      final tokenRect = Rect.fromCenter(
        center: token.position,
        width: hitboxSize,
        height: hitboxSize,
      );
      if (tokenRect.contains(mapPosition)) {
        return token;
      }
    }
    return null;
  }

  /// Behandelt einen Tap im Targeting-Modus.
  void _handleTapInTargetingMode(ObjectToken tappedToken) {
    if (_targetableEnemies.contains(tappedToken)) {
      // Gültiges Ziel getroffen – Aktion ausführen
      final action = _pendingAction!;
      _pendingAction = null;
      _targetableEnemies = {};
      _executeActionOnTarget(action, tappedToken);
    } else if (tappedToken == _selectedToken) {
      // Klick auf den eigenen Angreifer bricht ab
      _pendingAction = null;
      _targetableEnemies = {};
    } else {
      // Unerwarteter Token – abbrechen
      _pendingAction = null;
      _targetableEnemies = {};
    }
  }

  /// Startet einen Drag-Vorgang für den Token unter der Startposition.
  void _handleDragStart(Offset startPosition) {
    // Nur im Spieler-Zug darf gezogen werden
    if (!_isPlayerTurn || _isGameOver) return;

    for (final renderInfo in _allTokens) {
      final token = renderInfo.token;
      // Nur Spieler-Einheiten können gezogen werden
      if (!renderInfo.isPlayerUnit) continue;

      final tokenRect = Rect.fromCenter(
        center: token.position,
        width: widget.tileWidth.toDouble(),
        height: widget.tileHeight.toDouble(),
      );
      if (tokenRect.contains(startPosition)) {
        setState(() {
          _isDragging = true;
          _draggedToken = token;
          _selectedToken = token;
          _dragOffset = Offset.zero;
          _dragStartHex = _getTokenHex(token);
        });
        return;
      }
    }
  }

  /// Aktualisiert die Position des gezogenen Tokens während des Drags.
  void _handleDragUpdate(Offset delta) {
    if (!_isDragging || _draggedToken == null) return;
    setState(() {
      _dragOffset += delta;
    });
  }

  /// Beendet den Drag-Vorgang und setzt die endgültige Position.
  /// Der Token wird automatisch auf das nächstgelegene freie Hex-Feld
  /// gesetzt (Snap-to-Grid). Ist das Zielfeld belegt, wird spiralförmig
  /// nach einem freien Feld gesucht.
  ///
  /// Die Bewegung wird auf [ObjectToken.movementValue] begrenzt. Überschreitet
  /// die Entfernung den Bewegungswert, wird der Token an seine ursprüngliche
  /// Position zurückgesetzt.
  void _handleDragEnd() {
    if (!_isDragging || _draggedToken == null) return;
    setState(() {
      // Neue Pixel-Position nach dem Drag
      final newPosition = _draggedToken!.position + _dragOffset;

      // Auf das nächstgelegene freie Hex-Feld einrasten
      final snappedPosition = _snapToNearestFreeHex(
        newPosition,
        excludeToken: _draggedToken,
      );

      // Ziel-Hex-Koordinaten ermitteln
      final targetHex = _pixelToHex(snappedPosition);

      // Bewegung auf movementValue begrenzen
      if (_dragStartHex != null) {
        final distance = _HexUtils.distance(
          x1: _dragStartHex!.x,
          y1: _dragStartHex!.y,
          x2: targetHex.x,
          y2: targetHex.y,
        );

        if (distance > _draggedToken!.movementValue) {
          // Bewegung überschreitet den verbleibenden Bewegungswert – zurücksetzen
          _showMessage(
            'Bewegung zu weit! Nur noch ${_draggedToken!.movementValue} Bewegungspunkte übrig.',
          );
          _isDragging = false;
          _draggedToken = null;
          _dragOffset = Offset.zero;
          _dragStartHex = null;
          return;
        }

        // Verbrauchte Bewegungspunkte abziehen
        _draggedToken!.movementValue -= distance;
      }

      _draggedToken!.position = snappedPosition;
      _isDragging = false;
      _draggedToken = null;
      _dragOffset = Offset.zero;
      _dragStartHex = null;

      _invalidateCache();

      // Nach Bewegung prüfen, ob alle Tokens fertig sind
      _checkAutoEndPlayerTurn();
    });
  }

  /// Versetzt das Spiel in den Targeting-Modus für die angegebene Aktion.
  /// Zeigt alle erreichbaren Gegner als rote Highlights an.
  /// Erst ein Klick auf einen Gegner führt die Aktion aus.
  void _enterTargetingMode(CombatAction action) {
    if (_selectedToken == null) return;
    if (_selectedToken is! ObjectLineCook) return;
    if (!_isPlayerTurn || _isGameOver) return;

    final attacker = _selectedToken as ObjectLineCook;

    // Prüfen, ob der Token in dieser Runde bereits gehandelt hat
    if (attacker.hasActed) {
      _showMessage('${attacker.name} hat bereits in dieser Runde angegriffen!');
      return;
    }

    // Alle in Reichweite liegenden Gegner finden
    final targets = <ObjectToken>{};
    final attackerHex = _getTokenHex(attacker);
    for (final renderInfo in _allTokens) {
      if (renderInfo.isPlayerUnit) continue;
      final enemy = renderInfo.token;
      if (enemy.woundValue <= 0) continue;

      final distance = _HexUtils.distance(
        x1: attackerHex.x,
        y1: attackerHex.y,
        x2: _getTokenHex(enemy).x,
        y2: _getTokenHex(enemy).y,
      );

      if (action == CombatAction.melee && distance <= 1) {
        targets.add(enemy);
      } else if (action == CombatAction.ranged && distance <= attacker.rangeValue) {
        targets.add(enemy);
      }
    }

    if (targets.isEmpty) {
      _showMessage('Keine Ziele in Reichweite!');
      return;
    }

    setState(() {
      _pendingAction = action;
      _targetableEnemies = targets;
    });
  }

  /// Führt die ausstehende Kampfaktion gegen das per Tap gewählte Ziel aus.
  void _executeActionOnTarget(CombatAction action, ObjectToken target) {
    if (_selectedToken == null || _selectedToken is! ObjectLineCook) return;
    final attacker = _selectedToken as ObjectLineCook;

    // Entfernung in Hex-Feldern ermitteln
    final distanceInHex = _HexUtils.distance(
      x1: _getTokenHex(attacker).x,
      y1: _getTokenHex(attacker).y,
      x2: _getTokenHex(target).x,
      y2: _getTokenHex(target).y,
    );
    if (distanceInHex < 1) return;

    // Kampfaktion ausführen
    final result = _player.performAction(
      action: action,
      attacker: attacker,
      defender: target,
      distance: distanceInHex,
    );

    // Token hat in dieser Runde seine eine Kampfaktion verbraucht
    attacker.hasActed = true;

    // Ergebnis anzeigen
    final message = _buildCombatResultMessage(target, result);
    _showMessage(message);

    // Tote Einheiten entfernen
    _removeDeadTokens();

    // Prüfen, ob der Host besiegt wurde
    if (_host.isDefeated) {
      _isGameOver = true;
      _statusMessage = 'Spieler hat gewonnen! Alle Gegner besiegt.';
      setState(() {});
      return;
    }

    // Prüfen, ob alle Spieler-Tokens ihre Aktionen und Bewegung verbraucht haben
    _checkAutoEndPlayerTurn();
  }

  /// Baut eine lesbare Kampf-Nachricht aus dem Kampfergebnis.
  String _buildCombatResultMessage(ObjectToken target, CombatResult result) {
    String message = 'Angriff auf ${target.name}: ';
    if (result.hit) {
      message += 'Treffer! ${result.damage} Schaden verursacht.';
    } else {
      message += 'Verfehlt!';
    }
    if (result.attackerCritical) message += ' (Kritischer Treffer!)';
    if (result.attackerFumbled) message += ' (Patzer – selbst Schaden erlitten!)';
    if (result.defenderCritical) message += ' (Gegner hat kritisch pariert!)';
    if (result.defenderFumbled) message += ' (Gegner hat einen Patzer erlitten!)';
    return message;
  }

  /// Entfernt alle Tokens mit woundValue <= 0 und räumt den Cache auf.
  void _removeDeadTokens() {
    // Tote Spieler-Einheiten entfernen
    _player.unitList.removeWhere((cook) => cook.woundValue <= 0);

    // Tote Zombies aus allen Dumpstern entfernen
    for (final dumpster in _host.doughDumpsterList) {
      dumpster.zombieList.removeWhere((zombie) => zombie.woundValue <= 0);
    }

    // Leere Dumpster entfernen (optional – Dumpster haben 50 woundValue)
    _host.doughDumpsterList.removeWhere((dumpster) => dumpster.woundValue <= 0);

    // Auswahl zurücksetzen, falls der selektierte Token tot ist
    if (_selectedToken != null && _selectedToken!.woundValue <= 0) {
      _selectedToken = null;
    }

    // Basis-Bewegungswerte für tote Tokens aufräumen (Memory Leak vermeiden)
    _baseMovementValues.removeWhere((token, _) => token.woundValue <= 0);

    // Cache invalidieren, damit tote Tokens sofort aus der Darstellung verschwinden
    _invalidateCache();
  }

  /// Prüft, ob alle Spieler-Tokens ihre Aktionen und Bewegung verbraucht haben.
  /// Ist dies der Fall, wird der Spielerzug automatisch beendet.
  void _checkAutoEndPlayerTurn() {
    if (!_isPlayerTurn || _isGameOver) return;
    if (_player.unitList.isEmpty) return;

    for (final cook in _player.unitList) {
      // Ein Token hat noch Aktionen oder Bewegungspunkte übrig
      if (!cook.hasActed || cook.movementValue > 0) return;
    }

    // Alle Tokens haben gehandelt und keine Bewegung mehr – automatisch beenden
    _showMessage('Alle Einheiten haben keine Aktionen mehr – Zug wird beendet.');
    _endPlayerTurn();
  }

  /// Zeigt eine SnackBar-Nachricht an.
  /// Verwendet einen eindeutigen Schlüssel, um das Stapeln mehrerer
  /// SnackBars zu vermeiden.
  void _showMessage(String message) {
    if (!context.mounted) return;
    _snackBarKey++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: ValueKey('snack_$_snackBarKey'),
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Zeigt ein Kontextmenü für den ausgewählten Token an.
  void _showContextMenu(BuildContext context, Offset position) {
    if (_selectedToken == null) return;
    if (_selectedToken is! ObjectLineCook) return;
    // Nur im Spieler-Zug darf das Kontextmenü geöffnet werden
    if (!_isPlayerTurn || _isGameOver) return;

    final cook = _selectedToken as ObjectLineCook;
    final actions = _player.getAvailableActions(cook);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'info',
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Info'),
            subtitle: Text(
              'AW: ${cook.attackValue} | VW: ${cook.defenseValue} | '
              'BW: ${cook.movementValue} | SW: ${cook.damageValue} | '
              'RW: ${cook.rangeValue} | LP: ${cook.woundValue}',
            ),
          ),
        ),
        const PopupMenuDivider(),
        for (final action in actions)
          PopupMenuItem(
            value: action.name,
            child: Text(action == CombatAction.melee ? 'Nahkampf' : 'Fernkampf'),
          ),
      ],
    ).then((value) {
      if (value == 'info') {
        _showMessage(
          '${cook.name}\n'
          'Angriff: ${cook.attackValue}\n'
          'Verteidigung: ${cook.defenseValue}\n'
          'Bewegung: ${cook.movementValue}\n'
          'Schaden: ${cook.damageValue}\n'
          'Reichweite: ${cook.rangeValue}\n'
          'Trefferpunkte: ${cook.woundValue}',
        );
      } else if (value == CombatAction.melee.name) {
        _enterTargetingMode(CombatAction.melee);
      } else if (value == CombatAction.ranged.name) {
        _enterTargetingMode(CombatAction.ranged);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matrix = widget.transformationController.value;

    return GestureDetector(
      onTapUp: (details) {
        // Bildschirm-Koordinaten in Karten-Koordinaten umrechnen
        final mapPosition = _screenToMap(details.localPosition);
        _handleTap(mapPosition);
      },
      onLongPressStart: (details) {
        // Bei langem Drücken: zuerst den Token unter dem Finger auswählen,
        // dann Kontextmenü anzeigen
        final mapPosition = _screenToMap(details.localPosition);
        _handleTap(mapPosition);
        if (_selectedToken != null) {
          _showContextMenu(context, details.globalPosition);
        }
      },
      onPanStart: (details) {
        final mapPosition = _screenToMap(details.localPosition);
        _handleDragStart(mapPosition);
      },
      onPanUpdate: (details) {
        // Delta muss ebenfalls durch den aktuellen Zoom geteilt werden,
        // damit der Drag in Karten-Koordinaten korrekt ist
        final scale = matrix.getMaxScaleOnAxis();
        final scaledDelta = details.delta / scale;
        _handleDragUpdate(scaledDelta);
      },
      onPanEnd: (details) {
        _handleDragEnd();
      },
      onPanCancel: () {
        if (_isDragging) {
          setState(() {
            _isDragging = false;
            _draggedToken = null;
            _dragOffset = Offset.zero;
          });
        }
      },
      child: Stack(
        children: [
          // Tokens mit der gleichen Transformation wie die Karte zeichnen.
          // Dieses nicht-positionierte Child gibt dem Stack seine Größe.
          Transform(
            transform: matrix,
            child: SizedBox(
              width: widget.mapWidth * widget.tileWidth +
                  widget.tileWidth / 2,
              height: (widget.mapHeight * widget.tileHeight * 3 / 4) +
                  widget.tileHeight / 4,
              child: Stack(
                children: _buildTokenWidgets(),
              ),
            ),
          ),
          // Info-Panel für den ausgewählten Token (nicht transformiert,
          // damit es immer lesbar im Bildschirm bleibt)
          if (_selectedToken != null)
            Positioned(
              left: 8,
              top: 8,
              child: SizedBox(
                width: 220,
                child: _buildInfoPanelContent(),
              ),
            ),
          // Runden- und Status-Anzeige (oben rechts)
          Positioned(
            right: 8,
            top: 8,
            child: _buildStatusPanel(),
          ),
        ],
      ),
    );
  }

  /// Baut das Status-Panel mit Runden-, Initiativ- und Spielstandsanzeige.
  Widget _buildStatusPanel() {
    return Card(
      elevation: 4,
      color: _isGameOver
          ? Colors.amber.shade100
          : _isPlayerTurn
              ? Colors.green.shade50
              : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rundenanzeige
            Text(
              'Runde $_currentRound',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            // Status (wessen Zug)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isGameOver
                        ? Colors.orange
                        : _isPlayerTurn
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isGameOver
                      ? 'Spiel beendet'
                      : _isPlayerTurn
                          ? 'Spieler am Zug'
                          : 'Host am Zug',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isGameOver
                        ? Colors.orange.shade800
                        : _isPlayerTurn
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                  ),
                ),
              ],
            ),
            // Initiativnachricht
            if (_initiativeMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _initiativeMessage!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
            // Spielstand
            const SizedBox(height: 8),
            Text(
              'Line Cooks: ${_player.unitCount}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Gegner: ${_host.activeUnitCount}',
              style: const TextStyle(fontSize: 12),
            ),
            // "Zug beenden"-Button (nur im Spieler-Zug)
            if (_isPlayerTurn && !_isGameOver) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _endPlayerTurn,
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('Zug beenden'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.green.shade900,
                ),
              ),
            ],
            // Spielende-Nachricht
            if (_isGameOver) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Berechnet das in Karten-Koordinaten sichtbare Rechteck (Viewport).
  /// Tokens außerhalb dieses Bereichs werden nicht gezeichnet (Viewport-Culling).
  /// Das Ergebnis wird gecached, da es sich nur bei Transformation ändert.
  Rect _getVisibleMapRect() {
    if (_cachedVisibleRect != null) return _cachedVisibleRect!;

    final matrix = widget.transformationController.value;
    final inverseMatrix = Matrix4.tryInvert(matrix);
    if (inverseMatrix == null) {
      // Falls die Matrix nicht invertiert werden kann, den gesamten Kartenbereich zurückgeben
      _cachedVisibleRect = Rect.fromLTWH(
        0,
        0,
        widget.mapWidth * widget.tileWidth + widget.tileWidth / 2,
        (widget.mapHeight * widget.tileHeight * 3 / 4) + widget.tileHeight / 4,
      );
      return _cachedVisibleRect!;
    }

    // Die Bildschirmgröße über den BuildContext ermitteln
    final screenSize = MediaQuery.of(context).size;

    // Die vier Ecken des Bildschirms in Karten-Koordinaten umrechnen
    final topLeft = MatrixUtils.transformPoint(inverseMatrix, Offset.zero);
    final topRight = MatrixUtils.transformPoint(
        inverseMatrix, Offset(screenSize.width, 0));
    final bottomLeft = MatrixUtils.transformPoint(
        inverseMatrix, Offset(0, screenSize.height));
    final bottomRight = MatrixUtils.transformPoint(
        inverseMatrix, Offset(screenSize.width, screenSize.height));

    // Das umschließende Rechteck in Karten-Koordinaten berechnen
    final minX = [
      topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx
    ].reduce((a, b) => a < b ? a : b);
    final minY = [
      topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy
    ].reduce((a, b) => a < b ? a : b);
    final maxX = [
      topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx
    ].reduce((a, b) => a > b ? a : b);
    final maxY = [
      topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy
    ].reduce((a, b) => a > b ? a : b);

    // Einen großzügigen Rand hinzufügen, damit Tokens nicht zu früh
    // ein-/ausblenden (ca. 2 Tile-Breiten als Puffer)
    const margin = 200.0;
    _cachedVisibleRect = Rect.fromLTRB(
      minX - margin,
      minY - margin,
      maxX + margin,
      maxY + margin,
    );
    return _cachedVisibleRect!;
  }

  /// Berechnet alle erreichbaren Hex-Felder für den ausgewählten Token
  /// basierend auf seinen verbleibenden Bewegungspunkten.
  /// Verwendet BFS über die Hex-Nachbarschaft (odd-r).
  /// Das Ergebnis wird gecached, solange sich Auswahl oder Bewegung nicht ändern.
  Set<int> get _reachableHexFields {
    if (_selectedToken == null || _selectedToken!.movementValue <= 0) {
      return {};
    }

    // Cache verwenden, wenn Auswahl und Bewegung gleich geblieben sind
    if (_cachedReachableFields != null &&
        _cachedReachableToken == _selectedToken &&
        _cachedReachableMovement == _selectedToken!.movementValue &&
        !_cacheDirty) {
      return _cachedReachableFields!;
    }

    final hex = _getTokenHex(_selectedToken!);
    final maxMovement = _selectedToken!.movementValue;
    final occupied = _getOccupiedHexFields(excludeToken: _selectedToken);

    // BFS: Queue von (x, y, remainingSteps)
    visited.reset();
    final reachable = <int>{};
    visited.add(_HexUtils.hexKey(hex.x, hex.y, widget.mapWidth));
    final queue = Queue<({int x, int y, int steps})>();
    queue.add((x: hex.x, y: hex.y, steps: maxMovement));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.steps <= 0) continue;

      for (final offset in _HexUtils.neighborOffsets(current.y)) {
        final nx = current.x + offset.dx;
        final ny = current.y + offset.dy;
        if (nx < 0 || nx >= widget.mapWidth || ny < 0 || ny >= widget.mapHeight) continue;
        final key = _HexUtils.hexKey(nx, ny, widget.mapWidth);
        if (visited.contains(key)) continue;
        visited.add(key);
        if (occupied.contains(key)) continue;
        reachable.add(key);
        queue.add((x: nx, y: ny, steps: current.steps - 1));
      }
    }

    _cachedReachableFields = reachable;
    _cachedReachableToken = _selectedToken;
    _cachedReachableMovement = maxMovement;
    return reachable;
  }

  /// Baut die Widgets für erreichbare Felder (grüne Overlays).
  List<Widget> _buildReachableFieldWidgets(
    Set<int> reachableFields,
    Rect visibleRect,
  ) {
    if (reachableFields.isEmpty) return const [];

    final widgets = <Widget>[];
    for (final key in reachableFields) {
      final x = key % widget.mapWidth;
      final y = key ~/ widget.mapWidth;
      final pixel = _hexToPixel(x: x, y: y);

      // Viewport-Culling
      if (!visibleRect.contains(pixel)) continue;

      widgets.add(
        Positioned(
          left: pixel.dx - widget.tileWidth / 2,
          top: pixel.dy - widget.tileHeight / 2,
          child: IgnorePointer(
            child: Container(
              width: widget.tileWidth.toDouble(),
              height: widget.tileHeight.toDouble(),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.25),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Baut die Widgets für targetierbare Gegner (rote Highlights).
  List<Widget> _buildTargetingHighlightWidgets(Rect visibleRect) {
    if (_pendingAction == null || _targetableEnemies.isEmpty) return const [];

    final widgets = <Widget>[];
    for (final enemy in _targetableEnemies) {
      if (enemy.woundValue <= 0) continue;
      if (!visibleRect.contains(enemy.position)) continue;

      final hex = _getTokenHex(enemy);
      final pixel = _hexToPixel(x: hex.x, y: hex.y);

      widgets.add(
        Positioned(
          left: pixel.dx - widget.tileWidth / 2,
          top: pixel.dy - widget.tileHeight / 2,
          child: IgnorePointer(
            child: Container(
              width: widget.tileWidth.toDouble(),
              height: widget.tileHeight.toDouble(),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.3),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.8),
                  width: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Baut die Widgets für alle Tokens auf der Karte.
  /// Tokens außerhalb des sichtbaren Viewports werden übersprungen (Culling).
  /// Wenn ein Token ausgewählt ist, werden seine erreichbaren Hex-Felder
  /// als transparente grüne Overlays angezeigt.
  List<Widget> _buildTokenWidgets() {
    final widgets = <Widget>[];

    // Sichtbaren Bereich in Karten-Koordinaten ermitteln
    final visibleRect = _getVisibleMapRect();

    // Erreichbare Felder für den ausgewählten Token berechnen
    final reachableFields = _reachableHexFields;

    // Highlight-Widgets für erreichbare Felder zeichnen
    widgets.addAll(_buildReachableFieldWidgets(reachableFields, visibleRect));

    // Im Targeting-Modus: rote Highlights für targetierbare Gegner zeichnen
    widgets.addAll(_buildTargetingHighlightWidgets(visibleRect));

    // Tokens zeichnen
    for (final renderInfo in _allTokens) {
      final token = renderInfo.token;
      if (token.woundValue <= 0) continue;

      Offset displayPosition = token.position;
      if (_isDragging && _draggedToken == token) {
        displayPosition += _dragOffset;
      }

      // Viewport-Culling: Nur Tokens im sichtbaren Bereich zeichnen
      if (!visibleRect.contains(displayPosition)) {
        continue;
      }

      final tokenSize = (widget.tileWidth * 0.7).clamp(20.0, 48.0);
      final halfTokenSize = tokenSize / 2;

      widgets.add(
        Positioned(
          left: displayPosition.dx - halfTokenSize,
          top: displayPosition.dy - halfTokenSize,
          child: _TokenWidget(
            token: token,
            isSelected: _selectedToken == token,
            isDragging: _isDragging && _draggedToken == token,
            tileWidth: widget.tileWidth,
            tileHeight: widget.tileHeight,
          ),
        ),
      );
    }

    return widgets;
  }

  /// Baut den Inhalt des Info-Panels für den ausgewählten Token.
  Widget _buildInfoPanelContent() {
    final token = _selectedToken!;
    final isPlayerUnit = _player.unitList.contains(token);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              token.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPlayerUnit ? 'Spieler-Einheit' : 'Gegner',
              style: TextStyle(
                fontSize: 12,
                color: isPlayerUnit ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            _infoRow('Angriff', token.attackValue.toString()),
            _infoRow('Verteidigung', token.defenseValue.toString()),
            _infoRow('Bewegung', token.movementValue.toString()),
            _infoRow('Schaden', token.damageValue.toString()),
            _infoRow('Reichweite', token.rangeValue.toString()),
            _infoRow('Trefferpunkte', token.woundValue.toString()),
            if (isPlayerUnit) ..._buildPlayerActionButtons(token),
          ],
        ),
      ),
    );
  }

  /// Baut die Aktions-Buttons für Spieler-Einheiten im Info-Panel.
  List<Widget> _buildPlayerActionButtons(ObjectToken token) {
    final buttons = <Widget>[
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: (_isPlayerTurn && !_isGameOver && !token.hasActed)
            ? () => _enterTargetingMode(CombatAction.melee)
            : null,
        icon: const Icon(Icons.local_fire_department, size: 16),
        label: const Text('Nahkampf'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    ];

    if (token.rangeValue > 0) {
      buttons.add(const SizedBox(height: 4));
      buttons.add(
        ElevatedButton.icon(
          onPressed: (_isPlayerTurn && !_isGameOver && !token.hasActed)
              ? () => _enterTargetingMode(CombatAction.ranged)
              : null,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Fernkampf'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      );
    }

    return buttons;
  }

  /// Hilfswidget für eine einzelne Info-Zeile.
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Ein spezialisiertes Set für BFS-Besuchsmarkierungen, das Wiederverwendung
/// des internen Speichers ermöglicht, ohne jedes Mal eine neue Allokation
/// durchführen zu müssen.
class _BfsVisitedSet {
  final Map<int, int> _storage = {};
  int _generation = 0;

  /// Setzt die Besuchsmarkierungen zurück, ohne den internen Speicher
  /// freizugeben.
  void reset() {
    _generation++;
  }

  /// Fügt einen Wert als besucht hinzu.
  void add(int key) {
    _storage[key] = _generation;
  }

  /// Prüft, ob ein Wert besucht wurde.
  bool contains(int key) {
    return _storage[key] == _generation;
  }
}

/// Hilfsklasse, die einen Token mit Metadaten für die Darstellung kapselt.
class _TokenRenderInfo {
  final ObjectToken token;
  final bool isPlayerUnit;

  const _TokenRenderInfo({
    required this.token,
    required this.isPlayerUnit,
  });
}

/// Widget, das einen einzelnen Token auf der Karte darstellt.
class _TokenWidget extends StatelessWidget {
  final ObjectToken token;
  final bool isSelected;
  final bool isDragging;
  final int tileWidth;
  final int tileHeight;

  const _TokenWidget({
    required this.token,
    required this.isSelected,
    required this.isDragging,
    required this.tileWidth,
    required this.tileHeight,
  });

  @override
  Widget build(BuildContext context) {
    final tokenSize = (tileWidth * 0.7).clamp(20.0, 48.0);

    return Opacity(
      opacity: isDragging ? 0.8 : 1.0,
      child: SizedBox(
        width: tokenSize,
        height: tokenSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Hintergrund-Kreis
            Container(
              width: tokenSize,
              height: tokenSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getTokenColor(),
                border: Border.all(
                  color: isSelected ? Colors.yellow : Colors.black,
                  width: isSelected ? 3.0 : 1.5,
                ),
                boxShadow: [
                  if (isDragging)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                ],
              ),
            ),
            // Token-Label
            Text(
              _getTokenLabel(),
              style: TextStyle(
                color: Colors.white,
                fontSize: tokenSize * 0.3,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            // Wund-Anzeige (unten rechts)
            if (token.woundValue > 0)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${token.woundValue}',
                    style: TextStyle(
                      color: token.woundValue <= 2 ? Colors.red.shade300 : Colors.white,
                      fontSize: tokenSize * 0.25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTokenColor() {
    if (token is ObjectLineCook) return Colors.blue;
    if (token is ObjectDoughDumpster) return Colors.purple;
    if (token is ObjectDoughZombie) return Colors.red.shade700;
    return Colors.grey;
  }

  String _getTokenLabel() {
    if (token is ObjectLineCook) return 'LC';
    if (token is ObjectDoughDumpster) return 'DD';
    if (token is ObjectDoughZombie) return 'DZ';
    return '??';
  }
}
