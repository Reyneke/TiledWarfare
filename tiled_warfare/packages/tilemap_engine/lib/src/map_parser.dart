import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import 'map_data.dart';
import 'map_exceptions.dart';

/// Gemeinsames Interface für TMX- und TMJ-Parser.
abstract class MapParser {
  /// Parst eine Karte aus einem String (XML oder JSON).
  MapData parse(String content, String basePath);

  /// Lädt und parst eine Karte aus einer Asset-Datei.
  Future<MapData> loadFromAsset(String assetPath);

  /// Lädt und parst eine externe TSX-Tileset-Datei.
  ///
  /// TSX-Dateien sind immer XML (unabhängig davon, ob die referenzierende
  /// Karte als TMX oder TMJ vorliegt). [tsxPath] ist der vollständige
  /// Asset-Pfad zur `.tsx`-Datei.
  Future<TilesetInfo> loadExternalTileset(String tsxPath);

  /// Extrahiert den Basis-Pfad aus einem Asset-Pfad.
  static String basePath(String assetPath) {
    final index = assetPath.lastIndexOf('/');
    return index >= 0 ? assetPath.substring(0, index) : '';
  }

  /// Erstellt den passenden Parser für eine Datei anhand der Endung.
  static MapParser forPath(String path, {AssetBundle? assetBundle}) {
    if (path.endsWith('.tmj')) {
      return TmjParser(assetBundle: assetBundle);
    } else if (path.endsWith('.tmx')) {
      return TmxParser(assetBundle: assetBundle);
    }
    throw MapParseException(
      message: 'Unsupported map format (expected .tmx or .tmj)',
      path: path,
    );
  }
}

/// TMX-Parser (XML-Format).
class TmxParser implements MapParser {
  final AssetBundle _assetBundle;

  TmxParser({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  @override
  MapData parse(String content, String basePath) {
    final document = XmlDocument.parse(content);
    final mapElement = document.findElements('map').first;

    final orientationStr = mapElement.getAttribute('orientation') ?? 'orthogonal';
    final orientation = MapOrientation.fromString(orientationStr);

    return MapData(
      width: int.parse(mapElement.getAttribute('width') ?? '0'),
      height: int.parse(mapElement.getAttribute('height') ?? '0'),
      tileWidth: int.parse(mapElement.getAttribute('tilewidth') ?? '32'),
      tileHeight: int.parse(mapElement.getAttribute('tileheight') ?? '32'),
      orientation: orientation,
      staggerAxis: mapElement.getAttribute('staggeraxis') ?? 'y',
      staggerIndex: mapElement.getAttribute('staggerindex') ?? 'odd',
      layers: _parseLayers(mapElement, basePath),
      tilesets: _parseTilesets(mapElement, basePath),
      objectGroups: _parseObjectGroups(mapElement),
    );
  }

  @override
  Future<MapData> loadFromAsset(String assetPath) async {
    final content = await _assetBundle.loadString(assetPath);
    return parse(content, MapParser.basePath(assetPath));
  }

  // ──────────────────────────────────────────────
  // Layer-Parsing
  // ──────────────────────────────────────────────

  List<TileLayer> _parseLayers(XmlElement mapElement, String basePath) {
    final layers = <TileLayer>[];
    for (final layerElement in mapElement.findElements('layer')) {
      final dataElement = layerElement.findElements('data').firstOrNull;
      if (dataElement == null) {
        throw MapParseException(
          message:
              'Missing <data> element in layer "${layerElement.getAttribute('name')}"',
          path: basePath,
        );
      }

      final encoding = dataElement.getAttribute('encoding') ?? 'csv';
      final compression = dataElement.getAttribute('compression');

      List<int> tileIds;
      switch (encoding) {
        case 'csv':
          tileIds = _parseCsv(dataElement.innerText);
          break;
        case 'base64':
          tileIds = _parseBase64(dataElement.innerText, compression);
          break;
        default:
          throw MapParseException(
            message: 'Unsupported encoding: $encoding',
            path: basePath,
          );
      }

      final width = int.parse(layerElement.getAttribute('width') ?? '0');
      final height = int.parse(layerElement.getAttribute('height') ?? '0');

      if (tileIds.length != width * height) {
        throw MapParseException(
          message: 'Tile data length (${tileIds.length}) does not match '
              'layer dimensions ($width x $height = ${width * height})',
          path: basePath,
        );
      }

      layers.add(TileLayer(
        name: layerElement.getAttribute('name') ?? '',
        width: width,
        height: height,
        opacity: double.parse(layerElement.getAttribute('opacity') ?? '1.0'),
        visible: layerElement.getAttribute('visible') != '0',
        tileData: Uint32List.fromList(tileIds),
      ));
    }
    return layers;
  }

  // ──────────────────────────────────────────────
  // CSV-Parsing
  // ──────────────────────────────────────────────

  List<int> _parseCsv(String csv) {
    return csv
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => int.parse(s.trim()))
        .toList();
  }

  // ──────────────────────────────────────────────
  // Base64/Zlib/Gzip-Parsing
  // ──────────────────────────────────────────────

  List<int> _parseBase64(String base64Data, String? compression) {
    final decoded = base64.decode(base64Data.trim());
    final bytes = switch (compression) {
      'zlib' => ZLibDecoder().decodeBytes(decoded),
      'gzip' => GZipDecoder().decodeBytes(decoded),
      _ => decoded, // keine Kompression
    };

    // 4 Bytes pro Tile-ID (little-endian)
    final result = <int>[];
    for (int i = 0; i < bytes.length; i += 4) {
      final tileId = bytes[i] |
          (bytes[i + 1] << 8) |
          (bytes[i + 2] << 16) |
          (bytes[i + 3] << 24);
      result.add(tileId & 0x3FFFFFFF); // Flip-Bits maskieren
    }
    return result;
  }

  // ──────────────────────────────────────────────
  // Tileset-Parsing
  // ──────────────────────────────────────────────

  List<TilesetInfo> _parseTilesets(XmlElement mapElement, String basePath) {
    final tilesets = <TilesetInfo>[];
    for (final tsElement in mapElement.findElements('tileset')) {
      final firstGid = int.parse(tsElement.getAttribute('firstgid') ?? '1');
      final source = tsElement.getAttribute('source');

      tilesets.add(_parseTilesetElement(tsElement, firstGid, source: source));
    }
    return tilesets;
  }

  /// Lädt und parst eine TSX-Datei asynchron.
  @override
  Future<TilesetInfo> loadExternalTileset(String tsxPath) async {
    final tsxContent = await _assetBundle.loadString(tsxPath);
    final document = XmlDocument.parse(tsxContent);
    final tilesetElement = document.findElements('tileset').first;
    return _parseTilesetElementFromXml(tilesetElement);
  }

  TilesetInfo _parseTilesetElementFromXml(
    XmlElement element, {
    int firstGid = 1,
  }) {
    final imageElement = element.findElements('image').firstOrNull;
    return TilesetInfo(
      firstGid: firstGid,
      name: element.getAttribute('name'),
      tileWidth: int.tryParse(element.getAttribute('tilewidth') ?? ''),
      tileHeight: int.tryParse(element.getAttribute('tileheight') ?? ''),
      tileCount: int.tryParse(element.getAttribute('tilecount') ?? ''),
      columns: int.tryParse(element.getAttribute('columns') ?? ''),
      imageSource: imageElement?.getAttribute('source'),
      imageWidth: int.tryParse(imageElement?.getAttribute('width') ?? ''),
      imageHeight: int.tryParse(imageElement?.getAttribute('height') ?? ''),
    );
  }

  TilesetInfo _parseTilesetElement(
    XmlElement element,
    int firstGid, {
    String? source,
  }) {
    final imageElement = element.findElements('image').firstOrNull;
    return TilesetInfo(
      firstGid: firstGid,
      source: source,
      name: element.getAttribute('name'),
      tileWidth: int.tryParse(element.getAttribute('tilewidth') ?? ''),
      tileHeight: int.tryParse(element.getAttribute('tileheight') ?? ''),
      tileCount: int.tryParse(element.getAttribute('tilecount') ?? ''),
      columns: int.tryParse(element.getAttribute('columns') ?? ''),
      imageSource: imageElement?.getAttribute('source'),
      imageWidth: int.tryParse(imageElement?.getAttribute('width') ?? ''),
      imageHeight: int.tryParse(imageElement?.getAttribute('height') ?? ''),
    );
  }

  // ──────────────────────────────────────────────
  // Objektgruppen-Parsing
  // ──────────────────────────────────────────────

  List<ObjectGroup> _parseObjectGroups(XmlElement mapElement) {
    final groups = <ObjectGroup>[];
    for (final ogElement in mapElement.findElements('objectgroup')) {
      final objects = <MapObject>[];
      for (final objElement in ogElement.findElements('object')) {
        final properties = <String, dynamic>{};
        final propsElement = objElement.findElements('properties').firstOrNull;
        if (propsElement != null) {
          for (final prop in propsElement.findElements('property')) {
            final name = prop.getAttribute('name') ?? '';
            final value = prop.getAttribute('value');
            final type = prop.getAttribute('type') ?? 'string';
            properties[name] = _parsePropertyValue(value ?? '', type);
          }
        }

        // Polygon-Punkte parsen (relativ zu x/y)
        List<({double x, double y})> polygonPoints = const [];
        final polygonElement = objElement.findElements('polygon').firstOrNull;
        if (polygonElement != null) {
          final pointsAttr = polygonElement.getAttribute('points') ?? '';
          polygonPoints = pointsAttr
              .split(' ')
              .where((s) => s.trim().isNotEmpty)
              .map((pair) {
            final parts = pair.split(',');
            return (
              x: double.tryParse(parts[0]) ?? 0.0,
              y: parts.length > 1 ? double.tryParse(parts[1]) ?? 0.0 : 0.0,
            );
          }).toList();
        }

        objects.add(MapObject(
          id: int.parse(objElement.getAttribute('id') ?? '0'),
          name: objElement.getAttribute('name') ?? '',
          type: objElement.getAttribute('type') ?? '',
          x: double.parse(objElement.getAttribute('x') ?? '0'),
          y: double.parse(objElement.getAttribute('y') ?? '0'),
          width: double.parse(objElement.getAttribute('width') ?? '0'),
          height: double.parse(objElement.getAttribute('height') ?? '0'),
          rotation: double.parse(objElement.getAttribute('rotation') ?? '0'),
          visible: objElement.getAttribute('visible') != '0',
          properties: properties,
          points: polygonPoints,
        ));
      }

      groups.add(ObjectGroup(
        name: ogElement.getAttribute('name') ?? '',
        objects: objects,
      ));
    }
    return groups;
  }

  dynamic _parsePropertyValue(dynamic value, String type) {
    if (value == null) return null;
    return switch (type) {
      'int' => value is int
          ? value
          : value is String
              ? int.tryParse(value)
              : (value as num).toInt(),
      'float' => value is double
          ? value
          : value is String
              ? double.tryParse(value)
              : (value as num).toDouble(),
      'bool' => value is bool ? value : value == 'true',
      _ => value.toString(),
    };
  }
}

/// TMJ-Parser (JSON-Format).
class TmjParser implements MapParser {
  final AssetBundle _assetBundle;

  TmjParser({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  @override
  MapData parse(String content, String basePath) {
    final json = jsonDecode(content) as Map<String, dynamic>;

    final orientationStr = json['orientation'] as String? ?? 'orthogonal';
    final orientation = MapOrientation.fromString(orientationStr);

    return MapData(
      width: json['width'] as int,
      height: json['height'] as int,
      tileWidth: json['tilewidth'] as int,
      tileHeight: json['tileheight'] as int,
      orientation: orientation,
      staggerAxis: json['staggeraxis'] as String? ?? 'y',
      staggerIndex: json['staggerindex'] as String? ?? 'odd',
      layers: _parseLayers(json),
      tilesets: _parseTilesets(json, basePath),
      objectGroups: _parseObjectGroups(json),
    );
  }

  @override
  Future<MapData> loadFromAsset(String assetPath) async {
    final content = await _assetBundle.loadString(assetPath);
    return parse(content, MapParser.basePath(assetPath));
  }

  @override
  Future<TilesetInfo> loadExternalTileset(String tsxPath) async {
    final tsxContent = await _assetBundle.loadString(tsxPath);
    final document = XmlDocument.parse(tsxContent);
    final tilesetElement = document.findElements('tileset').first;
    final imageElement = tilesetElement.findElements('image').firstOrNull;
    return TilesetInfo(
      firstGid: 1,
      name: tilesetElement.getAttribute('name'),
      tileWidth: int.tryParse(tilesetElement.getAttribute('tilewidth') ?? ''),
      tileHeight: int.tryParse(tilesetElement.getAttribute('tileheight') ?? ''),
      tileCount: int.tryParse(tilesetElement.getAttribute('tilecount') ?? ''),
      columns: int.tryParse(tilesetElement.getAttribute('columns') ?? ''),
      imageSource: imageElement?.getAttribute('source'),
      imageWidth: int.tryParse(imageElement?.getAttribute('width') ?? ''),
      imageHeight: int.tryParse(imageElement?.getAttribute('height') ?? ''),
    );
  }

  // ──────────────────────────────────────────────
  // Layer-Parsing
  // ──────────────────────────────────────────────

  List<TileLayer> _parseLayers(Map<String, dynamic> mapJson) {
    final layers = <TileLayer>[];
    final layersJson = mapJson['layers'] as List<dynamic>? ?? [];

    for (final layerJson in layersJson) {
      final type = layerJson['type'] as String?;
      if (type != 'tilelayer') continue;

      final dataRaw = layerJson['data'] as List<dynamic>;
      final width = layerJson['width'] as int;
      final height = layerJson['height'] as int;

      final tileIds = dataRaw
          .map((e) => (e as int) & 0x3FFFFFFF) // Flip-Bits maskieren
          .toList();

      layers.add(TileLayer(
        name: layerJson['name'] as String? ?? '',
        width: width,
        height: height,
        opacity: (layerJson['opacity'] as num?)?.toDouble() ?? 1.0,
        visible: layerJson['visible'] as bool? ?? true,
        tileData: Uint32List.fromList(tileIds),
      ));
    }
    return layers;
  }

  // ──────────────────────────────────────────────
  // Tileset-Parsing
  // ──────────────────────────────────────────────

  List<TilesetInfo> _parseTilesets(
    Map<String, dynamic> mapJson,
    String basePath,
  ) {
    final tilesets = <TilesetInfo>[];
    final tilesetsJson = mapJson['tilesets'] as List<dynamic>? ?? [];

    for (final tsJson in tilesetsJson) {
      final firstGid = tsJson['firstgid'] as int;
      final source = tsJson['source'] as String?;

      if (source != null) {
        tilesets.add(TilesetInfo(
          firstGid: firstGid,
          source: source,
          name: tsJson['name'] as String?,
        ));
      } else {
        tilesets.add(TilesetInfo(
          firstGid: firstGid,
          name: tsJson['name'] as String?,
          tileWidth: tsJson['tilewidth'] as int?,
          tileHeight: tsJson['tileheight'] as int?,
          tileCount: tsJson['tilecount'] as int?,
          columns: tsJson['columns'] as int?,
          imageSource: tsJson['image'] as String?,
          imageWidth: tsJson['imagewidth'] as int?,
          imageHeight: tsJson['imageheight'] as int?,
        ));
      }
    }
    return tilesets;
  }

  // ──────────────────────────────────────────────
  // Objektgruppen-Parsing
  // ──────────────────────────────────────────────

  List<ObjectGroup> _parseObjectGroups(Map<String, dynamic> mapJson) {
    final groups = <ObjectGroup>[];
    final layersJson = mapJson['layers'] as List<dynamic>? ?? [];

    for (final layerJson in layersJson) {
      if (layerJson['type'] != 'objectgroup') continue;

      final objects = <MapObject>[];
      final objectsJson = layerJson['objects'] as List<dynamic>? ?? [];

      for (final objJson in objectsJson) {
        final properties = <String, dynamic>{};
        if (objJson['properties'] != null) {
          for (final prop in objJson['properties'] as List<dynamic>) {
            final name = prop['name'] as String;
            final value = prop['value'];
            final type = prop['type'] as String? ?? 'string';
            properties[name] = _parsePropertyValue(value, type);
          }
        }

        // Polygon-Punkte aus JSON parsen
        List<({double x, double y})> parsedPoints = const [];
        final rawPolygon = objJson['polygon'];
        if (rawPolygon is List) {
          parsedPoints = [
            for (final raw in rawPolygon)
              if (raw is Map)
                (
                  x: ((raw['x'] as num?)?.toDouble() ?? 0),
                  y: ((raw['y'] as num?)?.toDouble() ?? 0),
                ),
          ];
        }

        objects.add(MapObject(
          id: objJson['id'] as int? ?? 0,
          name: objJson['name'] as String? ?? '',
          type: objJson['type'] as String? ?? '',
          x: (objJson['x'] as num?)?.toDouble() ?? 0,
          y: (objJson['y'] as num?)?.toDouble() ?? 0,
          width: (objJson['width'] as num?)?.toDouble() ?? 0,
          height: (objJson['height'] as num?)?.toDouble() ?? 0,
          rotation: (objJson['rotation'] as num?)?.toDouble() ?? 0,
          visible: objJson['visible'] as bool? ?? true,
          properties: properties,
          points: parsedPoints,
        ));
      }

      groups.add(ObjectGroup(
        name: layerJson['name'] as String? ?? '',
        objects: objects,
      ));
    }
    return groups;
  }

  dynamic _parsePropertyValue(dynamic value, String type) {
    if (value == null) return null;
    return switch (type) {
      'int' => value is int
          ? value
          : value is String
              ? int.tryParse(value)
              : (value as num).toInt(),
      'float' => value is double
          ? value
          : value is String
              ? double.tryParse(value)
              : (value as num).toDouble(),
      'bool' => value is bool ? value : value == 'true',
      _ => value.toString(),
    };
  }
}