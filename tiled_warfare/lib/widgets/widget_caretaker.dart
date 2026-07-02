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

  @override
  void initState() {
    super.initState();
    _initializeGameObjects();
    // Auf Änderungen der Transformation (Zoom/Scroll) lauschen,
    // um die Token-Positionen zu aktualisieren
    widget.transformationController.addListener(_onTransformationChanged);
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
  void _handleDragEnd() {
    if (!_isDragging || _draggedToken == null) return;
    setState(() {
      _draggedToken!.position += _dragOffset;
      _isDragging = false;
      _draggedToken = null;
      _dragOffset = Offset.zero;
    });
  }

  /// Führt eine Kampfaktion des ausgewählten Tokens gegen einen Gegner aus.
  void _performAction(CombatAction action) {
    if (_selectedToken == null) return;
    if (_selectedToken is! ObjectLineCook) return;

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

    setState(() {});
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

        ],
      ),





    );
  }



  /// Baut die Widgets für alle Tokens auf der Karte.
  List<Widget> _buildTokenWidgets() {
    final widgets = <Widget>[];

    for (final renderInfo in _allTokens) {
      final token = renderInfo.token;
      if (token.woundValue <= 0) continue;

      Offset displayPosition = token.position;
      if (_isDragging && _draggedToken == token) {
        displayPosition += _dragOffset;
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
                onPressed: () => _performAction(CombatAction.melee),
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
                  onPressed: () => _performAction(CombatAction.ranged),
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
