import 'dart:ui' show Offset;

/// Zentrale Utility-Klasse für alle Hex-Gitter-Berechnungen.
///
/// Verwendet ein odd-r-Schema (staggeraxis="y", staggerindex="odd"):
/// - Pointy-topped Hexagons
/// - Ungerade Zeilen (y % 2 == 1) sind um tileWidth/2 nach rechts versetzt
///
/// Alle Methoden nutzen die bei der Konstruktion übergebenen Karten-Parameter
/// ([tileWidth], [tileHeight], [mapWidth], [mapHeight]), sodass keine
/// zusätzlichen Parameter pro Aufruf nötig sind.
///
/// ## Verwendung
/// ```dart
/// final hexGrid = HexGrid(
///   tileWidth: 32,
///   tileHeight: 32,
///   mapWidth: 30,
///   mapHeight: 30,
/// );
///
/// final pixel = hexGrid.hexToPixel(x: 5, y: 3);
/// final hex = hexGrid.pixelToHex(Offset(100, 80));
/// final key = hexGrid.hexKey(5, 3);
/// final dist = hexGrid.distance(x1: 0, y1: 0, x2: 5, y2: 3);
/// ```
class HexGrid {
  /// Die Pixel-Breite eines einzelnen Karten-Tiles.
  final int tileWidth;

  /// Die Pixel-Höhe eines einzelnen Karten-Tiles.
  final int tileHeight;

  /// Die Anzahl der Spalten der Karte.
  final int mapWidth;

  /// Die Anzahl der Zeilen der Karte.
  final int mapHeight;

  const HexGrid({
    required this.tileWidth,
    required this.tileHeight,
    required this.mapWidth,
    required this.mapHeight,
  });

  // ──────────────────────────────────────────────
  // Pixel ↔ Hex-Konvertierung
  // ──────────────────────────────────────────────

  /// Rechnet Hex-Gitter-Koordinaten (x, y) in Pixel-Koordinaten um.
  ///
  /// - staggeraxis="y", staggerindex="odd"
  /// - Ungerade Zeilen sind um tileWidth/2 nach rechts versetzt.
  Offset hexToPixel({required int x, required int y}) {
    final double pixelX;
    if (y % 2 == 1) {
      pixelX = (x * tileWidth).toDouble() + tileWidth / 2;
    } else {
      pixelX = (x * tileWidth).toDouble();
    }
    final pixelY = y * (tileHeight * 3.0 / 4.0);
    return Offset(pixelX, pixelY);
  }

  /// Rechnet Pixel-Koordinaten in die nächstgelegenen Hex-Gitter-Koordinaten
  /// (x, y) um. Dies ist die Umkehrung von [hexToPixel].
  ///
  /// - staggeraxis="y", staggerindex="odd"
  /// - Das Ergebnis wird auf [mapWidth] und [mapHeight] begrenzt (clamped).
  ({int x, int y}) pixelToHex(Offset pixel) {
    final approxY = (pixel.dy / (tileHeight * 3.0 / 4.0)).round();
    final y = approxY.clamp(0, mapHeight - 1);

    int x;
    if (y % 2 == 1) {
      x = ((pixel.dx - tileWidth / 2) / tileWidth).round();
    } else {
      x = (pixel.dx / tileWidth).round();
    }

    x = x.clamp(0, mapWidth - 1);
    return (x: x, y: y);
  }

  // ──────────────────────────────────────────────
  // Hex-Identifikation
  // ──────────────────────────────────────────────

  /// Erstellt eine eindeutige Kennung für ein Hex-Feld (x, y).
  int hexKey(int x, int y) => y * mapWidth + x;

  /// Prüft, ob die Hex-Koordinaten (x, y) innerhalb der Karten-Grenzen liegen.
  bool isInBounds(int x, int y) =>
      x >= 0 && x < mapWidth && y >= 0 && y < mapHeight;

  // ──────────────────────────────────────────────
  // Distanzberechnung
  // ──────────────────────────────────────────────

  /// Konvertiert Offset-Koordinaten (odd-r) in Cube-Koordinaten.
  static ({int x, int y, int z}) offsetToCube(int x, int y) {
    final cubeX = x - (y & ~1) ~/ 2;
    final cubeZ = y;
    final cubeY = -cubeX - cubeZ;
    return (x: cubeX, y: cubeY, z: cubeZ);
  }

  /// Berechnet die Hex-Gitter-Entfernung zwischen zwei Hex-Koordinaten
  /// (korrekte Cube-Distanz, nicht Manhattan!).
  int distance({
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

  // ──────────────────────────────────────────────
  // Nachbar-Offsets
  // ──────────────────────────────────────────────

  /// Nachbar-Offsets für gerade y-Zeilen (y % 2 == 0).
  static const List<({int dx, int dy})> _evenOffsets = [
    (dx: -1, dy: -1),
    (dx: 0, dy: -1),
    (dx: -1, dy: 0),
    (dx: 1, dy: 0),
    (dx: -1, dy: 1),
    (dx: 0, dy: 1),
  ];

  /// Nachbar-Offsets für ungerade y-Zeilen (y % 2 == 1).
  static const List<({int dx, int dy})> _oddOffsets = [
    (dx: 0, dy: -1),
    (dx: 1, dy: -1),
    (dx: -1, dy: 0),
    (dx: 1, dy: 0),
    (dx: 0, dy: 1),
    (dx: 1, dy: 1),
  ];

  /// Gibt die Nachbar-Offsets für odd-r Hex-Gitter zurück.
  List<({int dx, int dy})> neighborOffsets(int y) {
    return y % 2 == 0 ? _evenOffsets : _oddOffsets;
  }

  // ──────────────────────────────────────────────
  // Pfadfindung / Freie Felder
  // ──────────────────────────────────────────────

  /// Findet einen Pfad von (startX, startY) nach (targetX, targetY)
  /// mittels A*-Suche.
  ///
  /// Berücksichtigt:
  /// - [blocked]: Menge unpassierbarer Hex-Keys (Kollisionstiles + Token)
  /// - [movementCost]: Optionale Funktion, die pro Ziel-Hex die Bewegungskosten
  ///   (>= 1.0) zurückgibt. Wenn `null`, werden einheitliche Kosten von 1.0
  ///   angenommen (klassisches BFS-Verhalten).
  ///
  /// Gibt eine Liste von Hex-Keys zurück, die den Pfad inklusive Start- und
  /// Ziel-Hex beschreibt. Wenn kein Pfad existiert, wird eine leere Liste
  /// zurückgegeben.
  List<int> findPath({
    required int startX,
    required int startY,
    required int targetX,
    required int targetY,
    required Set<int> blocked,
    double Function(int x, int y)? movementCost,
    int maxIterations = 10000,
  }) {
    final startKey = hexKey(startX, startY);
    final goalKey = hexKey(targetX, targetY);

    if (startKey == goalKey) return [startKey];
    if (blocked.contains(goalKey)) return [];

    final openSet = <int>{startKey};
    final cameFrom = <int, int>{};
    final gScore = <int, double>{startKey: 0};
    final fScore = <int, double>{
      startKey: _heuristic(startX, startY, targetX, targetY).toDouble(),
    };

    var iterations = 0;
    while (openSet.isNotEmpty) {
      if (++iterations > maxIterations) return [];

      int? current;
      double? bestF;
      for (final key in openSet) {
        final s = fScore[key] ?? double.infinity;
        if (bestF == null || s < bestF) {
          bestF = s;
          current = key;
        }
      }
      if (current == null) return [];

      if (current == goalKey) {
        return _reconstructPath(cameFrom, startKey, goalKey);
      }

      openSet.remove(current);
      final currentHex = hexFromKey(current);

      for (final offset in neighborOffsets(currentHex.y)) {
        final nx = currentHex.x + offset.dx;
        final ny = currentHex.y + offset.dy;
        if (!isInBounds(nx, ny)) continue;

        final nKey = hexKey(nx, ny);
        if (blocked.contains(nKey)) continue;

        final cost = movementCost?.call(nx, ny) ?? 1.0;
        if (cost < 1.0) continue;

        final tentativeG = (gScore[current] ?? double.infinity) + cost;
        if (tentativeG < (gScore[nKey] ?? double.infinity)) {
          cameFrom[nKey] = current;
          gScore[nKey] = tentativeG;
          final h = _heuristic(nx, ny, targetX, targetY).toDouble();
          fScore[nKey] = tentativeG + h;
          openSet.add(nKey);
        }
      }
    }
    return [];
  }

  /// Rekonstruiert den Pfad von [startKey] nach [goalKey].
  List<int> _reconstructPath(
    Map<int, int> cameFrom,
    int startKey,
    int goalKey,
  ) {
    final path = <int>[goalKey];
    var current = goalKey;
    while (current != startKey) {
      final prev = cameFrom[current];
      if (prev == null) return [];
      path.insert(0, prev);
      current = prev;
    }
    return path;
  }

  /// Heuristik für A*: Cube-Distanz zwischen zwei Hex-Feldern.
  int _heuristic(int x1, int y1, int x2, int y2) {
    return distance(x1: x1, y1: y1, x2: x2, y2: y2);
  }

  /// Rechnet einen Hex-Key zurück in (x, y)-Koordinaten.
  ({int x, int y}) hexFromKey(int key) {
    final x = key % mapWidth;
    final y = key ~/ mapWidth;
    return (x: x, y: y);
  }

  /// Findet ein freies Hex-Feld in der Nähe eines Ausgangs-Hex (spiralförmig).
  Offset findFreeHexNear({
    required int startX,
    required int startY,
    required Set<int> occupied,
    int maxRadius = 12,
  }) {
    if (!occupied.contains(hexKey(startX, startY))) {
      return hexToPixel(x: startX, y: startY);
    }

    for (int radius = 1; radius <= maxRadius; radius++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final x = startX + dx;
        final y = startY - radius;
        if (isInBounds(x, y) && !occupied.contains(hexKey(x, y))) {
          return hexToPixel(x: x, y: y);
        }
      }
      for (int dx = -radius; dx <= radius; dx++) {
        final x = startX + dx;
        final y = startY + radius;
        if (isInBounds(x, y) && !occupied.contains(hexKey(x, y))) {
          return hexToPixel(x: x, y: y);
        }
      }
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        final x = startX - radius;
        final y = startY + dy;
        if (isInBounds(x, y) && !occupied.contains(hexKey(x, y))) {
          return hexToPixel(x: x, y: y);
        }
      }
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        final x = startX + radius;
        final y = startY + dy;
        if (isInBounds(x, y) && !occupied.contains(hexKey(x, y))) {
          return hexToPixel(x: x, y: y);
        }
      }
    }

    return hexToPixel(x: startX, y: startY);
  }

  /// Baut eine Menge aller aktuell belegten Hex-Felder aus einer beliebigen
  /// Liste von Objekten auf.
  ///
  /// [items] – Die zu prüfenden Objekte.
  /// [getPosition] – Liefert die Pixel-Position eines Objekts.
  /// [include] – Optionaler Filter: Nur Objekte, für die `true` zurückgegeben
  ///   wird, belegen ein Feld. Wenn `null`, werden alle Objekte berücksichtigt.
  Set<int> buildOccupiedHexes<T>(
    Iterable<T> items,
    Offset Function(T) getPosition, {
    bool Function(T)? include,
  }) {
    final occupied = <int>{};
    for (final item in items) {
      if (include != null && !include(item)) continue;
      final hex = pixelToHex(getPosition(item));
      occupied.add(hexKey(hex.x, hex.y));
    }
    return occupied;
  }

  // ──────────────────────────────────────────────
  // Karten-Dimensionen
  // ──────────────────────────────────────────────

  /// Die Pixel-Breite der gesamten Karte.
  int get mapPixelWidth => mapWidth * tileWidth + tileWidth ~/ 2;

  /// Die Pixel-Höhe der gesamten Karte.
  int get mapPixelHeight => (mapHeight * tileHeight * 3 ~/ 4) + tileHeight ~/ 4;
}