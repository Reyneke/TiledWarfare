import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/object_dough_dumpster.dart';
import 'package:tiled_warfare/objects/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/object_line_cook.dart';
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

  const WidgetCaretaker({
    super.key,
    required this.tileWidth,
    required this.tileHeight,
    required this.mapWidth,
    required this.mapHeight,
    required this.transformationController,
  });


  @override
  State<WidgetCaretaker> createState() => _WidgetCaretakerState();
}

class _WidgetCaretakerState extends State<WidgetCaretaker> {
  /// Der Spieler (Singleton).
  final ObjectPlayer _player = ObjectPlayer();

  /// Der Host (Gegner-Steuerung).
  final ObjectHost _host = ObjectHost();

  /// Der aktuell ausgewählte Token (für Info-Anzeige und Aktionen).
  ObjectToken? _selectedToken;

  /// Gibt an, ob gerade ein Drag-Vorgang läuft.
  bool _isDragging = false;

  /// Die Offset-Verschiebung während eines Drags.
  Offset _dragOffset = Offset.zero;

  /// Der Token, der gerade gezogen wird.
  ObjectToken? _draggedToken;

  /// Die Hex-Position (x, y), an der der Drag-Vorgang begonnen hat.
  /// Wird verwendet, um die Bewegung auf [ObjectToken.movementValue] zu begrenzen.
  ({int x, int y})? _dragStartHex;

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

  /// Wird bei jeder Änderung der Karten-Transformation aufgerufen.
  void _onTransformationChanged() {
    // setState, um die Token-Positionen neu zu zeichnen
    setState(() {});
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
  void _initializeGameObjects() {
    // Spieler-Einheiten spawnen und auf der Karte positionieren
    for (int i = 0; i < 3; i++) {
      final cook = _player.spawnLineCook();
      // Startpositionen: linke Seite der Karte
      cook.position = _hexToPixel(
        x: 2,
        y: 5 + i * 4,
      );
    }

    // Gegnerische Dough Dumpster platzieren
    final dumpster = ObjectDoughDumpster();
    dumpster.position = _hexToPixel(x: 25, y: 5);
    _host.doughDumpsterList.add(dumpster);

    // Start-Zombies vom Dumpster spawnen lassen
    final zombies = dumpster.spawnZombies();
    for (int i = 0; i < zombies.length; i++) {
      zombies[i].position = _hexToPixel(
        x: 22,
        y: 3 + i * 3,
      );
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

  /// Führt den Zug des Hosts aus.
  ///
  /// Der Host bewegt alle Zombies auf die Line Cooks zu und führt
  /// Angriffe aus, wenn Zombies in Reichweite sind.
  void _executeHostTurn() {
    if (_isGameOver) return;

    // Prüfen, ob der Host überhaupt noch Einheiten hat
    if (_host.isDefeated) {
      _isGameOver = true;
      _statusMessage = 'Spieler hat gewonnen! Alle Gegner besiegt.';
      setState(() {});
      return;
    }

    // Prüfen, ob der Spieler noch Einheiten hat
    if (_player.lineCookList.isEmpty) {
      _isGameOver = true;
      _statusMessage = 'Host hat gewonnen! Alle Spieler-Einheiten besiegt.';
      setState(() {});
      return;
    }

    // 1. Zombies bewegen
    _host.moveAllZombiesTowardsLineCooks(_player.lineCookList);

    // 2. Zombies angreifen lassen
    _host.performAllZombieAttacks(_player);

    // 3. Tote Einheiten entfernen
    _removeDeadTokens();

    // 4. Prüfen, ob der Spieler noch Einheiten hat
    if (_player.lineCookList.isEmpty) {
      _isGameOver = true;
      _statusMessage = 'Host hat gewonnen! Alle Spieler-Einheiten besiegt.';
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

  /// Rechnet Hex-Gitter-Koordinaten (x, y) in Pixel-Koordinaten um.
  ///
  /// Verwendet die gleiche Logik wie [_HexMapPainter] in [WidgetMapLoader]:
  /// - staggeraxis="y", staggerindex="odd"
  /// - Ungerade Zeilen sind um tileWidth/2 nach rechts versetzt.
  Offset _hexToPixel({required int x, required int y}) {
    final double pixelX;
    final double pixelY;

    if (y % 2 == 1) {
      pixelX = (x * widget.tileWidth).toDouble() + widget.tileWidth / 2;
    } else {
      pixelX = (x * widget.tileWidth).toDouble();
    }
    pixelY = y * (widget.tileHeight * 3.0 / 4.0);

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

  /// Gibt die Hex-Gitter-Koordinaten (x, y) für einen Token zurück,
  /// basierend auf seiner aktuellen Pixel-Position.
  ({int x, int y}) _getTokenHex(ObjectToken token) {
    return _pixelToHex(token.position);
  }

  /// Erstellt eine eindeutige Kennung für ein Hex-Feld (x, y).
  /// Wird verwendet, um belegte Felder in einem Set zu verwalten.
  int _hexKey(int x, int y) => y * widget.mapWidth + x;

  /// Baut eine Menge aller aktuell belegten Hex-Felder auf.
  /// Ein Feld gilt als belegt, wenn dort ein lebender Token steht.
  /// Der [excludeToken] wird dabei nicht berücksichtigt (z. B. der
  /// gerade gezogene Token).
  Set<int> _getOccupiedHexFields({ObjectToken? excludeToken}) {
    final occupied = <int>{};

    for (final renderInfo in _allTokens) {
      final token = renderInfo.token;
      if (token.woundValue <= 0) continue;
      if (token == excludeToken) continue;

      final hex = _getTokenHex(token);
      occupied.add(_hexKey(hex.x, hex.y));
    }

    return occupied;
  }

  /// Prüft, ob ein bestimmtes Hex-Feld (x, y) frei ist (kein lebender Token
  /// darauf steht). Der [excludeToken] wird ignoriert.
  bool _isHexFieldFree(int x, int y, {ObjectToken? excludeToken}) {
    final occupied = _getOccupiedHexFields(excludeToken: excludeToken);
    return !occupied.contains(_hexKey(x, y));
  }

  /// Findet das nächstgelegene freie Hex-Feld zu einer Pixel-Position.
  /// Durchsucht die Umgebung spiralförmig, beginnend beim nächstgelegenen
  /// Hex-Feld, und gibt die Pixel-Position des ersten freien Feldes zurück.
  /// Falls alle Felder belegt sind, wird die ursprüngliche Pixel-Position
  /// zurückgegeben.
  Offset _snapToNearestFreeHex(Offset pixel, {ObjectToken? excludeToken}) {
    final approxHex = _pixelToHex(pixel);

    // Prüfen, ob das angenäherte Feld bereits frei ist
    if (_isHexFieldFree(approxHex.x, approxHex.y, excludeToken: excludeToken)) {
      return _hexToPixel(x: approxHex.x, y: approxHex.y);
    }

    // Spiralförmige Suche im Umkreis von bis zu 10 Feldern
    const maxRadius = 10;
    for (int radius = 1; radius <= maxRadius; radius++) {
      // Obere und untere Kante
      for (int dx = -radius; dx <= radius; dx++) {
        // Obere Kante: y = approxHex.y - radius
        final yTop = approxHex.y - radius;
        if (yTop >= 0 && yTop < widget.mapHeight) {
          final xTop = approxHex.x + dx;
          if (xTop >= 0 && xTop < widget.mapWidth) {
            if (_isHexFieldFree(xTop, yTop, excludeToken: excludeToken)) {
              return _hexToPixel(x: xTop, y: yTop);
            }
          }
        }

        // Untere Kante: y = approxHex.y + radius
        final yBottom = approxHex.y + radius;
        if (yBottom >= 0 && yBottom < widget.mapHeight) {
          final xBottom = approxHex.x + dx;
          if (xBottom >= 0 && xBottom < widget.mapWidth) {
            if (_isHexFieldFree(xBottom, yBottom, excludeToken: excludeToken)) {
              return _hexToPixel(x: xBottom, y: yBottom);
            }
          }
        }
      }

      // Linke und rechte Kante (ohne Ecken, die schon oben/unten abgedeckt sind)
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        // Linke Kante: x = approxHex.x - radius
        final xLeft = approxHex.x - radius;
        if (xLeft >= 0) {
          final yLeft = approxHex.y + dy;
          if (yLeft >= 0 && yLeft < widget.mapHeight) {
            if (_isHexFieldFree(xLeft, yLeft, excludeToken: excludeToken)) {
              return _hexToPixel(x: xLeft, y: yLeft);
            }
          }
        }

        // Rechte Kante: x = approxHex.x + radius
        final xRight = approxHex.x + radius;
        if (xRight < widget.mapWidth) {
          final yRight = approxHex.y + dy;
          if (yRight >= 0 && yRight < widget.mapHeight) {
            if (_isHexFieldFree(xRight, yRight, excludeToken: excludeToken)) {
              return _hexToPixel(x: xRight, y: yRight);
            }
          }
        }
      }
    }

    // Kein freies Feld gefunden – ursprüngliche Pixel-Position zurückgeben
    return _hexToPixel(x: approxHex.x, y: approxHex.y);
  }

  /// Gibt alle Tokens zurück, die auf der Karte angezeigt werden sollen.
  List<_TokenRenderInfo> get _allTokens {
    final tokens = <_TokenRenderInfo>[];

    // Spieler-Einheiten
    for (final cook in _player.lineCookList) {
      tokens.add(_TokenRenderInfo(
        token: cook,
        isPlayerUnit: true,
      ));
    }

    // Gegnerische Dough Dumpster
    for (final dumpster in _host.doughDumpsterList) {
      tokens.add(_TokenRenderInfo(
        token: dumpster,
        isPlayerUnit: false,
      ));
    }

    // Zombies aus allen Dumpstern
    for (final dumpster in _host.doughDumpsterList) {
      for (final zombie in dumpster.zombieList) {
        tokens.add(_TokenRenderInfo(
          token: zombie,
          isPlayerUnit: false,
        ));
      }
    }

    return tokens;
  }

  /// Behandelt einen Tap auf die Karte – wählt den Token unter dem Tap aus
  /// oder deselektiert, wenn auf leeren Bereich getippt wird.
  void _handleTap(Offset tapPosition) {
    // Nur im Spieler-Zug darf ausgewählt werden
    if (!_isPlayerTurn || _isGameOver) return;

    setState(() {
      // Prüfen, ob ein Token angetippt wurde
      ObjectToken? tappedToken;
      for (final renderInfo in _allTokens) {
        final token = renderInfo.token;
        final tokenRect = Rect.fromCenter(
          center: token.position,
          width: widget.tileWidth.toDouble(),
          height: widget.tileHeight.toDouble(),
        );
        if (tokenRect.contains(tapPosition)) {
          tappedToken = token;
          break;
        }
      }

      if (tappedToken != null) {
        // Token auswählen
        _selectedToken = tappedToken;
      } else {
        // Nichts getroffen – Deselektieren
        _selectedToken = null;
      }
    });
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

  /// Berechnet die Hex-Gitter-Entfernung zwischen zwei Hex-Koordinaten
  /// auf einem Pointy-Top-Hex-Gitter mit staggeraxis="y", staggerindex="odd".
  ///
  /// Verwendet die Umrechnung in Cube-Koordinaten für eine korrekte
  /// Hex-Distanzberechnung.
  int _hexDistance({required int x1, required int y1, required int x2, required int y2}) {
    // Offset-zu-Cube-Konvertierung für odd-r (staggerindex="odd")
    int cubeX1 = x1 - (y1 - (y1 & 1)) ~/ 2;
    int cubeZ1 = y1;
    int cubeY1 = -cubeX1 - cubeZ1;

    int cubeX2 = x2 - (y2 - (y2 & 1)) ~/ 2;
    int cubeZ2 = y2;
    int cubeY2 = -cubeX2 - cubeZ2;

    // Hex-Distanz = max(|dx|, |dy|, |dz|)
    return [
      (cubeX1 - cubeX2).abs(),
      (cubeY1 - cubeY2).abs(),
      (cubeZ1 - cubeZ2).abs(),
    ].reduce((a, b) => a > b ? a : b);
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
        final distance = _hexDistance(
          x1: _dragStartHex!.x,
          y1: _dragStartHex!.y,
          x2: targetHex.x,
          y2: targetHex.y,
        );

        if (distance > _draggedToken!.movementValue) {
          // Bewegung überschreitet den erlaubten Wert – zurücksetzen
          _showMessage(
            'Bewegung zu weit! Maximal ${_draggedToken!.movementValue} Felder erlaubt.',
          );
          _isDragging = false;
          _draggedToken = null;
          _dragOffset = Offset.zero;
          _dragStartHex = null;
          return;
        }
      }

      _draggedToken!.position = snappedPosition;
      _isDragging = false;
      _draggedToken = null;
      _dragOffset = Offset.zero;
      _dragStartHex = null;
    });
  }

  /// Führt eine Kampfaktion des ausgewählten Tokens gegen einen Gegner aus.
  void _performAction(CombatAction action) {
    if (_selectedToken == null) return;
    if (_selectedToken is! ObjectLineCook) return;
    // Nur im Spieler-Zug darf gekämpft werden
    if (!_isPlayerTurn || _isGameOver) return;

    final attacker = _selectedToken as ObjectLineCook;

    // Nächstgelegenen Gegner finden
    ObjectToken? nearestEnemy;
    double nearestDistance = double.infinity;

    for (final renderInfo in _allTokens) {
      if (renderInfo.isPlayerUnit) continue;
      final enemy = renderInfo.token;
      if (enemy.woundValue <= 0) continue;

      final distance = (enemy.position - attacker.position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestEnemy = enemy;
      }
    }

    if (nearestEnemy == null) return;

    // Entfernung in Hex-Feldern schätzen
    final distanceInHex = (nearestDistance / widget.tileWidth).round();
    if (distanceInHex < 1) return;

    // Prüfen, ob die Aktion in dieser Entfernung möglich ist
    if (action == CombatAction.melee && distanceInHex > 1) {
      _showMessage('Nahkampf ist nur auf benachbarte Felder möglich!');
      return;
    }
    if (action == CombatAction.ranged && distanceInHex > attacker.rangeValue) {
      _showMessage('Ziel ist außerhalb der Reichweite!');
      return;
    }

    // Kampfaktion ausführen
    final result = _player.performAction(
      action: action,
      attacker: attacker,
      defender: nearestEnemy,
      distance: distanceInHex,
    );

    // Ergebnis anzeigen
    String message = 'Angriff auf ${nearestEnemy.name}: ';
    if (result.hit) {
      message += 'Treffer! ${result.damage} Schaden verursacht.';
    } else {
      message += 'Verfehlt!';
    }
    if (result.attackerCritical) message += ' (Kritischer Treffer!)';
    if (result.attackerFumbled) message += ' (Patzer – selbst Schaden erlitten!)';
    if (result.defenderCritical) message += ' (Gegner hat kritisch pariert!)';
    if (result.defenderFumbled) message += ' (Gegner hat einen Patzer erlitten!)';
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

    // Nach dem Angriff: Host-Zug ausführen (der Host reagiert auf den Angriff)
    _endPlayerTurn();
  }

  /// Entfernt alle Tokens mit woundValue <= 0.
  void _removeDeadTokens() {
    // Tote Spieler-Einheiten entfernen
    _player.lineCookList.removeWhere((cook) => cook.woundValue <= 0);

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
  }

  /// Zeigt eine SnackBar-Nachricht an.
  void _showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
        _performAction(CombatAction.melee);
      } else if (value == CombatAction.ranged.name) {
        _performAction(CombatAction.ranged);
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
              'Line Cooks: ${_player.lineCookCount}',
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
  Rect _getVisibleMapRect() {
    final matrix = widget.transformationController.value;
    final inverseMatrix = Matrix4.tryInvert(matrix);
    if (inverseMatrix == null) {
      // Falls die Matrix nicht invertiert werden kann, den gesamten Kartenbereich zurückgeben
      return Rect.fromLTWH(
        0,
        0,
        widget.mapWidth * widget.tileWidth + widget.tileWidth / 2,
        (widget.mapHeight * widget.tileHeight * 3 / 4) + widget.tileHeight / 4,
      );
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
      topLeft.dx,
      topRight.dx,
      bottomLeft.dx,
      bottomRight.dx
    ].reduce((a, b) => a < b ? a : b);
    final minY = [
      topLeft.dy,
      topRight.dy,
      bottomLeft.dy,
      bottomRight.dy
    ].reduce((a, b) => a < b ? a : b);
    final maxX = [
      topLeft.dx,
      topRight.dx,
      bottomLeft.dx,
      bottomRight.dx
    ].reduce((a, b) => a > b ? a : b);
    final maxY = [
      topLeft.dy,
      topRight.dy,
      bottomLeft.dy,
      bottomRight.dy
    ].reduce((a, b) => a > b ? a : b);

    // Einen großzügigen Rand hinzufügen, damit Tokens nicht zu früh
    // ein-/ausblenden (ca. 2 Tile-Breiten als Puffer)
    const margin = 200.0;
    return Rect.fromLTRB(
      minX - margin,
      minY - margin,
      maxX + margin,
      maxY + margin,
    );
  }

  /// Baut die Widgets für alle Tokens auf der Karte.
  /// Tokens außerhalb des sichtbaren Viewports werden übersprungen (Culling).
  List<Widget> _buildTokenWidgets() {
    final widgets = <Widget>[];

    // Sichtbaren Bereich in Karten-Koordinaten ermitteln
    final visibleRect = _getVisibleMapRect();

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

      widgets.add(
        Positioned(
          left: displayPosition.dx,
          top: displayPosition.dy,
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
    final isPlayerUnit = _player.lineCookList.contains(token);

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
            if (isPlayerUnit) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: (_isPlayerTurn && !_isGameOver)
                    ? () => _performAction(CombatAction.melee)
                    : null,
                icon: const Icon(Icons.local_fire_department, size: 16),
                label: const Text('Nahkampf'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
              if (token is ObjectLineCook && token.rangeValue > 0)
                const SizedBox(height: 4),
              if (token.rangeValue > 0)
                ElevatedButton.icon(
                  onPressed: (_isPlayerTurn && !_isGameOver)
                      ? () => _performAction(CombatAction.ranged)
                      : null,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Fernkampf'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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
      child: Container(
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
        child: Center(
          child: Text(
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