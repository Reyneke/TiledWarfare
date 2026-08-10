import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/boss_monsters/object_dough_dumpster.dart';
import 'package:tiled_warfare/objects/monsters/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/services/fog_of_war.dart';
import 'package:tiled_warfare/models/map_data.dart';

import 'package:tiled_warfare/utils/hex_grid.dart';

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
  /// Die zentrale Hex-Utility-Instanz für alle Gitter-Berechnungen.
  final HexGrid hexGrid;

  /// Der [TransformationController] des [InteractiveViewer] der Karte,
  /// um die Token-Positionen mit dem Zoom/Scroll der Karte zu synchronisieren.
  final TransformationController transformationController;

  /// Callback, um die Kamera auf eine bestimmte Karten-Position zu zentrieren
  /// (wird an [ScreenMain] weitergereicht, das den [InteractiveViewer] steuert).
  final void Function(Offset mapPosition)? onRequestCameraFocus;

  /// Die geparsten Spawnpunkte aus der Map.
  /// Jeder Spawnpunkt hat einen Namen (z. B. "spawn_player1", "spawn_monster")
  /// und Pixel-Koordinaten (x, y) aus der TMX-Datei.
  final List<({String name, double x, double y})> spawnPoints;

  /// Callback, der aufgerufen wird, wenn das Spiel vorbei ist (Sieg oder Niederlage).
  /// Der übergebene Boolean ist `true` bei Sieg, `false` bei Niederlage.
  final void Function(bool playerWon)? onGameOver;

  /// Menge blockierter Hex-Felder aus dem Kollisions-Layer der TMX-Karte.
  ///
  /// Wird vom [ScreenMain] nach dem Parsen der Karte übergeben.
  /// Enthält alle Hex-Keys, die durch den "collision"-Layer blockiert sind.
  final Set<int> collisionSet;

  /// Optionaler FogOfWarService für Sichtbarkeits-Berechnung.
  ///
  /// Wenn gesetzt, wird die Sichtbarkeit zu Beginn jeder Runde neu
  /// berechnet und an den Karten-Renderer weitergegeben.
  final FogOfWarService? fogOfWarService;

  /// Gelände-Map für die Fog-of-War-Berechnung (hexKey → TerrainType).
  final Map<int, TerrainType>? terrainMap;

  const WidgetCaretaker({
    super.key,
    required this.hexGrid,
    required this.transformationController,
    this.spawnPoints = const [],
    this.onGameOver,
    this.onRequestCameraFocus,
    this.collisionSet = const {},
    this.fogOfWarService,
    this.terrainMap,
  });

  @override
  State<WidgetCaretaker> createState() => _WidgetCaretakerState();
}

class _WidgetCaretakerState extends State<WidgetCaretaker> with TickerProviderStateMixin {
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

  /// Ghost-Tokens: Gegner auf aufgedeckten, aber nicht sichtbaren Feldern.
  /// Wird nach jeder Sichtbarkeits-Berechnung aktualisiert.
  final Map<ObjectToken, Offset> _ghostTokenPositions = {};

  /// Animation-Controller für sanfte Token-Bewegungen (Host Tokens gleiten).
  AnimationController? _tokenAnimationController;

  /// Merkt sich die Startpositionen aller Tokens, die gerade animiert werden.
  /// Wird benötigt, da ObjectToken kein _animationStart-Feld hat.
  final Map<ObjectToken, Offset> _tokenAnimationStarts = {};

  /// Letzte Layout-Constraints des [LayoutBuilder] (verfügbarer Viewport).
  ///
  /// Wird in [_getVisibleMapRect] verwendet, um die tatsächliche Widget-Größe
  /// zu ermitteln. `context.size` ist während des Builds nicht verfügbar,
  /// daher werden die Constraints im Build gespeichert.
  BoxConstraints? _lastConstraints;

  @override
  void initState() {
    super.initState();
    _initializeGameObjects();
    // Auf Änderungen der Transformation (Zoom/Scroll) lauschen,
    // um die Token-Positionen zu aktualisieren
    widget.transformationController.addListener(_onTransformationChanged);

    // Auf Fog-of-War-Änderungen lauschen, um Ghost-Positionen zu aktualisieren
    widget.fogOfWarService?.addListener(_onFogOfWarChanged);

    // Animation-Controller für Token-Animationen (Host gleiten)
    _tokenAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_animateTokens);

    // Nach der Initialisierung die erste Runde starten
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNewRound();
    });
  }

  @override
  void dispose() {
    widget.fogOfWarService?.removeListener(_onFogOfWarChanged);
    widget.transformationController.removeListener(_onTransformationChanged);
    _tokenAnimationController?.dispose();
    super.dispose();
  }

  /// Wird aufgerufen, wenn sich die Sichtbarkeit (Fog of War) geändert hat.
  /// Aktualisiert die Ghost-Positionen und löst ein Neuzeichnen aus.
  void _onFogOfWarChanged() {
    if (!mounted) return;
    _invalidateCache();
    setState(() {});
  }

  /// Animiert alle Tokens mit gesetztem targetPosition über die
  /// Animationsdauer des [_tokenAnimationController] (300ms).
  ///
  /// Verwendet den normierten Fortschritt [0..1] des AnimationControllers
  /// statt einer frame-rate-abhängigen Interpolation, sodass die Animation
  /// auf 60 Hz und 120 Hz Displays gleich schnell läuft.
  void _animateTokens() {
    bool needsUpdate = false;
    final progress = _tokenAnimationController?.value ?? 0.0;
    // Ease-Out für sanftes Abbremsen
    final t = 1.0 - (1.0 - progress) * (1.0 - progress);
    
    for (final renderInfo in _allTokens) {
      final token = renderInfo.token;
      if (token.targetPosition == null) continue;
      
      if (!_tokenAnimationStarts.containsKey(token)) {
        _tokenAnimationStarts[token] = token.position;
      }
      
      token.position = Offset.lerp(
        _tokenAnimationStarts[token]!,
        token.targetPosition!,
        t,
      )!;
      
      if (progress >= 1.0) {
        token.position = token.targetPosition!;
        token.targetPosition = null;
        _tokenAnimationStarts.remove(token);
      }
      needsUpdate = true;
    }
    
    if (needsUpdate) {
      _invalidateCache();
      setState(() {});
    } else {
      _tokenAnimationController?.stop();
    }
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
      playerSpawnPosition = widget.hexGrid.hexToPixel(x: 2, y: 5);
    }

    // Vorhandene Spieler-Einheiten um den gewählten Spawnpunkt positionieren
    final playerUnits = _player.unitList;
    for (int i = 0; i < playerUnits.length; i++) {
      final unit = playerUnits[i];
      // Für Apprentice und Line Cook gleichermaßen positionieren
      // Leichter Versatz, damit die Tokens nicht exakt übereinander liegen
      final roughPosition = Offset(
        playerSpawnPosition.dx + (i - (playerUnits.length - 1) / 2) * widget.hexGrid.tileWidth * 0.5,
        playerSpawnPosition.dy + (i - (playerUnits.length - 1) / 2) * widget.hexGrid.tileHeight * 0.5,
      );
      // Auf das nächstgelegene freie Hex-Feld snappen, damit Tokens nicht
      // zwischen Hex-Feldern schweben (Bugfix: "Tokens schweben im Nichts")
      unit.position = _snapToNearestFreeHex(roughPosition, excludeToken: unit);
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
      dumpster.position = widget.hexGrid.hexToPixel(x: 25, y: 5);
    }
    _host.doughDumpsterList.add(dumpster);

    // Start-Zombies vom Dumpster spawnen lassen – verteilt um den Dumpster herum
    // auf freien Hex-Feldern, um Stapelung zu vermeiden
    final zombies = dumpster.spawnZombies();
    final dumpsterHex = widget.hexGrid.pixelToHex(dumpster.position);
    // Alle belegten Felder ermitteln (Dumpster selbst + bereits platzierte Zombies)
    final occupied = <int>{};
    occupied.add(widget.hexGrid.hexKey(dumpsterHex.x, dumpsterHex.y));
    for (int i = 0; i < zombies.length; i++) {
      // Spiralförmig nach einem freien Feld in der Nähe des Dumpsters suchen
      final freePos = widget.hexGrid.findFreeHexNear(
        startX: dumpsterHex.x,
        startY: dumpsterHex.y,
        occupied: occupied,
      );
      zombies[i].position = freePos;
      // Neu platzierten Zombie als belegt markieren
      final zh = widget.hexGrid.pixelToHex(freePos);
      occupied.add(widget.hexGrid.hexKey(zh.x, zh.y));
    }

    _invalidateCache();
  }

  /// Setzt den Bewegungswert und das hasActed-Flag eines Tokens zurück.
  /// Nutzt [ObjectToken.baseMovementValue] (final), um den ursprünglichen
  /// Konstruktor-Wert zu erhalten – unabhängig von früheren Spielrunden.
  void _resetTokenRoundState(ObjectToken token) {
    token.movementValue = token.baseMovementValue;
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

  /// Setzt den [timesAttackedThisTurn]-Zähler für alle Tokens zurück.
  /// Wird zu Beginn jedes neuen Zuges der kontrollierenden Seite aufgerufen,
  /// um den kumulativen Malus für mehrfach angegriffene Tokens zu löschen.
  void _resetAllAttackCounters() {
    // Spieler-Einheiten
    for (final cook in _player.unitList) {
      cook.timesAttackedThisTurn = 0;
    }
    // Gegnerische Dough Dumpster und deren Zombies
    for (final dumpster in _host.doughDumpsterList) {
      dumpster.timesAttackedThisTurn = 0;
      for (final zombie in dumpster.zombieList) {
        zombie.timesAttackedThisTurn = 0;
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

    // Fog of War: Sichtbarkeit zu Beginn jeder Runde neu berechnen
    _computeFogOfWar();

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

    // Attack-Zähler für die neue Runde zurücksetzen (Malus-System)
    _resetAllAttackCounters();

    _invalidateCache();

    // Wenn der Host die Initiative hat, führt er sofort seinen Zug aus
    if (_isHostTurn) {
      _executeHostTurn();
    }

    setState(() {});
  }

  /// Berechnet die Sichtbarkeit für die aktuelle Runde neu (Fog of War).
  ///
  /// Verwendet den [fogOfWarService] und die aktuellen Spieler-Einheiten.
  /// Aktualisiert außerdem die Ghost-Positionen für Gegner auf aufgedeckten,
  /// aber nicht sichtbaren Feldern.
  void _computeFogOfWar() {
    final fog = widget.fogOfWarService;
    if (fog == null) return;

    fog.computeVisibility(
      friendlyTokens: _player.unitList,
      terrainMap: widget.terrainMap ?? {},
      terrainConfigs: TerrainConfig.defaults,
    );

    // Ghost-Positionen aktualisieren: Gegner auf aufgedeckten Feldern
    _ghostTokenPositions.clear();
    final allEnemies = <ObjectToken>[];
    for (final dumpster in _host.doughDumpsterList) {
      allEnemies.add(dumpster);
      allEnemies.addAll(dumpster.zombieList);
    }
    for (final enemy in fog.getRevealedEnemies(allEnemies)) {
      final enemyHex = widget.hexGrid.pixelToHex(enemy.position);
      if (fog.isVisible(widget.hexGrid.hexKey(enemyHex.x, enemyHex.y))) {
        continue; // Sichtbare Gegner werden normal gezeichnet
      }
      _ghostTokenPositions[enemy] = enemy.position;
    }
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
    if (_player.unitList.every((u) => u.woundValue <= 0)) {
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
    
    // playerUnits übergeben, damit Zombies nicht auf Spieler-Tokens spawnen (Bugfix)
    final spawnLogs = _host.performAllDumpsterSpawning(
      playerUnits: _player.unitList,
    );
    for (final log in spawnLogs) {
      _showMessage(log);
    }
  }

  /// Führt die Bewegung aller Host-Zombies aus.
  void _executeHostMovement() {
    _host.moveAllZombiesTowardsTargets(_player.unitList);
    // Token-Animation starten, damit Zombies sanft gleiten.
    // reset() + forward() statt repeat(), damit die Animation nach
    // einmaligem Durchlauf endet und die Tokens an ihrer Zielposition
    // stoppen. reset() ist nötig, da forward() auf einem bereits
    // abgeschlossenen Controller sofort fertig wäre.
    _tokenAnimationController?.reset();
    _tokenAnimationController?.forward();
  }

  /// Führt die Angriffe aller Host-Zombies aus.
  ///
  /// Der Host entscheidet taktisch, ob er FocusFire einsetzt oder
  /// jeden Zombie einzeln angreifen lässt. FocusFire wird bevorzugt,
  /// wenn eine Spieler-Einheit bereits verwundbar ist (woundValue < 50%
  /// des Maximalwerts) oder mehrere Zombies in Reichweite sind.
  ///
  /// Siehe auch: [ObjectHost.performHostFocusFire], [ObjectHost.performAllZombieAttacks].
  void _executeHostAttacks() {
    // Zähle verfügbare Zombies (lebend, in Reichweite zu irgendeinem Ziel)
    int zombiesInRange = 0;
    for (final dumpster in _host.doughDumpsterList) {
      for (final zombie in dumpster.zombieList) {
        if (zombie.woundValue <= 0 || zombie.hasActed) continue;
        for (final playerUnit in _player.unitList) {
          if (playerUnit.woundValue <= 0) continue;
          final zombieHex = widget.hexGrid.pixelToHex(zombie.position);
          final cookHex = widget.hexGrid.pixelToHex(playerUnit.position);
          final hexDistance = widget.hexGrid.distance(
            x1: zombieHex.x, y1: zombieHex.y,
            x2: cookHex.x, y2: cookHex.y,
          );
          if (hexDistance <= zombie.rangeValue + 1) {
            zombiesInRange++;
            break;
          }
        }
      }
    }

    // FocusFire einsetzen, wenn mindestens 3 Zombies ein Ziel erreichen können
    // oder eine Spieler-Einheit bereits angeschlagen ist (woundValue <= 5)
    final bool hasDamagedTarget = _player.unitList.any((u) => u.woundValue > 0 && u.woundValue <= 5);
    final bool useFocusFire = zombiesInRange >= 3 || (zombiesInRange >= 2 && hasDamagedTarget);

    List<String> combatLogs;
    if (useFocusFire) {
      combatLogs = _host.performHostFocusFire(_player);
      if (combatLogs.isEmpty) {
        // Fallback: Falls FocusFire kein Ziel fand, normale Angriffe ausführen
        combatLogs = _host.performAllZombieAttacks(_player);
      }
    } else {
      combatLogs = _host.performAllZombieAttacks(_player);
    }

    for (final log in combatLogs) {
      _showMessage(log);
    }
  }

  /// Gibt die Hex-Gitter-Koordinaten (x, y) für einen Token zurück,
  /// basierend auf seiner aktuellen Pixel-Position.
  ({int x, int y}) _getTokenHex(ObjectToken token) {
    return widget.hexGrid.pixelToHex(token.position);
  }

  /// Baut eine Menge aller blockierten Hex-Felder auf.
  ///
  /// Ein Feld gilt als blockiert, wenn:
  /// 1. Ein lebender Token darauf steht (Token-Belegung)
  /// 2. Es im Kollisions-Layer der Karte markiert ist (TMX collision-Layer)
  ///
  /// Der [excludeToken] wird bei der Token-Belegung ignoriert (z. B. der
  /// gerade gezogene Token).
  ///
  /// Das Ergebnis wird gecached, wenn kein excludeToken übergeben wird.
  Set<int> _getBlockedHexFields({ObjectToken? excludeToken}) {
    if (excludeToken != null || _cacheDirty || _cachedOccupiedFields == null) {
      return _buildBlockedHexFields(excludeToken: excludeToken);
    }
    return _cachedOccupiedFields!;
  }

  Set<int> _buildBlockedHexFields({ObjectToken? excludeToken}) {
    final blocked = widget.hexGrid.buildOccupiedHexFields(
      _allTokens.map((r) => r.token),
      excludeToken: excludeToken,
    );
    blocked.addAll(widget.collisionSet);
    return blocked;
  }

  /// Prüft, ob ein bestimmtes Hex-Feld (x, y) frei ist (kein lebender Token
  /// darauf steht, und nicht durch den Kollisions-Layer blockiert).
  /// Der [excludeToken] wird ignoriert.
  bool _isHexFieldFree(int x, int y, {ObjectToken? excludeToken}) {
    final blocked = _getBlockedHexFields(excludeToken: excludeToken);
    return !blocked.contains(widget.hexGrid.hexKey(x, y));
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

    final blocked = _buildBlockedHexFields(excludeToken: excludeToken);
    visited.reset();
    final queue = Queue<({int x, int y, int steps})>();
    queue.add((x: startX, y: startY, steps: maxSteps));
    visited.add(widget.hexGrid.hexKey(startX, startY));
    final targetKey = widget.hexGrid.hexKey(targetX, targetY);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.steps <= 0) continue;

      for (final offset in widget.hexGrid.neighborOffsets(current.y)) {
        final nx = current.x + offset.dx;
        final ny = current.y + offset.dy;
        if (!widget.hexGrid.isInBounds(nx, ny)) continue;
        final key = widget.hexGrid.hexKey(nx, ny);
        if (visited.contains(key)) continue;
        visited.add(key);
        if (key == targetKey) return true;
        if (blocked.contains(key)) continue;
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
    final approxHex = widget.hexGrid.pixelToHex(pixel);

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
        return widget.hexGrid.hexToPixel(x: approxHex.x, y: approxHex.y);
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
    return widget.hexGrid.hexToPixel(x: approxHex.x, y: approxHex.y);
  }

  /// Prüft ein einzelnes Hex-Feld auf Freiheit und Erreichbarkeit.
  /// Gibt die Pixel-Position zurück, wenn das Feld geeignet ist, sonst null.
  Offset? _checkSpiralEdge(
    int x,
    int y, {
    ({int x, int y})? startHex,
    ObjectToken? excludeToken,
  }) {
    if (!widget.hexGrid.isInBounds(x, y)) return null;
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
    return widget.hexGrid.hexToPixel(x: x, y: y);
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
        // Kamera auf den ausgewählten Token fokussieren
        widget.onRequestCameraFocus?.call(tappedToken.position);
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
          ? widget.hexGrid.tileWidth.toDouble()
          : widget.hexGrid.tileWidth.toDouble() * 1.3;
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

  /// Prüft Spielende nach einer Kampfaktion und leitet ggf. den
  /// automatischen Zug-Ende ein.
  ///
  /// Extrahiert aus [_executeActionOnTarget] und [_executeFocusFireOnTarget],
  /// da beide dieselbe Logik nach einem Angriff durchführen.
  /// Gibt `true` zurück, wenn das Spiel beendet ist (Host besiegt).
  bool _handlePostCombatState() {
    if (_host.isDefeated) {
      _isGameOver = true;
      _statusMessage = 'Spieler hat gewonnen! Alle Gegner besiegt.';
      setState(() {});
      return true;
    }
    _checkAutoEndPlayerTurn();
    return false;
  }

  /// Behandelt einen Tap im Targeting-Modus.
  void _handleTapInTargetingMode(ObjectToken tappedToken) {
    if (_targetableEnemies.contains(tappedToken)) {
      // Gültiges Ziel getroffen – Aktion ausführen
      final action = _pendingAction!;
      _pendingAction = null;
      _targetableEnemies = {};

      if (action == CombatAction.focusFire) {
        _executeFocusFireOnTarget(tappedToken);
      } else {
        _executeActionOnTarget(action, tappedToken);
      }
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
        width: widget.hexGrid.tileWidth.toDouble(),
        height: widget.hexGrid.tileHeight.toDouble(),
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
  /// Der _dragOffset wird auf die Karten-Pixel-Grenzen begrenzt, sodass der
  /// Token nicht außerhalb der Karte landen kann (Bugfix: "Tokens können die
  /// Karte verlassen"). Der Clamp erfolgt direkt im Offset, nicht erst beim
  /// Rendering, damit es keine Sprünge beim Loslassen gibt.
  void _handleDragUpdate(Offset delta) {
    if (!_isDragging || _draggedToken == null) return;
    setState(() {
      final newOffset = _dragOffset + delta;
      final startPos = _draggedToken!.position;
      final newPos = startPos + newOffset;
      final clampedPos = Offset(
        newPos.dx.clamp(0, widget.hexGrid.mapPixelWidth.toDouble()),
        newPos.dy.clamp(0, widget.hexGrid.mapPixelHeight.toDouble()),
      );
      _dragOffset = clampedPos - startPos;
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
      final targetHex = widget.hexGrid.pixelToHex(snappedPosition);

      // Bewegung auf movementValue begrenzen
      if (_dragStartHex != null) {
        final distance = widget.hexGrid.distance(
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
    });

    // Fog of War: Sichtbarkeit nach der Bewegung aktualisieren,
    // damit der Spieler die neue Sichtweite sofort sieht.
    // Wird NACH setState aufgerufen, um verschachtelte setState-Aufrufe
    // über notifyListeners() zu vermeiden (verlässliche Aktualisierung).
    _computeFogOfWar();

    // Nach Bewegung prüfen, ob alle Tokens fertig sind
    _checkAutoEndPlayerTurn();
  }

  /// Versetzt das Spiel in den Targeting-Modus für die angegebene Aktion.
  /// Zeigt alle erreichbaren Gegner als rote Highlights an.
  /// Erst ein Klick auf einen Gegner führt die Aktion aus.
  void _enterTargetingMode(CombatAction action) {
    if (_selectedToken == null) return;
    if (_selectedToken is! ObjectApprentice) return;
    if (!_isPlayerTurn || _isGameOver) return;

    final attacker = _selectedToken as ObjectApprentice;

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

      final distance = widget.hexGrid.distance(
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
    if (_selectedToken == null || _selectedToken is! ObjectApprentice) return;
    final attacker = _selectedToken as ObjectApprentice;

    // Entfernung in Hex-Feldern ermitteln
    final distanceInHex = widget.hexGrid.distance(
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

    // Der Attack-Zähler des Verteidigers wird automatisch von
    // performAction() erhöht (Malus-System).

    // Ergebnis anzeigen
    final message = _buildCombatResultMessage(target, result);
    _showMessage(message);

    // Tote Einheiten entfernen
    _removeDeadTokens();

    // Prüfen, ob der Host besiegt wurde und ggf. Zug automatisch beenden
    if (_handlePostCombatState()) return;
  }

  /// Führt eine FocusFire-Aktion für den Spieler aus.
  /// Alle verfügbaren Spieler-Einheiten greifen das gewählte Ziel an,
  /// sofern sie in Reichweite sind.
  ///
  /// Jeder Angreifer wählt automatisch die beste Aktion:
  /// - Nahkampf (melee), wenn das Ziel benachbart ist (distance <= 1)
  /// - Fernkampf (ranged), wenn das Ziel in Fernkampf-Reichweite liegt
  /// - Überspringt den Angreifer, wenn keine Reichweite gegeben ist
  void _executeFocusFireOnTarget(ObjectToken target) {
    if (_selectedToken == null) return;

    // Alle Spieler-Einheiten sammeln, die noch nicht gehandelt haben
    final availableAttackers = <ObjectToken>[];
    for (final unit in _player.unitList) {
      if (unit.woundValue <= 0) continue;
      if (unit.hasActed) continue;
      availableAttackers.add(unit);
    }

    if (availableAttackers.isEmpty) {
      _showMessage('Keine verfügbaren Einheiten für FocusFire!');
      return;
    }

    // FocusFire ausführen – jeder Angreifer wählt automatisch die beste
    // verfügbare Aktion (Nahkampf wenn benachbart, sonst Fernkampf)
    final result = _player.performFocusFire(
      attackers: availableAttackers,
      defender: target,
      action: CombatAction.melee, // Wird pro Angreifer überschrieben
      getDistance: (attacker) => widget.hexGrid.distance(
        x1: _getTokenHex(attacker).x,
        y1: _getTokenHex(attacker).y,
        x2: _getTokenHex(target).x,
        y2: _getTokenHex(target).y,
      ),
    );

    // Der Attack-Zähler des Verteidigers wird automatisch für jeden
    // einzelnen Angriff von performAction() erhöht (Malus-System).

    // Ergebnisse anzeigen
    final messageBuffer = StringBuffer('FocusFire auf ${target.name}: ');
    if (result.attacks.isNotEmpty) {
      messageBuffer.writeln('${result.attacks.length} Angriffe, ${result.totalDamage} Gesamtschaden.');
      for (final attack in result.attacks) {
        messageBuffer.writeln(
          '- ${attack.attacker.name}: ${attack.result.hit ? "Treffer (${attack.result.damage} Schaden)" : "Verfehlt"}',
        );
      }
    } else {
      messageBuffer.write('Keine Angriffe möglich.');
    }
    _showMessage(messageBuffer.toString());

    // Tote Einheiten entfernen
    _removeDeadTokens();

    // Prüfen, ob der Host besiegt wurde und ggf. Zug automatisch beenden
    if (_handlePostCombatState()) return;
  }

  /// Versetzt das Spiel in den FocusFire-Targeting-Modus.
  /// Zeigt nur Gegner als Ziele an, die von mindestens einer verfügbaren
  /// Einheit erreicht werden können (Nahkampf ODER Fernkampf).
  /// Ein Klick auf einen Gegner startet den Massenangriff.
  void _enterFocusFireTargetingMode() {
    if (!_isPlayerTurn || _isGameOver) return;

    // Verfügbare Einheiten sammeln (noch nicht gehandelt)
    final availableUnits = <ObjectApprentice>[];
    for (final unit in _player.unitList) {
      if (unit.woundValue <= 0) continue;
      if (!unit.hasActed) {
        availableUnits.add(unit);
      }
    }

    if (availableUnits.isEmpty) {
      _showMessage('Keine Einheiten verfügbar für FocusFire!');
      return;
    }

    // Nur Gegner als Ziele markieren, die von mindestens einer verfügbaren
    // Einheit erreicht werden können (Nahkampf ODER Fernkampf).
    final targets = <ObjectToken>{};
    for (final renderInfo in _allTokens) {
      if (renderInfo.isPlayerUnit) continue;
      final enemy = renderInfo.token;
      if (enemy.woundValue <= 0) continue;

      // Prüfen, ob mindestens ein verfügbarer Angreifer diesen Gegner
      // im Nahkampf (distance <= 1) ODER Fernkampf (distance <= rangeValue)
      // erreichen kann
      final enemyHex = _getTokenHex(enemy);
      for (final unit in availableUnits) {
        final unitHex = _getTokenHex(unit);
        final distance = widget.hexGrid.distance(
          x1: unitHex.x, y1: unitHex.y,
          x2: enemyHex.x, y2: enemyHex.y,
        );
        if (distance <= 1 || (unit.rangeValue > 0 && distance <= unit.rangeValue)) {
          targets.add(enemy);
          break; // Ein Angreifer reicht, um das Ziel anzuzeigen
        }
      }
    }

    if (targets.isEmpty) {
      _showMessage('Kein Gegner in Nahkampf- oder Fernkampf-Reichweite für FocusFire!');
      return;
    }

    setState(() {
      _pendingAction = CombatAction.focusFire;
      _targetableEnemies = targets;
    });
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

  /// Entfernt alle toten Tokens (woundValue <= 0) und räumt den Cache auf.
  ///
  /// **Wichtig:** Tote Spieler-Einheiten werden NICHT aus _player.unitList
  /// entfernt, damit der Battle Result Screen sie beim _computeResults()
  /// noch auslesen kann (Anzeige der Gefallenen, XP-Verteilung etc.).
  /// Sie werden lediglich über _buildAllTokens() (woundValue <= 0-Check
  /// im Rendering) ausgeblendet.
  void _removeDeadTokens() {
    // Tote Spieler-Einheiten werden NICHT aus unitList entfernt,
    // damit der Battle Result Screen sie auslesen kann.
    // Das Rendering filtert sie bereits über _buildAllTokens().

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

    // Cache invalidieren, damit tote Tokens sofort aus der Darstellung verschwinden
    _invalidateCache();
  }

  /// Kehrt zum Restaurant-Bildschirm zurück und aktualisiert das Profil.
  void _returnToRestaurant() {
    // Prüfen, ob der Spieler tatsächlich gewonnen hat (mindestens eine
    // Einheit mit woundValue > 0). _player.unitList.isEmpty allein reicht
    // nicht, da tote Einheiten nicht aus unitList entfernt werden (sie
    // werden vom Battle Result Screen für die Anzeige der Gefallenen
    // benötigt).
    final hasAliveUnits = _player.unitList.any((u) => u.woundValue > 0);
    // Benachrichtige ScreenMain über das Spiel-Ende (Callback).
    // ScreenMain führt dann ein Navigator.pushReplacement zum
    // ScreenBattleResult durch, daher KEIN zusätzliches .pop() hier.
    // Wichtig: KEIN _updateProfileAfterBattle() hier aufrufen!
    // ScreenBattleResult._computeResults() führt den Profil-Sync (inkl.
    // Rettungswürfe + Speichern) selbst durch. Ein vorheriger Sync würde
    // die woundValues toter Einheiten durch Rettungswürfe verändern, bevor
    // _computeResults() sie für die Überlebenden-/Gefallenen-Anzeige
    // auslesen kann.
    widget.onGameOver?.call(hasAliveUnits);
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
    if (_selectedToken is! ObjectApprentice) return;
    // Nur im Spieler-Zug darf das Kontextmenü geöffnet werden
    if (!_isPlayerTurn || _isGameOver) return;

    final cook = _selectedToken as ObjectApprentice;
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
            child: Text(
              action == CombatAction.melee ? 'Nahkampf' :
              action == CombatAction.ranged ? 'Fernkampf' :
              action == CombatAction.focusFire ? 'FocusFire' :
              action.name,
            ),
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
      } else if (value == CombatAction.focusFire.name) {
        _enterFocusFireTargetingMode();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matrix = widget.transformationController.value;
    final hexGrid = widget.hexGrid;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Aktuelle Constraints speichern (für Viewport-Berechnung)
        _lastConstraints = constraints;
        return _buildContent(matrix, hexGrid);
      },
    );
  }

  /// Baut den eigentlichen Inhalt des WidgetCaretakers.
  ///
  /// Wird vom [LayoutBuilder] in [build] aufgerufen, damit die
  /// Viewport-Größe über [_lastConstraints] verfügbar ist.
  Widget _buildContent(Matrix4 matrix, HexGrid hexGrid) {
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
      // clipBehavior: Clip.none – erlaubt, dass das Info-Panel (left: -232)
      // in die linke Gutter-Spalte ragt, die in ScreenMain für das Panel
      // reserviert wurde. Mit Clip.hardEdge würde das Panel abgeschnitten.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // SizedBox.expand() als nicht-positioniertes Child, das den Stack
          // auf die volle verfügbare Größe (Bildschirm) zwingt.
          // Dadurch positionieren sich Positioned(right: 8) etc. korrekt
          // am Bildschirmrand, nicht am Kartenrand.
          // (Bugfix: "Rundenzähler und Kartenrand sind schmaler als WidgetCaretaker")
          const SizedBox.expand(),
          // Tokens mit der gleichen Transformation wie die Karte zeichnen.
          // Positioned, damit es die Stack-Größe nicht beeinflusst.
          Positioned(
            left: 0,
            top: 0,
            child: Transform(
              transform: matrix,
              child: SizedBox(
                width: hexGrid.mapPixelWidth.toDouble(),
                height: hexGrid.mapPixelHeight.toDouble(),
                child: Stack(
                  children: [
                    ..._buildTokenWidgets(),
                    // DEBUG: Karten-Bounding-Box visualisieren, um zu prüfen,
                    // ob die Map im WidgetMapLoader die gleiche Größe hat
                    // wie die Token-Ebene im WidgetCaretaker.
                    // Entfernen für Release-Builds.
                    ..._buildDebugOverlay(),
                  ],
                ),
              ),
            ),
          ),
          // Info-Panel für den ausgewählten Token (nicht transformiert,
          // damit es immer lesbar im Bildschirm bleibt).
          //
          // WICHTIG: Der WidgetCaretaker ist in ScreenMain um 240px nach
          // rechts gepaddet (Gutter-Spalte für das Info-Panel). Daher wird
          // das Panel mit `left: -232` (8 - 240) positioniert, damit es in
          // der Gutter-Spalte (Screen-x: 8..228) erscheint – NICHT über
          // der Karte (die bei x=240 beginnt).
          if (_selectedToken != null)
            Positioned(
              left: -232, // -240 (Gutter) + 8 (Randabstand)
              top: 8,
              child: SizedBox(
                width: 220,
                child: _buildInfoPanelContent(),
              ),
            ),
          // Runden- und Status-Anzeige (oben rechts)
          // Explizite Breite, damit SizedBox(width: double.infinity) nicht
          // zu BoxConstraints(w=Infinity) führt (Bugfix: App crasht)
          Positioned(
            right: 8,
            top: 8,
            child: SizedBox(
              width: 220,
              child: _buildStatusPanel(),
            ),
          ),
        ],
      ),
    );
  }

  /// DEBUG: Zeichnet ein rotes Rechteck um die Karten-Bounding-Box
  /// sowie grüne Punkte an den Hex-Zentren der Kartenecken.
  /// Damit kann visuell überprüft werden, ob das Token-Overlay und die
  /// Karte im WidgetMapLoader das identische Koordinatensystem verwenden.
  ///
  /// Entfernen für Release-Builds.
  List<Widget> _buildDebugOverlay() {
    final hexGrid = widget.hexGrid;
    final mapPixelWidth = hexGrid.mapPixelWidth.toDouble();
    final mapPixelHeight = hexGrid.mapPixelHeight.toDouble();

    return [
      // Rote Bounding-Box der Karte
      Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Container(
            width: mapPixelWidth,
            height: mapPixelHeight,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
        ),
      ),
      // Grüne Punkte an den Hex-Zentren der Kartenecken
      // (0,0), (mapWidth-1, 0), (0, mapHeight-1), (mapWidth-1, mapHeight-1)
      ..._buildDebugHexCenter(x: 0, y: 0),
      ..._buildDebugHexCenter(
        x: hexGrid.mapWidth - 1, y: 0,
      ),
      ..._buildDebugHexCenter(
        x: 0, y: hexGrid.mapHeight - 1,
      ),
      ..._buildDebugHexCenter(
        x: hexGrid.mapWidth - 1,
        y: hexGrid.mapHeight - 1,
      ),
    ];
  }

  /// DEBUG: Zeichnet einen grünen Punkt am Zentrum eines Hex-Feldes (x, y).
  List<Widget> _buildDebugHexCenter({required int x, required int y}) {
    final pixel = widget.hexGrid.hexToPixel(x: x, y: y);
    return [
      Positioned(
        left: pixel.dx - 3,
        top: pixel.dy - 3,
        child: IgnorePointer(
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      Positioned(
        left: pixel.dx + 6,
        top: pixel.dy - 5,
        child: IgnorePointer(
          child: Text(
            '($x,$y)',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0x88000000),
            ),
          ),
        ),
      ),
    ];
  }

  /// Baut das Status-Panel mit Runden-, Initiativ- und Spielstandsanzeige.
  /// Verwendet ein ins Spiel-Design integriertes Layout mit abgerundeten
  /// Ecken, dezenten Farben und sinnvollen Abständen.
  Widget _buildStatusPanel() {
    final Color accentColor;
    final Color panelColor;
    final Color textColor;
    final String statusText;
    final IconData statusIcon;

    if (_isGameOver) {
      accentColor = Colors.orange;
      panelColor = Colors.orange.shade50;
      textColor = Colors.orange.shade900;
      statusText = 'Spiel beendet';
      statusIcon = Icons.flag;
    } else if (_isPlayerTurn) {
      accentColor = Colors.green;
      panelColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      statusText = 'Spieler am Zug';
      statusIcon = Icons.person;
    } else {
      accentColor = Colors.red;
      panelColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      statusText = 'Host am Zug';
      statusIcon = Icons.computer;
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1),
      ),
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Überschrift-Zeile: Runde + Status-Icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 18, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  'Runde $_currentRound',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Status-Badge (wessen Zug)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            // Initiativnachricht
            if (_initiativeMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _initiativeMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            // Spielstand (Trennlinie)
            const SizedBox(height: 8),
            Container(height: 1, color: accentColor.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  '${_player.unitCount}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.dangerous, size: 14, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text(
                  '${_host.activeUnitCount}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            // "Zug beenden"-Button (nur im Spieler-Zug)
            if (_isPlayerTurn && !_isGameOver) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _endPlayerTurn,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('Zug beenden', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
            // Spielende-Nachricht + Zurück-Button
            if (_isGameOver) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _returnToRestaurant,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Zurück', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
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
        widget.hexGrid.mapPixelWidth.toDouble(),
        widget.hexGrid.mapPixelHeight.toDouble(),
      );
      return _cachedVisibleRect!;
    }

    // Die Viewport-Größe über die LayoutBuilder-Constraints ermitteln.
    // Wichtig: Der WidgetCaretaker kann sich innerhalb eines Paddings
    // befinden (z. B. 240px links für das Info-Panel) – die MediaQuery
    // würde sonst die volle Bildschirmbreite liefern und den Viewport
    // falsch berechnen. `context.size` ist während des Builds nicht
    // verfügbar, daher werden die Constraints im LayoutBuilder gespeichert.
    final constraints = _lastConstraints;
    final viewportWidth = constraints?.maxWidth ?? MediaQuery.of(context).size.width;
    final viewportHeight = constraints?.maxHeight ?? MediaQuery.of(context).size.height;

    // Die vier Ecken des Viewports in Karten-Koordinaten umrechnen
    final topLeft = MatrixUtils.transformPoint(inverseMatrix, Offset.zero);
    final topRight = MatrixUtils.transformPoint(
        inverseMatrix, Offset(viewportWidth, 0));
    final bottomLeft = MatrixUtils.transformPoint(
        inverseMatrix, Offset(0, viewportHeight));
    final bottomRight = MatrixUtils.transformPoint(
        inverseMatrix, Offset(viewportWidth, viewportHeight));

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
    final blocked = _getBlockedHexFields(excludeToken: _selectedToken);

    // BFS: Queue von (x, y, remainingSteps)
    visited.reset();
    final reachable = <int>{};
    visited.add(widget.hexGrid.hexKey(hex.x, hex.y));
    final queue = Queue<({int x, int y, int steps})>();
    queue.add((x: hex.x, y: hex.y, steps: maxMovement));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.steps <= 0) continue;

      for (final offset in widget.hexGrid.neighborOffsets(current.y)) {
        final nx = current.x + offset.dx;
        final ny = current.y + offset.dy;
        if (!widget.hexGrid.isInBounds(nx, ny)) continue;
        final key = widget.hexGrid.hexKey(nx, ny);
        if (visited.contains(key)) continue;
        visited.add(key);
        if (blocked.contains(key)) continue;
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

    final hexGrid = widget.hexGrid;
    final widgets = <Widget>[];
    for (final key in reachableFields) {
      final x = key % hexGrid.mapWidth;
      final y = key ~/ hexGrid.mapWidth;
      final pixel = hexGrid.hexToPixel(x: x, y: y);

      // Viewport-Culling
      if (!visibleRect.contains(pixel)) continue;

      widgets.add(
        Positioned(
          left: pixel.dx - hexGrid.tileWidth / 2,
          top: pixel.dy - hexGrid.tileHeight / 2,
          child: IgnorePointer(
            child: Container(
              width: hexGrid.tileWidth.toDouble(),
              height: hexGrid.tileHeight.toDouble(),
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

    final hexGrid = widget.hexGrid;
    final widgets = <Widget>[];
    for (final enemy in _targetableEnemies) {
      if (enemy.woundValue <= 0) continue;
      if (!visibleRect.contains(enemy.position)) continue;

      final hex = _getTokenHex(enemy);
      final pixel = hexGrid.hexToPixel(x: hex.x, y: hex.y);

      widgets.add(
        Positioned(
          left: pixel.dx - hexGrid.tileWidth / 2,
          top: pixel.dy - hexGrid.tileHeight / 2,
          child: IgnorePointer(
            child: Container(
              width: hexGrid.tileWidth.toDouble(),
              height: hexGrid.tileHeight.toDouble(),
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
    final hexGrid = widget.hexGrid;
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

      // Fog of War: Gegner auf nicht sichtbaren Feldern als Ghost zeichnen
      final fog = widget.fogOfWarService;
      if (fog != null && !renderInfo.isPlayerUnit) {
        final hex = hexGrid.pixelToHex(token.position);
        final key = hexGrid.hexKey(hex.x, hex.y);
        if (!fog.isVisible(key)) {
          if (fog.isRevealed(key)) {
            // Ghost-Darstellung: Aufgedecktes Feld, aber nicht sichtbar
            final ghostPos = _ghostTokenPositions[token];
            if (ghostPos != null && visibleRect.contains(ghostPos)) {
              widgets.add(
                Positioned(
                  left: ghostPos.dx - (hexGrid.tileWidth * 0.7 / 2),
                  top: ghostPos.dy - (hexGrid.tileHeight * 0.7 / 2),
                  child: Opacity(
                    opacity: 0.4,
                    child: _TokenWidget(
                      token: token,
                      isSelected: false,
                      isDragging: false,
                      tileWidth: hexGrid.tileWidth,
                      tileHeight: hexGrid.tileHeight,
                    ),
                  ),
                ),
              );
            }
          }
          continue; // Nicht sichtbar → nicht normal zeichnen
        }
      }

      Offset displayPosition = token.position;
      if (_isDragging && _draggedToken == token) {
        displayPosition += _dragOffset;
        // Während des Drags die Position auf die Karten-Bounds clampen,
        // damit der Token nicht sichtbar außerhalb der Karte landen kann.
        // (Bugfix: "Tokens können die Karte verlassen")
        displayPosition = Offset(
          displayPosition.dx.clamp(0, hexGrid.mapPixelWidth.toDouble()),
          displayPosition.dy.clamp(0, hexGrid.mapPixelHeight.toDouble()),
        );
      }

      // Viewport-Culling: Nur Tokens im sichtbaren Bereich zeichnen
      if (!visibleRect.contains(displayPosition)) {
        continue;
      }

      final tokenSize = (hexGrid.tileWidth * 0.7).clamp(20.0, 48.0);
      final halfTokenSize = tokenSize / 2;

      widgets.add(
        Positioned(
          left: displayPosition.dx - halfTokenSize,
          top: displayPosition.dy - halfTokenSize,
          child: _TokenWidget(
            token: token,
            isSelected: _selectedToken == token,
            isDragging: _isDragging && _draggedToken == token,
            tileWidth: hexGrid.tileWidth,
            tileHeight: hexGrid.tileHeight,
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

    // FocusFire-Button ist immer verfügbar (solange noch nicht gehandelt),
    // da er alle Einheiten gleichzeitig angreifen lässt
    buttons.add(const SizedBox(height: 4));
    buttons.add(
      ElevatedButton.icon(
        onPressed: (_isPlayerTurn && !_isGameOver && !token.hasActed)
            ? () => _enterFocusFireTargetingMode()
            : null,
        icon: const Icon(Icons.group_work, size: 16),
        label: const Text('FocusFire'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );

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
    final hasCharacterImage = token.characterImagePath != null &&
        token.characterImagePath!.isNotEmpty;

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
            // Charakterbild (falls vorhanden) als Overlay im Token
            if (hasCharacterImage)
              Positioned.fill(
                child: ClipOval(
                  child: Image.asset(
                    token.characterImagePath!,
                    width: tokenSize * 0.6,
                    height: tokenSize * 0.6,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
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