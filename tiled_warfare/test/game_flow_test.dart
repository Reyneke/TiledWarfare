import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/objects/boss_monsters/object_dough_dumpster.dart';
import 'package:tiled_warfare/objects/monsters/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/services/map_parser.dart';
import 'package:tiled_warfare/services/terrain_service.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';
import 'package:tiled_warfare/widgets/widget_map_loader.dart';

/// Integrationstest: Kompletter Spielfluss von der Karte bis zur KI-Bewegung.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Integration - Karte laden und verarbeiten (map0)', () {
    late MapData mapData;
    late HexGrid hexGrid;

    setUpAll(() async {
      // Reale Karte aus dem Asset-Bundle laden
      final parser = TmxParser(assetBundle: rootBundle);
      mapData = await parser.loadFromAsset('assets/maps/map0/street_battle.tmx');
      hexGrid = HexGrid(
        tileWidth: mapData.tileWidth,
        tileHeight: mapData.tileHeight,
        mapWidth: mapData.width,
        mapHeight: mapData.height,
      );
    });

    test('Karte wird geladen und hat ground-Layer', () {
      expect(mapData.width, 30);
      expect(mapData.height, 30);
      expect(mapData.tileWidth, 32);
      expect(mapData.orientation, MapOrientation.hexagonal);

      final ground = mapData.layerByPurpose(LayerPurpose.ground);
      expect(ground, isNotNull);
      expect(ground!.name, 'ground');
    });

    test('Spawn-Punkte existieren in map0', () {
      final spawns =
          mapData.objectGroups.where((g) => g.name == 'Spawns').toList();
      expect(spawns, isNotEmpty);
      expect(spawns.first.objects, isNotEmpty);
    });

    test('findTileset ermittelt korrektes Tileset', () {
      expect(findTileset(0, mapData.tilesets), isNull);
      expect(findTileset(1, mapData.tilesets), isNotNull);
      expect(findTileset(121, mapData.tilesets), isNotNull);
    });

    test('Kollisions-Layer wird korrekt berechnet', () {
      final collisionSet = mapData.computeCollisionTiles(hexGrid);
      expect(collisionSet, isA<Set<int>>());
    });
  });

  group('Integration - TerrainService mit geladener Karte', () {
    late HexGrid hexGrid;
    late TerrainService terrain;

    setUp(() {
      hexGrid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 30, mapHeight: 30);
      terrain = TerrainService(
        terrainMap: {},
        configs: TerrainConfig.defaults,
        collisionSet: {},
        hexGrid: hexGrid,
      );
    });

    test('Bewegung auf normalem Terrain', () {
      final reachable = terrain.reachableHexes(
        startX: 15,
        startY: 15,
        maxMovement: 3,
      );
      expect(reachable.length, greaterThan(20));
    });

    test('Kollisions-Tiles blockieren Bewegung', () {
      final blocked = TerrainService(
        terrainMap: {},
        configs: TerrainConfig.defaults,
        collisionSet: {hexGrid.hexKey(15, 16)},
        hexGrid: hexGrid,
      );
      final reachable = blocked.reachableHexes(
        startX: 15,
        startY: 15,
        maxMovement: 3,
      );
      expect(reachable.contains(hexGrid.hexKey(15, 16)), false);
    });
  });

  group('Integration - ObjectHost Zombie-Bewegung (A*)', () {
    late HexGrid hexGrid;
    late ObjectHost host;

    setUpAll(() {
      // ObjectHost ist ein Singleton mit late final hexGrid
      hexGrid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
      host = ObjectHost();
      try {
        host.hexGrid = hexGrid; // Nur einmal setzbar
      } catch (_) {
        // Bereits von einem anderen Test gesetzt – verwende das vorhandene Grid
      }
      host.collisionSet = {};
      host.doughDumpsterList.clear();
    });

    test('Zombie bewegt sich zum nächsten Ziel ohne Hindernisse', () {
      // Zombie bei (5,5), Ziel bei (7,5)
      final zombie = ObjectDoughZombie();
      zombie.position = hexGrid.hexToPixel(x: 5, y: 5);
      zombie.targetPosition = null;

      final target = ObjectLineCook();
      target.position = hexGrid.hexToPixel(x: 7, y: 5);

      final dumpster = ObjectDoughDumpster();
      dumpster.zombieList.add(zombie);
      host.doughDumpsterList.add(dumpster);

      host.moveAllZombiesTowardsTargets([target]);

      // Zombie bewegt sich (targetPosition gesetzt)
      expect(zombie.targetPosition, isNotNull);

      // Neue Position ist näher am Ziel als die alte
      final oldDist = hexGrid.distance(
        x1: 5, y1: 5, x2: 7, y2: 5,
      );
      final newHex = hexGrid.pixelToHex(zombie.targetPosition!);
      final newDist = hexGrid.distance(
        x1: newHex.x, y1: newHex.y, x2: 7, y2: 5,
      );
      expect(newDist, lessThan(oldDist));
    });

    test('Zombie umgeht eine Mauer mit A*', () {
      // Zombie bei (5,5), Ziel bei (5,7), Mauer bei (5,6)
      final zombie = ObjectDoughZombie();
      zombie.position = hexGrid.hexToPixel(x: 5, y: 5);
      zombie.targetPosition = null;

      final target = ObjectLineCook();
      target.position = hexGrid.hexToPixel(x: 5, y: 7);

      host.collisionSet = {hexGrid.hexKey(5, 6)};

      final dumpster = ObjectDoughDumpster();
      dumpster.zombieList.add(zombie);
      host.doughDumpsterList.add(dumpster);

      host.moveAllZombiesTowardsTargets([target]);

      expect(zombie.targetPosition, isNotNull);
      final newHex = hexGrid.pixelToHex(zombie.targetPosition!);
      expect(newHex.x != 5 || newHex.y != 6, true);
      final dist = hexGrid.distance(
        x1: newHex.x,
        y1: newHex.y,
        x2: 5,
        y2: 7,
      );
      expect(dist, lessThan(2));
    });
  });
}