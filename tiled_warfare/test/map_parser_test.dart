import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/services/map_exceptions.dart';
import 'package:tiled_warfare/services/map_parser.dart';

/// TMX-Beispielstring mit CSV-kodiertem Layer und Inline-Tileset.
const _tmxCsv = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="hexagonal"
     renderorder="right-down" width="3" height="2" tilewidth="32" tileheight="32"
     staggeraxis="y" staggerindex="odd" nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" name="terrain" tilewidth="32" tileheight="32" tilecount="4" columns="2">
  <image source="terrain.png" width="64" height="64"/>
 </tileset>
 <layer id="1" name="ground" width="3" height="2">
  <data encoding="csv">
1,2,3,
4,1,2
  </data>
 </layer>
 <objectgroup id="2" name="Spawns">
  <object id="1" name="spawn_player1" type="" x="16" y="16" width="0" height="0"/>
  <object id="2" name="spawn_monster" type="" x="48" y="48" width="0" height="0"/>
 </objectgroup>
 <objectgroup id="3" name="Gelaendetypen">
  <object id="3" name="" type="ruin" x="0" y="0" width="64" height="64"/>
 </objectgroup>
</map>''';

/// TMX-Beispielstring mit ungültiger Tile-Datenlänge.
const _tmxInvalidLength = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="3" height="2" tilewidth="32" tileheight="32">
 <layer id="1" name="ground" width="3" height="2">
  <data encoding="csv">
1,2,3
  </data>
 </layer>
</map>''';

/// TMX-Beispielstring mit fehlendem `<data>`-Element.
const _tmxMissingData = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="3" height="2" tilewidth="32" tileheight="32">
 <layer id="1" name="ground" width="3" height="2"/>
</map>''';

/// TMX-Beispielstring mit externem TSX-Tileset.
const _tmxExternalTileset = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="hexagonal" width="2" height="2" tilewidth="32" tileheight="32"
     staggeraxis="y" staggerindex="odd">
 <tileset firstgid="1" source="terrain.tsx"/>
 <layer id="1" name="ground" width="2" height="2">
  <data encoding="csv">
1,2,
3,4
  </data>
 </layer>
</map>''';

/// TMJ-Beispielstring (JSON-Format).
final String _tmj = jsonEncode({
  "type": "map",
  "version": "1.10",
  "orientation": "hexagonal",
  "width": 2,
  "height": 2,
  "tilewidth": 32,
  "tileheight": 32,
  "staggeraxis": "y",
  "staggerindex": "odd",
  "tilesets": [
    {
      "firstgid": 1,
      "name": "terrain",
      "tilewidth": 32,
      "tileheight": 32,
      "tilecount": 4,
      "columns": 2,
      "image": "terrain.png",
      "imagewidth": 64,
      "imageheight": 64,
    }
  ],
  "layers": [
    {
      "type": "tilelayer",
      "name": "ground",
      "width": 2,
      "height": 2,
      "opacity": 1.0,
      "visible": true,
      "data": [1, 2, 3, 4],
    },
    {
      "type": "objectgroup",
      "name": "Spawns",
      "objects": [
        {"id": 1, "name": "spawn_player1", "type": "", "x": 16, "y": 16},
        {"id": 2, "name": "spawn_monster", "type": "", "x": 48, "y": 48},
      ],
    },
  ],
});

/// TMJ-Beispielstring mit Property-Objekt.
final String _tmjWithProperties = jsonEncode({
  "type": "map",
  "orientation": "orthogonal",
  "width": 1,
  "height": 1,
  "tilewidth": 32,
  "tileheight": 32,
  "layers": [
    {
      "type": "objectgroup",
      "name": "Gelaendetypen",
      "objects": [
        {
          "id": 1,
          "name": "",
          "type": "ruin",
          "x": 0,
          "y": 0,
          "width": 64,
          "height": 64,
          "properties": [
            {"name": "movementCost", "type": "int", "value": 2},
            {"name": "blocksVision", "type": "bool", "value": true},
            {"name": "label", "type": "string", "value": "test"},
          ],
        },
      ],
    },
  ],
});

/// Erzeugt eine Base64+Zlib-kodierte Tile-Daten-Zeichenkette.
String _makeBase64ZlibLayer(List<int> tileIds) {
  // 4 Bytes pro Tile-ID (little-endian)
  final bytes = Uint8List(tileIds.length * 4);
  for (int i = 0; i < tileIds.length; i++) {
    final tileId = tileIds[i];
    bytes[i * 4] = tileId & 0xFF;
    bytes[i * 4 + 1] = (tileId >> 8) & 0xFF;
    bytes[i * 4 + 2] = (tileId >> 16) & 0xFF;
    bytes[i * 4 + 3] = (tileId >> 24) & 0xFF;
  }
  final compressed = zlib.encode(bytes);
  return base64.encode(compressed);
}

void main() {
  group('TmxParser', () {
    test('parses map metadata from TMX', () {
      final parser = TmxParser(assetBundle: null);
      final map = parser.parse(_tmxCsv, 'assets/maps/test');

      expect(map.width, 3);
      expect(map.height, 2);
      expect(map.tileWidth, 32);
      expect(map.tileHeight, 32);
      expect(map.orientation, MapOrientation.hexagonal);
      expect(map.staggerAxis, 'y');
      expect(map.staggerIndex, 'odd');
    });

    test('parses CSV-encoded layer', () {
      final parser = TmxParser(assetBundle: null);
      final map = parser.parse(_tmxCsv, 'assets/maps/test');

      expect(map.layers.length, 1);
      final layer = map.layers.first;
      expect(layer.name, 'ground');
      expect(layer.width, 3);
      expect(layer.height, 2);
      expect(layer.tileData, Uint32List.fromList([1, 2, 3, 4, 1, 2]));
    });

    test('parses inline tileset', () {
      final parser = TmxParser(assetBundle: null);
      final map = parser.parse(_tmxCsv, 'assets/maps/test');

      expect(map.tilesets.length, 1);
      final tileset = map.tilesets.first;
      expect(tileset.firstGid, 1);
      expect(tileset.name, 'terrain');
      expect(tileset.imageSource, 'terrain.png');
      expect(tileset.columns, 2);
      expect(tileset.tileCount, 4);
    });

    test('parses external tileset reference', () {
      final parser = TmxParser(assetBundle: null);
      final map = parser.parse(_tmxExternalTileset, 'assets/maps/test');

      expect(map.tilesets.length, 1);
      final tileset = map.tilesets.first;
      expect(tileset.firstGid, 1);
      expect(tileset.source, 'terrain.tsx');
    });

    test('parses object groups', () {
      final parser = TmxParser(assetBundle: null);
      final map = parser.parse(_tmxCsv, 'assets/maps/test');

      expect(map.objectGroups.length, 2);

      final spawns = map.objectGroups.first;
      expect(spawns.name, 'Spawns');
      expect(spawns.objects.length, 2);
      expect(spawns.objects[0].name, 'spawn_player1');
      expect(spawns.objects[1].name, 'spawn_monster');

      final terrain = map.objectGroups[1];
      expect(terrain.name, 'Gelaendetypen');
      expect(terrain.objects.first.type, 'ruin');
    });

    test('parses Base64+Zlib compressed layer', () {
      const width = 2;
      const height = 2;
      final tileIds = [1, 2, 3, 4];
      final encoded = _makeBase64ZlibLayer(tileIds);

      final tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="$width" height="$height" tilewidth="32" tileheight="32">
 <layer id="1" name="ground" width="$width" height="$height">
  <data encoding="base64" compression="zlib">$encoded</data>
 </layer>
</map>''';

      final parser = TmxParser(assetBundle: null);
      final map = parser.parse(tmx, 'assets/maps/test');
      expect(map.layers.first.tileData, Uint32List.fromList(tileIds));
    });

    test('throws MapParseException on invalid tile data length', () {
      final parser = TmxParser(assetBundle: null);
      expect(
        () => parser.parse(_tmxInvalidLength, 'assets/maps/test'),
        throwsA(isA<MapParseException>()),
      );
    });

    test('throws MapParseException on missing data element', () {
      final parser = TmxParser(assetBundle: null);
      expect(
        () => parser.parse(_tmxMissingData, 'assets/maps/test'),
        throwsA(isA<MapParseException>()),
      );
    });

    test('throws MapParseException on unsupported map format', () {
      expect(
        () => MapParser.forPath('map.json'),
        throwsA(isA<MapParseException>()),
      );
    });

    test('MapParser.factory returns TmxParser for .tmx', () {
      final parser = MapParser.forPath('map.tmx');
      expect(parser, isA<TmxParser>());
    });

    test('MapParser.factory returns TmjParser for .tmj', () {
      final parser = MapParser.forPath('map.tmj');
      expect(parser, isA<TmjParser>());
    });

    test('MapParser.basePath extracts directory', () {
      expect(MapParser.basePath('assets/maps/map0/street_battle.tmx'),
          'assets/maps/map0');
      expect(MapParser.basePath('map.tmx'), '');
    });
  });

  group('TmjParser', () {
    test('parses map metadata from TMJ', () {
      final parser = TmjParser(assetBundle: null);
      final map = parser.parse(_tmj, 'assets/maps/test');

      expect(map.width, 2);
      expect(map.height, 2);
      expect(map.tileWidth, 32);
      expect(map.tileHeight, 32);
      expect(map.orientation, MapOrientation.hexagonal);
      expect(map.staggerAxis, 'y');
      expect(map.staggerIndex, 'odd');
    });

    test('parses tile layer from TMJ', () {
      final parser = TmjParser(assetBundle: null);
      final map = parser.parse(_tmj, 'assets/maps/test');

      expect(map.layers.length, 1);
      final layer = map.layers.first;
      expect(layer.name, 'ground');
      expect(layer.tileData, Uint32List.fromList([1, 2, 3, 4]));
    });

    test('parses tilesets from TMJ', () {
      final parser = TmjParser(assetBundle: null);
      final map = parser.parse(_tmj, 'assets/maps/test');

      expect(map.tilesets.length, 1);
      final tileset = map.tilesets.first;
      expect(tileset.firstGid, 1);
      expect(tileset.name, 'terrain');
      expect(tileset.imageSource, 'terrain.png');
    });

    test('parses object groups from TMJ', () {
      final parser = TmjParser(assetBundle: null);
      final map = parser.parse(_tmj, 'assets/maps/test');

      expect(map.objectGroups.length, 1);
      final spawns = map.objectGroups.first;
      expect(spawns.name, 'Spawns');
      expect(spawns.objects.length, 2);
      expect(spawns.objects[0].name, 'spawn_player1');
    });

    test('parses typed properties from TMJ', () {
      final parser = TmjParser(assetBundle: null);
      final map = parser.parse(_tmjWithProperties, 'assets/maps/test');

      final group = map.objectGroups.first;
      final obj = group.objects.first;
      expect(obj.type, 'ruin');
      expect(obj.properties['movementCost'], 2);
      expect(obj.properties['blocksVision'], true);
      expect(obj.properties['label'], 'test');
    });

    test('flip bits are masked in TMJ tile data', () {
      // Tile-ID mit gesetzten Flip-Bits (0x80000000 = flipped horizontally)
      final flipped = 0x80000001;
      final plain = 1; // Nach Maskierung: 1

      final tmj = jsonEncode({
        "type": "map",
        "orientation": "orthogonal",
        "width": 1,
        "height": 1,
        "tilewidth": 32,
        "tileheight": 32,
        "layers": [
          {
            "type": "tilelayer",
            "name": "ground",
            "width": 1,
            "height": 1,
            "data": [flipped],
          },
        ],
      });

      final parser = TmjParser(assetBundle: null);
      final map = parser.parse(tmj, 'assets/maps/test');
      expect(map.layers.first.tileData[0], plain);
    });
  });
}