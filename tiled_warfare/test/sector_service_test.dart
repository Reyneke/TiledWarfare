import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/models/sector.dart';
import 'package:tiled_warfare/services/map_parser.dart';
import 'package:tiled_warfare/services/sector_service.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Sector - containsPixel', () {
    test('rectangle sector contains points inside', () {
      const sector = Sector(name: 'Zone', x: 0, y: 0, width: 100, height: 100);
      expect(sector.containsPixel(const Offset(50, 50)), true);
      expect(sector.containsPixel(const Offset(0, 0)), true);
      expect(sector.containsPixel(const Offset(100, 100)), true);
    });

    test('rectangle sector rejects points outside', () {
      const sector = Sector(name: 'Zone', x: 0, y: 0, width: 100, height: 100);
      expect(sector.containsPixel(const Offset(-1, 50)), false);
      expect(sector.containsPixel(const Offset(50, -1)), false);
      expect(sector.containsPixel(const Offset(101, 50)), false);
      expect(sector.containsPixel(const Offset(50, 101)), false);
    });

    test('polygon sector uses ray casting', () {
      const sector = Sector(
        name: 'Dreieck',
        x: 0,
        y: 0,
        points: [
          (x: 0.0, y: 0.0),
          (x: 100.0, y: 0.0),
          (x: 50.0, y: 100.0),
        ],
      );
      expect(sector.isPolygon, true);
      expect(sector.containsPixel(const Offset(50, 40)), true);
      // Punkt unterhalb des Dreiecks (Dreieck endet bei y=100)
      expect(sector.containsPixel(const Offset(50, 150)), false);
      // Punkt links außerhalb des Dreiecks
      expect(sector.containsPixel(const Offset(-5, 50)), false);
    });

    test('point sector only matches exact coordinates', () {
      const sector = Sector(name: 'Punkt', x: 42, y: 24);
      expect(sector.containsPixel(const Offset(42, 24)), true);
      expect(sector.containsPixel(const Offset(43, 24)), false);
    });
  });

  group('Sector - containsHex', () {
    final grid = HexGrid(
      tileWidth: 32,
      tileHeight: 32,
      mapWidth: 10,
      mapHeight: 10,
    );

    test('hex center inside rectangle is contained', () {
      // Hex (5,5) liegt ungefähr bei Pixel (160, 120)
      const sector = Sector(
        name: 'Zone',
        x: 0,
        y: 0,
        width: 300,
        height: 300,
      );
      expect(sector.containsHex(grid, 5, 5), true);
      expect(sector.containsHex(grid, 9, 9), false);
    });
  });

  group('parseSectors', () {
    test('returns empty list for null group', () {
      expect(parseSectors(null), isEmpty);
    });

    test('parses rectangle objects', () {
      final group = ObjectGroup(
        name: 'Sektoren',
        objects: [
          MapObject(
            id: 1,
            name: 'Sektor Nord',
            x: 128,
            y: 64,
            width: 256,
            height: 192,
          ),
        ],
      );
      final sectors = parseSectors(group);
      expect(sectors.length, 1);
      final sector = sectors.first;
      expect(sector.name, 'Sektor Nord');
      expect(sector.x, 128);
      expect(sector.y, 64);
      expect(sector.width, 256);
      expect(sector.height, 192);
      expect(sector.isRectangle, true);
    });

    test('parses polygon objects with absolute points', () {
      final group = ObjectGroup(
        name: 'Sektoren',
        objects: [
          MapObject(
            id: 1,
            name: 'Sektor Arena',
            x: 512,
            y: 128,
            points: [
              (x: 0.0, y: 0.0),
              (x: 160.0, y: 0.0),
              (x: 160.0, y: 96.0),
            ],
          ),
        ],
      );
      final sectors = parseSectors(group);
      expect(sectors.length, 1);
      final sector = sectors.first;
      expect(sector.isPolygon, true);
      expect(sector.points, [
        (x: 512.0, y: 128.0),
        (x: 672.0, y: 128.0),
        (x: 672.0, y: 224.0),
      ]);
    });

    test('preserves properties', () {
      final group = ObjectGroup(
        name: 'Sektoren',
        objects: [
          MapObject(
            id: 1,
            name: 'Gefahrenzone',
            properties: {'type': 'danger', 'label': 'test'},
          ),
        ],
      );
      final sectors = parseSectors(group);
      expect(sectors.first.properties['type'], 'danger');
      expect(sectors.first.properties['label'], 'test');
    });
  });

  group('findSectorGroup', () {
    test('returns null when no Sektoren group', () {
      final groups = [
        const ObjectGroup(name: 'Spawns', objects: []),
        const ObjectGroup(name: 'Gelaendetypen', objects: []),
      ];
      expect(findSectorGroup(groups), isNull);
    });

    test('returns the Sektoren group', () {
      final groups = [
        const ObjectGroup(name: 'Spawns', objects: []),
        const ObjectGroup(name: 'Sektoren', objects: []),
      ];
      final found = findSectorGroup(groups);
      expect(found, isNotNull);
      expect(found!.name, 'Sektoren');
    });
  });

  group('Integration - Reale Karten (Sektoren-Objektebene)', () {
    test('map0: Sektoren-Objektebene wird geparst', () async {
      final parser = TmxParser(assetBundle: rootBundle);
      final mapData =
          await parser.loadFromAsset('assets/maps/map0/street_battle.tmx');

      final group = findSectorGroup(mapData.objectGroups);
      expect(group, isNotNull);
      final sectors = parseSectors(group);
      // Aktuell ist die Ebene in map0 leer
      expect(sectors, isEmpty);
    });

    test('map1: Sektoren-Objektebene wird geparst', () async {
      final parser = TmxParser(assetBundle: rootBundle);
      final mapData = await parser
          .loadFromAsset('assets/maps/map1/street_battle_colliders.tmx');

      final group = findSectorGroup(mapData.objectGroups);
      expect(group, isNotNull);
      final sectors = parseSectors(group);
      // Aktuell ist die Ebene in map1 leer
      expect(sectors, isEmpty);
    });
  });
}