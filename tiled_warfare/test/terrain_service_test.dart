import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/services/terrain_service.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

void main() {
  late HexGrid grid;
  late Map<int, TerrainType> emptyTerrain;

  setUp(() {
    grid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    emptyTerrain = {};
  });

  group('TerrainService - configAt', () {
    test('returns normal config for empty terrain map', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      final config = service.configAt(5, 5);
      expect(config.movementCostMultiplier, 1.0);
      expect(config.blocksVision, false);
      expect(config.impassable, false);
    });

    test('returns correct config for specific terrain type', () {
      final terrainMap = <int, TerrainType>{
        grid.hexKey(5, 5): TerrainType.ruin,
        grid.hexKey(3, 3): TerrainType.water,
      };
      final service = TerrainService(
        terrainMap: terrainMap,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );

      final ruin = service.configAt(5, 5);
      expect(ruin.movementCostMultiplier, 2.0);
      expect(ruin.blocksVision, true);

      final water = service.configAt(3, 3);
      expect(water.impassable, true);
    });
  });

  group('TerrainService - isPassable', () {
    test('normal terrain is passable', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      expect(service.isPassable(5, 5), true);
    });

    test('collision tiles are not passable', () {
      final blocked = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {grid.hexKey(5, 5)},
        hexGrid: grid,
      );
      expect(blocked.isPassable(5, 5), false);
    });

    test('occupied tiles are not passable', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      expect(service.isPassable(5, 5, occupied: {grid.hexKey(5, 5)}), false);
    });

    test('impassable terrain is not passable', () {
      final water = TerrainService(
        terrainMap: {grid.hexKey(5, 5): TerrainType.water},
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      expect(water.isPassable(5, 5), false);
    });
  });

  group('TerrainService - reachableHexes', () {
    test('empty terrain: reachable = maxMovement range', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      final reachable = service.reachableHexes(
        startX: 5,
        startY: 5,
        maxMovement: 2,
      );
      expect(reachable.length, greaterThan(6));
    });

    test('zero movement returns empty set', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      final reachable = service.reachableHexes(
        startX: 5,
        startY: 5,
        maxMovement: 0,
      );
      expect(reachable, isEmpty);
    });

    test('ruin terrain (2x cost) blocks movement with 1 MP', () {
      final terrainMap = <int, TerrainType>{
        grid.hexKey(5, 6): TerrainType.ruin,
      };
      final service = TerrainService(
        terrainMap: terrainMap,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      final reachable = service.reachableHexes(
        startX: 5,
        startY: 5,
        maxMovement: 1,
      );
      expect(reachable.contains(grid.hexKey(5, 6)), false);
      expect(reachable.length, 5);
    });

    test('impassable terrain blocks movement', () {
      final terrainMap = <int, TerrainType>{
        grid.hexKey(5, 6): TerrainType.water,
      };
      final service = TerrainService(
        terrainMap: terrainMap,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      final reachable = service.reachableHexes(
        startX: 5,
        startY: 5,
        maxMovement: 3,
      );
      expect(reachable.contains(grid.hexKey(5, 6)), false);
    });

    test('occupied fields block movement', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      final occupied = {grid.hexKey(5, 6)};
      final reachable = service.reachableHexes(
        startX: 5,
        startY: 5,
        maxMovement: 3,
        occupied: occupied,
      );
      expect(reachable.contains(grid.hexKey(5, 6)), false);
    });

    test('collision tiles block movement', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {grid.hexKey(5, 6)},
        hexGrid: grid,
      );
      final reachable = service.reachableHexes(
        startX: 5,
        startY: 5,
        maxMovement: 3,
      );
      expect(reachable.contains(grid.hexKey(5, 6)), false);
    });
  });

  group('TerrainService - effectiveMovementRange', () {
    test('returns count of reachable hexes', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      final range = service.effectiveMovementRange(
        startX: 5,
        startY: 5,
        maxMovement: 2,
      );
      expect(range, greaterThan(6));
    });

    test('zero movement returns 0', () {
      final service = TerrainService(
        terrainMap: emptyTerrain,
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: grid,
      );
      expect(
        service.effectiveMovementRange(
          startX: 5,
          startY: 5,
          maxMovement: 0,
        ),
        0,
      );
    });
  });

  group('TerrainService - parseTerrain', () {
    test('returns empty map for null terrain group', () {
      final result = parseTerrain(null, grid);
      expect(result, isEmpty);
    });

    test('parses terrain rectangles from object group', () {
      final group = ObjectGroup(
        name: 'Gelaendetypen',
        objects: [
          MapObject(
            id: 1,
            name: '',
            type: 'ruin',
            x: 0,
            y: 0,
            width: 64,
            height: 64,
          ),
          MapObject(
            id: 2,
            name: '',
            type: 'forest',
            x: 200,
            y: 200,
            width: 64,
            height: 64,
          ),
        ],
      );
      final result = parseTerrain(group, grid);
      expect(result.length, 2);
      expect(result[grid.hexKey(1, 1)], TerrainType.ruin);
      expect(result.values, contains(TerrainType.forest));
    });

    test('unknown terrain type maps to normal', () {
      final group = ObjectGroup(
        name: 'Gelaendetypen',
        objects: [
          MapObject(
            id: 1,
            name: '',
            type: 'unknown_type',
            x: 0,
            y: 0,
            width: 64,
            height: 64,
          ),
        ],
      );
      final result = parseTerrain(group, grid);
      expect(result[grid.hexKey(1, 1)], TerrainType.normal);
    });
  });
}