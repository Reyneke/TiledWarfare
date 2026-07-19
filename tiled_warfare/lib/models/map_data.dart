import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Repräsentiert die Ausrichtung einer Tiled-Karte.
enum MapOrientation {
  orthogonal,
  isometric,
  hexagonal,
  staggered;

  static MapOrientation fromString(String value) {
    switch (value) {
      case 'orthogonal':
        return MapOrientation.orthogonal;
      case 'isometric':
        return MapOrientation.isometric;
      case 'hexagonal':
        return MapOrientation.hexagonal;
      case 'staggered':
        return MapOrientation.staggered;
      default:
        throw ArgumentError('Unknown map orientation: $value');
    }
  }
}

/// Repräsentiert eine vollständig geparste Karte aus TMX/TMJ.
@immutable
class MapData {
  final int width;
  final int height;
  final int tileWidth;
  final int tileHeight;
  final MapOrientation orientation;
  final String staggerAxis;
  final String staggerIndex;
  final List<TileLayer> layers;
  final List<TilesetInfo> tilesets;
  final List<ObjectGroup> objectGroups;

  /// Geländetypen-Lookup: hexKey(x, y) → [TerrainType].
  ///
  /// Wird aus der Objektgruppe `"Gelaendetypen"` geparst.
  /// Felder, die nicht in dieser Map vorkommen, gelten als
  /// [TerrainType.normal].
  final Map<int, TerrainType> terrain;

  const MapData({
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    required this.orientation,
    this.staggerAxis = 'y',
    this.staggerIndex = 'odd',
    this.layers = const [],
    this.tilesets = const [],
    this.objectGroups = const [],
    this.terrain = const {},
  });

  /// Berechnet die Kollisions-Tiles aus dem benannten Tile-Layer.
  ///
  /// [collisionLayerName] – Name des Kollisions-Layers (Standard: 'collision').
  /// Ein Tile gilt als blockiert, wenn [TileLayer.tileAt] != 0.
  Set<int> computeCollisionTiles(String collisionLayerName) {
    final collided = <int>{};
    for (final layer in layers) {
      if (layer.name != collisionLayerName) continue;
      for (int y = 0; y < layer.height; y++) {
        for (int x = 0; x < layer.width; x++) {
          if (layer.tileAt(x, y) != 0) {
            collided.add(hexKey(x, y));
          }
        }
      }
    }
    return collided;
  }

  /// Erzeugt eine eindeutige Kennung für ein Hex-Feld.
  int hexKey(int x, int y) => y * width + x;

  MapData copyWith({
    int? width,
    int? height,
    int? tileWidth,
    int? tileHeight,
    MapOrientation? orientation,
    String? staggerAxis,
    String? staggerIndex,
    List<TileLayer>? layers,
    List<TilesetInfo>? tilesets,
    List<ObjectGroup>? objectGroups,
    Map<int, TerrainType>? terrain,
  }) =>
      MapData(
        width: width ?? this.width,
        height: height ?? this.height,
        tileWidth: tileWidth ?? this.tileWidth,
        tileHeight: tileHeight ?? this.tileHeight,
        orientation: orientation ?? this.orientation,
        staggerAxis: staggerAxis ?? this.staggerAxis,
        staggerIndex: staggerIndex ?? this.staggerIndex,
        layers: layers ?? this.layers,
        tilesets: tilesets ?? this.tilesets,
        objectGroups: objectGroups ?? this.objectGroups,
        terrain: terrain ?? this.terrain,
      );
}

/// Repräsentiert einen Tile-Layer einer Tiled-Karte.
@immutable
class TileLayer {
  final String name;
  final int width;
  final int height;
  final double opacity;
  final bool visible;

  /// Tile-Daten als flaches [Uint32List]-Array.
  /// Zugriff: [tileAt(x, y)] gibt die Tile-ID an Position (x, y) zurück.
  /// 0 bedeutet leeres Tile.
  final Uint32List tileData;

  const TileLayer({
    required this.name,
    required this.width,
    required this.height,
    this.opacity = 1.0,
    this.visible = true,
    required this.tileData,
  }) : assert(tileData.length == width * height,
            'tileData length must match width * height');

  /// Gibt die Tile-ID an Position (x, y) zurück.
  /// 0 bedeutet leeres (leeres) Tile.
  int tileAt(int x, int y) => tileData[y * width + x];

  /// Gibt die Tile-Daten als 2D-Liste zurück (für Rückwärtskompatibilität).
  List<List<int>> toListOfLists() {
    final result = <List<int>>[];
    for (int y = 0; y < height; y++) {
      final row = <int>[];
      for (int x = 0; x < width; x++) {
        row.add(tileAt(x, y));
      }
      result.add(row);
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileLayer &&
          name == other.name &&
          width == other.width &&
          height == other.height &&
          opacity == other.opacity &&
          visible == other.visible &&
          tileData == other.tileData;

  @override
  int get hashCode => Object.hash(name, width, height, opacity, visible, tileData);
}

/// Repräsentiert ein Tileset in einer Tiled-Karte.
@immutable
class TilesetInfo {
  final int firstGid;
  final String? source;
  final String? name;
  final int? tileWidth;
  final int? tileHeight;
  final int? tileCount;
  final int? columns;
  final String? imageSource;
  final int? imageWidth;
  final int? imageHeight;

  const TilesetInfo({
    required this.firstGid,
    this.source,
    this.name,
    this.tileWidth,
    this.tileHeight,
    this.tileCount,
    this.columns,
    this.imageSource,
    this.imageWidth,
    this.imageHeight,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TilesetInfo && firstGid == other.firstGid && source == other.source;

  @override
  int get hashCode => Object.hash(firstGid, source);
}

/// Repräsentiert eine Objektgruppe (Object Layer) in einer Tiled-Karte.
@immutable
class ObjectGroup {
  final String name;
  final List<MapObject> objects;

  const ObjectGroup({
    required this.name,
    this.objects = const [],
  });
}

/// Repräsentiert ein einzelnes Objekt in einer Objektgruppe.
@immutable
class MapObject {
  final int id;
  final String name;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final bool visible;
  final Map<String, dynamic> properties;

  const MapObject({
    required this.id,
    this.name = '',
    this.type = '',
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
    this.visible = true,
    this.properties = const {},
  });
}

// ──────────────────────────────────────────────
// Terrain-System (Section 3.1)
// ──────────────────────────────────────────────

/// Geländetypen, die über die `"Gelaendetypen"`-Objektgruppe in der TMX
/// definiert werden. Jeder Typ entspricht einer `MapObject.type`-Zeichenkette.
enum TerrainType {
  /// Normales Gelände — keine Modifikatoren. (Standard)
  normal,

  /// Ruine — doppelte Bewegungskosten, blockiert Sicht.
  ruin,

  /// Wald — erhöhte Bewegungskosten, blockiert Sicht (oder gewährt Deckung).
  forest,

  /// Wasser — unpassierbar für die meisten Einheiten.
  water,

  /// Mauer — unpassierbar und blockiert Sicht.
  wall,

  /// Offenes Feld — normale Bewegung, keine Sichtblockade.
  openGround,

  /// Sumpf — dreifache Bewegungskosten.
  swamp;

  static TerrainType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ruin':
        return TerrainType.ruin;
      case 'forest':
        return TerrainType.forest;
      case 'water':
        return TerrainType.water;
      case 'wall':
        return TerrainType.wall;
      case 'open_ground':
        return TerrainType.openGround;
      case 'swamp':
        return TerrainType.swamp;
      default:
        return TerrainType.normal;
    }
  }
}

/// Konfiguration eines Geländetyps: Bewegungskosten und Sichtbarkeitsregeln.
@immutable
class TerrainConfig {
  /// Bewegungskosten-Multiplikator (1.0 = normal, 2.0 = doppelt, 0.0 = unpassierbar).
  final double movementCostMultiplier;

  /// Ob dieses Gelände die Sicht blockiert (Line-of-Sight blockieren).
  final bool blocksVision;

  /// Ob dieses Gelände unpassierbar ist (z. B. Wasser, Mauer).
  final bool impassable;

  const TerrainConfig({
    this.movementCostMultiplier = 1.0,
    this.blocksVision = false,
    this.impassable = false,
  });

  static const Map<TerrainType, TerrainConfig> defaults = {
    TerrainType.normal: TerrainConfig(),
    TerrainType.ruin: TerrainConfig(movementCostMultiplier: 2.0, blocksVision: true),
    TerrainType.forest: TerrainConfig(movementCostMultiplier: 1.5, blocksVision: true),
    TerrainType.water: TerrainConfig(impassable: true),
    TerrainType.wall: TerrainConfig(impassable: true, blocksVision: true),
    TerrainType.openGround: TerrainConfig(),
    TerrainType.swamp: TerrainConfig(movementCostMultiplier: 3.0),
  };
}