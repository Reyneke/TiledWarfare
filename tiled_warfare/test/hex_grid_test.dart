import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

void main() {
  group('HexGrid - Pixel ↔ Hex-Konvertierung', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    });

    test('hexToPixel and pixelToHex are inverses', () {
      for (int y = 0; y < grid.mapHeight; y++) {
        for (int x = 0; x < grid.mapWidth; x++) {
          final pixel = grid.hexToPixel(x: x, y: y);
          final hex = grid.pixelToHex(pixel);
          expect(hex.x, x, reason: 'x-Mismatch at ($x, $y)');
          expect(hex.y, y, reason: 'y-Mismatch at ($x, $y)');
        }
      }
    });

    test('hexToPixel: even rows start at x * tileWidth', () {
      final pixel = grid.hexToPixel(x: 3, y: 0);
      expect(pixel.dx, 3 * 32);
      expect(pixel.dy, 0);
    });

    test('hexToPixel: odd rows are offset by tileWidth/2', () {
      final pixel = grid.hexToPixel(x: 3, y: 1);
      expect(pixel.dx, 3 * 32 + 16);
      expect(pixel.dy, 1 * 24); // 32 * 3/4
    });

    test('hexToPixel: y-step is 3/4 of tileHeight', () {
      final p0 = grid.hexToPixel(x: 0, y: 0);
      final p1 = grid.hexToPixel(x: 0, y: 1);
      expect(p1.dy - p0.dy, 24);
      final p2 = grid.hexToPixel(x: 0, y: 2);
      expect(p2.dy - p1.dy, 24);
    });

    test('pixelToHex clamps to map bounds', () {
      // Negativ = out of bounds
      final out = grid.pixelToHex(const Offset(-100, -100));
      expect(out.x, 0);
      expect(out.y, 0);

      // Zu groß = out of bounds
      final big = grid.pixelToHex(Offset(1000, 1000));
      expect(big.x, grid.mapWidth - 1);
      expect(big.y, grid.mapHeight - 1);
    });
  });

  group('HexGrid - hexKey', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    });

    test('hexKey is unique within map bounds', () {
      final keys = <int>{};
      for (int y = 0; y < grid.mapHeight; y++) {
        for (int x = 0; x < grid.mapWidth; x++) {
          final key = grid.hexKey(x, y);
          expect(keys.add(key), true, reason: 'Duplicate key at ($x, $y) = $key');
        }
      }
      expect(keys.length, 100);
    });

    test('hexKey uses y * mapWidth + x', () {
      expect(grid.hexKey(5, 3), 3 * 10 + 5);
      expect(grid.hexKey(0, 0), 0);
      expect(grid.hexKey(9, 9), 99);
    });
  });

  group('HexGrid - isInBounds', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    });

    test('isInBounds returns true for valid coordinates', () {
      expect(grid.isInBounds(0, 0), true);
      expect(grid.isInBounds(9, 9), true);
      expect(grid.isInBounds(5, 5), true);
    });

    test('isInBounds returns false for invalid coordinates', () {
      expect(grid.isInBounds(-1, 0), false);
      expect(grid.isInBounds(0, -1), false);
      expect(grid.isInBounds(10, 0), false);
      expect(grid.isInBounds(0, 10), false);
    });
  });

  group('HexGrid - distance (Cube-Koordinaten)', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 20, mapHeight: 20);
    });

    test('distance to itself is 0', () {
      expect(grid.distance(x1: 5, y1: 5, x2: 5, y2: 5), 0);
    });

    test('direct neighbors have distance 1', () {
      // Nachbar-Offsets für gerade y (5 ist ungerade, wir testen beide Fälle)
      for (final offset in grid.neighborOffsets(5)) {
        expect(grid.distance(x1: 5, y1: 5, x2: 5 + offset.dx, y2: 5 + offset.dy), 1,
            reason: 'Neighbor offset ($offset.dx, ${offset.dy}) should be distance 1');
      }
    });

    test('distance uses cube coordinates (not Manhattan)', () {
      // Auf einem Hex-Gitter ist die Entfernung von (0,0) nach (3,3)
      // NICHT |3| + |3| = 6, sondern die Cube-Distanz (hier 5).
      final hexDist = grid.distance(x1: 0, y1: 0, x2: 3, y2: 3);
      final manhattan = (3 - 0).abs() + (3 - 0).abs();
      expect(hexDist, lessThan(manhattan),
          reason: 'Hex distance should be less than Manhattan distance');
      expect(hexDist, 5); // Korrekte Cube-Distanz
    });

    test('distance is symmetric', () {
      final a = grid.distance(x1: 2, y1: 3, x2: 7, y2: 8);
      final b = grid.distance(x1: 7, y1: 8, x2: 2, y2: 3);
      expect(a, b);
    });
  });

  group('HexGrid - findPath (A*)', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    });

    test('target == start returns single hex', () {
      final path = grid.findPath(
        startX: 3, startY: 3,
        targetX: 3, targetY: 3,
        blocked: {},
      );
      expect(path, [grid.hexKey(3, 3)]);
    });

    test('direct neighbors have path length 2', () {
      final path = grid.findPath(
        startX: 5, startY: 5,
        targetX: 6, targetY: 5,
        blocked: {},
      );
      expect(path.length, 2);
      expect(path.first, grid.hexKey(5, 5));
      expect(path.last, grid.hexKey(6, 5));
    });

    test('finds path around a wall', () {
      final blocked = {grid.hexKey(5, 6)};
      final path = grid.findPath(
        startX: 5, startY: 5,
        targetX: 5, targetY: 7,
        blocked: blocked,
      );
      expect(path, isNotEmpty);
      expect(path.first, grid.hexKey(5, 5));
      expect(path.last, grid.hexKey(5, 7));
      for (final key in path) {
        expect(blocked.contains(key), false);
      }
    });

    test('returns empty list if target is blocked', () {
      final blocked = {grid.hexKey(5, 7)};
      final path = grid.findPath(
        startX: 5, startY: 5,
        targetX: 5, targetY: 7,
        blocked: blocked,
      );
      expect(path, isEmpty);
    });

    test('returns empty list if no path exists (fully enclosed)', () {
      final targetX = 5, targetY = 5;
      final blocked = <int>{};
      for (final off in grid.neighborOffsets(targetY)) {
        blocked.add(grid.hexKey(targetX + off.dx, targetY + off.dy));
      }
      final path = grid.findPath(
        startX: 0, startY: 0,
        targetX: targetX, targetY: targetY,
        blocked: blocked,
      );
      expect(path, isEmpty);
    });

    test('hexFromKey is inverse of hexKey', () {
      for (int y = 0; y < grid.mapHeight; y++) {
        for (int x = 0; x < grid.mapWidth; x++) {
          final key = grid.hexKey(x, y);
          final hex = grid.hexFromKey(key);
          expect(hex.x, x);
          expect(hex.y, y);
        }
      }
    });
  });

  group('HexGrid - neighborOffsets', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    });

    test('returns 6 neighbors for even rows', () {
      final offsets = grid.neighborOffsets(0);
      expect(offsets.length, 6);
    });

    test('returns 6 neighbors for odd rows', () {
      final offsets = grid.neighborOffsets(1);
      expect(offsets.length, 6);
    });

    test('even and odd rows have different offsets', () {
      final even = grid.neighborOffsets(0);
      final odd = grid.neighborOffsets(1);
      expect(even, isNot(equals(odd)));
    });
  });

  group('HexGrid - findFreeHexNear', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    });

    test('returns start position if not occupied', () {
      final result = grid.findFreeHexNear(startX: 5, startY: 5, occupied: {});
      expect(result, grid.hexToPixel(x: 5, y: 5));
    });

    test('finds a free neighbor when start is occupied', () {
      final busy = <int>{grid.hexKey(5, 5)};
      final result = grid.findFreeHexNear(startX: 5, startY: 5, occupied: busy);
      final hex = grid.pixelToHex(result);
      expect(hex.x != 5 || hex.y != 5, true);
      expect(grid.isInBounds(hex.x, hex.y), true);
      expect(busy.contains(grid.hexKey(hex.x, hex.y)), false);
    });

    test('falls back to start position after exhaustive search', () {
      // Alle Felder in der Nähe belegen
      final all = <int>{};
      for (int y = 0; y < grid.mapHeight; y++) {
        for (int x = 0; x < grid.mapWidth; x++) {
          all.add(grid.hexKey(x, y));
        }
      }
      final result = grid.findFreeHexNear(startX: 5, startY: 5, occupied: all);
      expect(result, grid.hexToPixel(x: 5, y: 5));
    });
  });

  group('HexGrid - buildOccupiedHexes', () {
    late HexGrid grid;

    setUp(() {
      grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    });

    ObjectToken makeToken(int x, int y, {int wound = 3}) {
      final token = ObjectToken(name: 'T', imagePath: 'test.png', woundValue: wound);
      token.position = grid.hexToPixel(x: x, y: y);
      return token;
    }

    test('builds set of occupied hex fields', () {
      final tokens = [makeToken(2, 3), makeToken(5, 5)];
      final occupied = grid.buildOccupiedHexes(
        tokens,
        (t) => t.position,
        include: (t) => t.woundValue > 0,
      );
      expect(occupied, {grid.hexKey(2, 3), grid.hexKey(5, 5)});
    });

    test('skips dead tokens (woundValue <= 0)', () {
      final tokens = [makeToken(2, 3, wound: 0), makeToken(5, 5)];
      final occupied = grid.buildOccupiedHexes(
        tokens,
        (t) => t.position,
        include: (t) => t.woundValue > 0,
      );
      expect(occupied, {grid.hexKey(5, 5)});
    });

    test('excludeToken is not included', () {
      final exclude = makeToken(2, 3);
      final tokens = [exclude, makeToken(5, 5)];
      final occupied = grid.buildOccupiedHexes(
        tokens,
        (t) => t.position,
        include: (t) => t.woundValue > 0 && t != exclude,
      );
      expect(occupied, {grid.hexKey(5, 5)});
    });

    test('all items are included when include is null', () {
      final positions = [
        grid.hexToPixel(x: 1, y: 1),
        grid.hexToPixel(x: 4, y: 4),
      ];
      final items = [positions[0], positions[1]];
      final occupied = grid.buildOccupiedHexes(items, (pos) => pos);
      expect(occupied, {grid.hexKey(1, 1), grid.hexKey(4, 4)});
    });
  });

  group('HexGrid - mapPixelDimensions', () {
    test('mapPixelWidth includes half-tile for odd rows', () {
      final grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
      expect(grid.mapPixelWidth, 10 * 32 + 16);
    });

    test('mapPixelHeight formula is correct', () {
      final grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
      expect(grid.mapPixelHeight, (10 * 32 * 3 ~/ 4) + 32 ~/ 4);
    });
  });
}