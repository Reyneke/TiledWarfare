import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

/// Zentraler Service für Fog of War (Nebel des Krieges).
///
/// Verwaltet zwei Sichtbarkeitsebenen:
///
/// 1. **visibleHexes** – Hex-Felder, die in der aktuellen Runde von
///    mindestens einer freundlichen Einheit eingesehen werden können.
///    Wird zu Beginn jeder Runde neu berechnet.
///
/// 2. **revealedHexes** – Hex-Felder, die jemals von einer freundlichen
///    Einheit gesehen wurden ("aufgedeckt"). Bleibt über Runden hinweg
///    bestehen und wird nie kleiner.
///
/// ## Verwendung
/// ```dart
/// final fog = FogOfWarService(hexGrid: hexGrid);
/// fog.computeVisibility(
///   friendlyTokens: player.unitList,
///   terrainMap: terrainMap,
///   terrainConfigs: TerrainConfig.defaults,
/// );
///
/// if (fog.isVisible(hexKey)) { /* zeichne hell */ }
/// else if (fog.isRevealed(hexKey)) { /* zeichne dunkel */ }
/// else { /* zeichne schwarz */ }
/// ```
class FogOfWarService extends ChangeNotifier {
  /// Maximale Sichtweite in Hex-Feldern, um die BFS-Erkundung zu begrenzen.
  ///
  /// Verhindert, dass ein sehr großer [ObjectToken.fieldOfView] die gesamte
  /// Karte erkundet und die Performance beeinträchtigt. Der Wert ist bewusst
  /// großzügig gewählt (größer als jede realistische Karten-Diagonale),
  /// sodass er im Normalfall nie erreicht wird.
  static const int maxFieldOfView = 50;

  /// Hex-Utility für alle Gitter-Berechnungen.
  final HexGrid hexGrid;

  /// Aktuell sichtbare Hex-Felder (wird pro Runde neu berechnet).
  final Set<int> _visibleHexes = {};

  /// Dauerhaft aufgedeckte Hex-Felder (kumulativ über Runden).
  final Set<int> _revealedHexes = {};

  /// Cache für LoS-Ergebnisse innerhalb einer Berechnung.
  /// Wird bei jedem [computeVisibility]-Aufruf zurückgesetzt.
  final Map<(int, int, int, int), bool> _losCache = {};

  /// Versionszähler, der bei jeder Sichtbarkeits-Berechnung erhöht wird.
  ///
  /// Wird vom Karten-Renderer verwendet, um zu erkennen, ob sich die
  /// Sichtbarkeit geändert hat und ein Neuzeichnen erforderlich ist.
  int _visibilityVersion = 0;

  /// Aktuelle Version der Sichtbarkeits-Berechnung.
  ///
  /// Erhöht sich bei jedem [computeVisibility]-Aufruf. Der Karten-Renderer
  /// kann diesen Wert in `shouldRepaint()` prüfen, um festzustellen, ob
  /// sich die Sichtbarkeit geändert hat.
  int get visibilityVersion => _visibilityVersion;

  FogOfWarService({
    required this.hexGrid,
  });

  // ──────────────────────────────────────────────
  // Öffentliche API
  // ──────────────────────────────────────────────

  /// Aktuell sichtbare Hex-Felder (unveränderliche Sicht).
  @visibleForTesting
  Set<int> get visibleHexes => Set.unmodifiable(_visibleHexes);

  /// Dauerhaft aufgedeckte Hex-Felder (unveränderliche Sicht).
  @visibleForTesting
  Set<int> get revealedHexes => Set.unmodifiable(_revealedHexes);

  /// Berechnet die Sichtbarkeit für die aktuelle Runde neu.
  ///
  /// [friendlyTokens] – Liste aller freundlichen (vom Spieler kontrollierten)
  /// Tokens. Nur lebende Tokens (woundValue > 0) tragen zur Sicht bei.
  ///
  /// [terrainMap] – Lookup-Map von hexKey → TerrainType.
  /// [terrainConfigs] – Konfiguration pro TerrainType (definiert, ob
  /// ein Gelände die Sicht blockiert).
  ///
  /// Nach dem Aufruf sind [visibleHexes] und [revealedHexes] aktualisiert.
  void computeVisibility({
    required Iterable<ObjectToken> friendlyTokens,
    required Map<int, TerrainType> terrainMap,
    required Map<TerrainType, TerrainConfig> terrainConfigs,
  }) {
    // Alte Sichtbarkeit zurücksetzen, LoS-Cache leeren
    _visibleHexes.clear();
    _losCache.clear();

    for (final token in friendlyTokens) {
      if (token.woundValue <= 0) continue;

      final hex = hexGrid.pixelToHex(token.position);

      _computeTokenVisibility(
        tokenHexX: hex.x,
        tokenHexY: hex.y,
        fieldOfView: token.fieldOfView.clamp(0, maxFieldOfView),
        terrainMap: terrainMap,
        terrainConfigs: terrainConfigs,
      );
    }

    // Aufgedeckte Felder aktualisieren: visibleHexes zu revealedHexes hinzufügen
    _revealedHexes.addAll(_visibleHexes);

    // Versionszähler erhöhen, damit der Renderer ein Neuzeichnen auslöst
    _visibilityVersion++;
    notifyListeners();
  }

  /// Setzt den gesamten Fog-of-War-Zustand zurück (z. B. beim Laden einer
  /// neuen Karte).
  void reset() {
    _visibleHexes.clear();
    _revealedHexes.clear();
    _losCache.clear();
    _visibilityVersion++;
    notifyListeners();
  }

  /// Gibt zurück, ob das Hex-Feld mit [hexKey] aktuell sichtbar ist.
  bool isVisible(int hexKey) => _visibleHexes.contains(hexKey);

  /// Gibt zurück, ob das Hex-Feld mit [hexKey] jemals aufgedeckt wurde.
  bool isRevealed(int hexKey) => _revealedHexes.contains(hexKey);

  /// Gibt alle gegnerischen Tokens zurück, die auf aktuell sichtbaren
  /// Feldern stehen.
  ///
  /// [enemyTokens] – Liste der gegnerischen Tokens.
  /// Ein Token gilt als sichtbar, wenn sein Hex-Feld in [visibleHexes] ist
  /// und der Token lebt (woundValue > 0).
  List<ObjectToken> getVisibleEnemies(Iterable<ObjectToken> enemyTokens) {
    final visible = <ObjectToken>[];
    for (final token in enemyTokens) {
      if (token.woundValue <= 0) continue;
      final hex = hexGrid.pixelToHex(token.position);
      if (_visibleHexes.contains(hexGrid.hexKey(hex.x, hex.y))) {
        visible.add(token);
      }
    }
    return visible;
  }

  /// Gibt alle gegnerischen Tokens zurück, die auf aufgedeckten (aber nicht
  /// unbedingt sichtbaren) Feldern stehen.
  ///
  /// [enemyTokens] – Liste der gegnerischen Tokens.
  /// Ein Token gilt als aufgedeckt, wenn sein Hex-Feld in [revealedHexes] ist
  /// und der Token lebt (woundValue > 0).
  ///
  /// Nützlich für die Ghost-Darstellung: Tokens auf aufgedeckten Feldern
  /// können als "letzte bekannte Position" angezeigt werden.
  List<ObjectToken> getRevealedEnemies(Iterable<ObjectToken> enemyTokens) {
    final revealed = <ObjectToken>[];
    for (final token in enemyTokens) {
      if (token.woundValue <= 0) continue;
      final hex = hexGrid.pixelToHex(token.position);
      if (_revealedHexes.contains(hexGrid.hexKey(hex.x, hex.y))) {
        revealed.add(token);
      }
    }
    return revealed;
  }

  // ──────────────────────────────────────────────
  // Interne Berechnung pro Token
  // ──────────────────────────────────────────────

  /// Berechnet die Sichtbarkeit für einen einzelnen Token mittels BFS.
  ///
  /// Der Algorithmus:
  /// 1. Das Start-Hex des Tokens ist immer sichtbar.
  /// 2. BFS erkundet benachbarte Hex-Felder bis zur [fieldOfView]-Distanz.
  /// 3. Für jedes Kandidaten-Hex wird `hasLineOfSight()` aufgerufen.
  /// 4. Nur wenn die Sichtlinie frei ist, wird das Hex als sichtbar markiert
  ///    und seine Nachbarn zur weiteren Erkundung vorgemerkt.
  /// 5. Blockiert ein Hex die Sicht (`blocksVision == true`), wird es selbst
  ///    noch als sichtbar markiert, aber seine Nachbarn werden nicht erkundet.
  void _computeTokenVisibility({
    required int tokenHexX,
    required int tokenHexY,
    required int fieldOfView,
    required Map<int, TerrainType> terrainMap,
    required Map<TerrainType, TerrainConfig> terrainConfigs,
  }) {
    final startKey = hexGrid.hexKey(tokenHexX, tokenHexY);

    // 1. Start-Hex ist immer sichtbar
    _visibleHexes.add(startKey);

    if (fieldOfView <= 0) return;

    // 2. BFS über die Nachbarschaft
    // Queue speichert (x, y, distance) – O(1) removeFirst() statt O(n) removeAt(0)
    final queue = Queue<(int x, int y, int distance)>();
    final visited = <int>{startKey};
    queue.add((tokenHexX, tokenHexY, 0));

    while (queue.isNotEmpty) {
      final (currentX, currentY, distance) = queue.removeFirst();
      final nextDistance = distance + 1;

      if (nextDistance > fieldOfView) continue;

      for (final offset in hexGrid.neighborOffsets(currentY)) {
        final nx = currentX + offset.dx;
        final ny = currentY + offset.dy;
        final nKey = hexGrid.hexKey(nx, ny);

        if (!hexGrid.isInBounds(nx, ny)) continue;
        if (visited.contains(nKey)) continue;
        visited.add(nKey);

        // 3. LoS-Prüfung vom Token zum Kandidaten-Hex
        final canSee = hasLineOfSight(
          x1: tokenHexX,
          y1: tokenHexY,
          x2: nx,
          y2: ny,
          terrainMap: terrainMap,
          terrainConfigs: terrainConfigs,
        );

        if (canSee) {
          _visibleHexes.add(nKey);

          // Prüfen, ob das Feld selbst die Sicht blockiert
          final terrainType = terrainMap[nKey] ?? TerrainType.normal;
          final config = terrainConfigs[terrainType] ??
              TerrainConfig.defaults[terrainType]!;

          // Nur wenn das Feld die Sicht nicht blockiert, propagieren wir weiter
          if (!config.blocksVision) {
            queue.add((nx, ny, nextDistance));
          }
          // Blockiert das Feld die Sicht, wird es selbst sichtbar,
          // aber dahinterliegende Felder nicht erkundet (natürliche Sichtbarriere).
        }
        // Keine Sichtlinie → Feld bleibt unsichtbar, keine weitere Propagation
      }
    }
  }

  // ──────────────────────────────────────────────
  // Line-of-Sight (Cube-Koordinaten-basierte DDA)
  // ──────────────────────────────────────────────

  /// Prüft, ob eine Sichtlinie zwischen zwei Hex-Feldern (x1,y1) und (x2,y2)
  /// existiert.
  ///
  /// Gibt `true` zurück, wenn alle Hex-Felder auf der Linie *keine*
  /// Sichtblockade haben (gemäß [terrainConfigs]).
  /// Gibt `false` zurück, wenn ein Feld mit `blocksVision == true` auf der
  /// Linie liegt.
  ///
  /// Verwendet Cube-Koordinaten-DDA (angepasster Bresenham für Hex-Gitter).
  /// Das Start-Feld (x1,y1) wird übersprungen — ein Token sieht immer
  /// durch sein eigenes Feld hindurch.
  ///
  /// Ergebnisse werden gecached, um wiederholte Prüfungen zwischen
  /// denselben Feldern zu beschleunigen.
  @visibleForTesting
  bool hasLineOfSight({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required Map<int, TerrainType> terrainMap,
    required Map<TerrainType, TerrainConfig> terrainConfigs,
  }) {
    final cacheKey = (x1, y1, x2, y2);
    final cached = _losCache[cacheKey];
    if (cached != null) return cached;

    // Symmetrie: LoS von A→B ist gleich LoS von B→A
    final reversedKey = (x2, y2, x1, y1);
    final reversedCached = _losCache[reversedKey];
    if (reversedCached != null) {
      _losCache[cacheKey] = reversedCached;
      return reversedCached;
    }

    final steps = hexGrid.distance(x1: x1, y1: y1, x2: x2, y2: y2);
    if (steps <= 1) {
      _losCache[cacheKey] = true;
      return true; // Direkte Nachbarn sind immer sichtbar
    }

    // Cube-Koordinaten für die Linie
    final cube1 = HexGrid.offsetToCube(x1, y1);
    final cube2 = HexGrid.offsetToCube(x2, y2);

    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final cubeX = cube1.x + (cube2.x - cube1.x) * t;
      final cubeZ = cube1.z + (cube2.z - cube1.z) * t;
      final cubeY = -cubeX - cubeZ;

      // Cube → Offset (abgerundet)
      final qx = cubeX.round();
      final qz = cubeZ.round();
      final qy = cubeY.round();

      // Validierung: muss auf dem Hex-Gitter liegen
      if (qx + qy + qz != 0) continue;

      // Cube → Offset-Koordinaten (odd-r)
      // offset_x = cube_x + (cube_z - (cube_z&1)) / 2
      final offsetX = qx + (qz & ~1) ~/ 2;
      final offsetY = qz;

      final hexKey = hexGrid.hexKey(offsetX, offsetY);
      final terrainType = terrainMap[hexKey] ?? TerrainType.normal;
      final config = terrainConfigs[terrainType] ??
          TerrainConfig.defaults[terrainType]!;

      if (config.blocksVision) {
        _losCache[cacheKey] = false;
        return false;
      }
    }

    _losCache[cacheKey] = true;
    return true;
  }
}