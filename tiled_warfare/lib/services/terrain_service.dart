import 'dart:ui' show Offset;

import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

/// Parst die "Gelaendetypen"-Objektgruppe.
///
/// Erwartet Rechteck-Objekte (x, y, width, height) pro Geländebereich.
/// Der Mittelpunkt jedes Rechtecks wird in Hex-Koordinaten umgerechnet
/// und als Geländetyp in der Map gespeichert.
///
/// [terrainGroup] – Die Objektgruppe mit dem Namen "Gelaendetypen".
///                  Kann `null` sein (→ leere Map).
/// [hexGrid] – Hex-Utility für die Pixel→Hex-Konvertierung.
///
/// Gibt eine Map von hexKey → [TerrainType] zurück.
Map<int, TerrainType> parseTerrain(ObjectGroup? terrainGroup, HexGrid hexGrid) {
  final result = <int, TerrainType>{};
  if (terrainGroup == null) return result;

  for (final obj in terrainGroup.objects) {
    final type = TerrainType.fromString(obj.type);
    // Rechteck-Mittelpunkt in Hex-Koordinaten umrechnen
    final centerX = obj.x + obj.width / 2;
    final centerY = obj.y + obj.height / 2;
    final hex = hexGrid.pixelToHex(Offset(centerX, centerY));
    result[hexGrid.hexKey(hex.x, hex.y)] = type;
  }
  return result;
}

/// Baut eine Menge aller blockierten Felder aus Kollisions-Tiles und
/// Token-Positionen auf.
///
/// Kombiniert die Kollisions-Tiles aus [mapData] mit den durch Tokens
/// belegten Hex-Feldern. Der [excludeToken] wird nicht als blockiert
/// gewertet (z. B. der gerade gezogene Token).
Set<int> buildAllBlockedFields({
  required MapData mapData,
  required String collisionLayerName,
  required Iterable<ObjectToken> tokens,
  ObjectToken? excludeToken,
  required HexGrid hexGrid,
}) {
  final blocked = hexGrid.buildOccupiedHexFields(tokens, excludeToken: excludeToken);
  blocked.addAll(mapData.computeCollisionTiles(hexGrid));
  return blocked;
}

/// Zentraler Service für alle Gelände-bezogenen Abfragen.
///
/// - Verwaltet die Terrain-Map (hexKey → TerrainType)
/// - Stellt Bewegungskosten-Berechnung bereit
/// - Führt LoS-Prüfungen durch
/// - Trackt Kollisions-Felder
///
/// ## Verwendung
/// ```dart
/// final terrain = TerrainService(
///   terrainMap: terrainMap,
///   configs: TerrainConfig.defaults,
///   collisionSet: collisionSet,
///   hexGrid: hexGrid,
/// );
///
/// if (terrain.isPassable(5, 5)) { /* bewegen erlaubt */ }
/// final range = terrain.effectiveMovementRange(token, 5, 5);
/// ```
class TerrainService {
  /// Terrain-Lookup-Map (hexKey → TerrainType).
  final Map<int, TerrainType> _terrainMap;

  /// Konfiguration pro TerrainType.
  final Map<TerrainType, TerrainConfig> _configs;

  /// Menge der Kollisions-Tiles (hexKey).
  final Set<int> _collisionSet;

  /// Hex-Utility für alle Gitter-Berechnungen.
  final HexGrid _hexGrid;

  const TerrainService({
    required Map<int, TerrainType> terrainMap,
    required Map<TerrainType, TerrainConfig> configs,
    required Set<int> collisionSet,
    required HexGrid hexGrid,
  })  : _terrainMap = terrainMap,
        _configs = configs,
        _collisionSet = collisionSet,
        _hexGrid = hexGrid;

  // ──────────────────────────────────────────────
  // Geländekonfiguration abfragen
  // ──────────────────────────────────────────────

  /// Gibt die [TerrainConfig] für das Hex-Feld (x, y) zurück.
  TerrainConfig configAt(int x, int y) {
    final type = _terrainMap[_hexGrid.hexKey(x, y)] ?? TerrainType.normal;
    return _configs[type] ?? TerrainConfig.defaults[type]!;
  }

  // ──────────────────────────────────────────────
  // Passierbarkeit
  // ──────────────────────────────────────────────

  /// Prüft, ob das Hex-Feld (x, y) passierbar ist.
  ///
  /// Ein Feld ist passierbar, wenn:
  /// 1. Es nicht durch einen Token belegt ist ([occupied])
  /// 2. Es nicht im Kollisions-Set ist
  /// 3. Das Gelände nicht `impassable` ist
  bool isPassable(int x, int y, {Set<int>? occupied}) {
    if (occupied?.contains(_hexGrid.hexKey(x, y)) ?? false) return false;
    if (_collisionSet.contains(_hexGrid.hexKey(x, y))) return false;
    return !configAt(x, y).impassable;
  }

  // ──────────────────────────────────────────────
  // Bewegungskosten-BFS (Section 3.3)
  // ──────────────────────────────────────────────

  /// Berechnet die maximale Reichweite eines Tokens in Hex-Feldern
  /// unter Berücksichtigung der Geländekosten.
  ///
  /// Delegiert an [reachableHexes] und zählt die Anzahl.
  /// [startX], [startY] – Startposition des Tokens.
  /// [maxMovement] – Maximale Bewegungspunkte ([ObjectToken.movementValue]).
  /// [occupied] – Optional: Menge blockierter Felder (Token + Kollision).
  ///
  /// Gibt die **Anzahl der erreichbaren Hex-Felder** zurück (exkl. Startfeld).
  int effectiveMovementRange({
    required int startX,
    required int startY,
    required int maxMovement,
    Set<int>? occupied,
  }) {
    return reachableHexes(
      startX: startX,
      startY: startY,
      maxMovement: maxMovement,
      occupied: occupied,
    ).length;
  }

  /// Berechnet die Menge aller erreichbaren Hex-Felder (exkl. Startfeld).
  ///
  /// [startX], [startY] – Startposition des Tokens.
  /// [maxMovement] – Maximale Bewegungspunkte.
  /// [occupied] – Optional: Menge blockierter Felder (Token + Kollision).
  ///
  /// Gibt die Menge der Hex-Keys aller erreichbaren Felder zurück.
  Set<int> reachableHexes({
    required int startX,
    required int startY,
    required int maxMovement,
    Set<int>? occupied,
  }) {
    if (maxMovement <= 0) return {};

    final startKey = _hexGrid.hexKey(startX, startY);
    final reachable = <int>{};
    final queue = <(int x, int y, double cost)>[];
    final visited = <int>{startKey};
    queue.add((startX, startY, 0.0));

    while (queue.isNotEmpty) {
      final (currentX, currentY, currentCost) = queue.removeAt(0);

      for (final offset in _hexGrid.neighborOffsets(currentY)) {
        final nx = currentX + offset.dx;
        final ny = currentY + offset.dy;
        final nKey = _hexGrid.hexKey(nx, ny);

        if (!_hexGrid.isInBounds(nx, ny)) continue;
        if (visited.contains(nKey)) continue;

        final config = configAt(nx, ny);
        if (config.impassable) continue;
        if (_collisionSet.contains(nKey)) continue;
        if (occupied?.contains(nKey) ?? false) continue;

        final newCost = currentCost + config.movementCostMultiplier;
        if (newCost > maxMovement) continue;

        visited.add(nKey);
        reachable.add(nKey);
        queue.add((nx, ny, newCost));
      }
    }

    return reachable;
  }
}