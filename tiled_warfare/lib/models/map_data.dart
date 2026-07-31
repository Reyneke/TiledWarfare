import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

// ──────────────────────────────────────────────
// Layer-Purpose-System (Section 8)
// ──────────────────────────────────────────────

/// Definiert den Zweck eines Tile-Layers über den bloßen Namen hinaus.
///
/// Während [TileLayer.name] direkt aus der TMX/TMJ-Datei stammt, erlaubt
/// [LayerPurpose] eine **typsichere** Klassifizierung, welche Layer von der
/// Engine wie verwendet werden sollen (Boden, Kollision, Dekoration usw.).
///
/// Die Zuordnung von Layer-Name → Purpose erfolgt beim Laden über
/// [LayerPurpose.resolve] oder über [MapData.layerByPurpose].
///
/// ## Beispiel
/// ```dart
/// final ground = mapData.layerByPurpose(LayerPurpose.ground);
/// ```
enum LayerPurpose {
  /// Boden-Ebene: Wird zuerst gezeichnet, bildet die Grundfläche.
  ground,

  /// Kollisions-Ebene: Enthält Tiles, die als unpassierbar markiert sind.
  /// Wird in der Regel nicht visuell gezeichnet, sondern nur für
  /// Bewegungseinschränkungen verwendet.
  collision,

  /// Dekorations-Ebene: Wird über dem Boden gezeichnet (z. B. Bäume, Steine).
  decorative,

  /// Obere Dekorations-Ebene: Wird ganz oben gezeichnet (z. B. Dächer, Wolken).
  decorativeUpper,

  /// Gelände-Ebene: Enthält Informationen über Geländetypen.
  terrain,

  /// Standard/andere Layer ohne spezifischen Zweck.
  unknown;

  /// Standardmäßige Layer-Namen für jeden Purpose in der TMX/TMJ-Datei.
  ///
  /// Kann über [MapLoadConfig] überschrieben werden (siehe widget_map_loader.dart).
  static const Map<LayerPurpose, String> defaultLayerNames = {
    LayerPurpose.ground: 'ground',
    LayerPurpose.collision: 'collision',
    LayerPurpose.decorative: 'decoration',
    LayerPurpose.decorativeUpper: 'decoration - upper',
    LayerPurpose.terrain: 'terrain',
  };

  /// Versucht, einen [LayerPurpose] aus einem Layer-Namen zu ermitteln.
  ///
  /// Verwendet die [defaultLayerNames]-Zuordnung. Wenn der Name nicht
  /// erkannt wird, wird [LayerPurpose.unknown] zurückgegeben.
  static LayerPurpose fromLayerName(String name) {
    for (final entry in defaultLayerNames.entries) {
      if (entry.value == name) return entry.key;
    }
    return LayerPurpose.unknown;
  }

  /// Erstellt eine reverse-Map: Layer-Name → LayerPurpose.
  ///
  /// Nützlich für Lookups mit benutzerdefinierten Namen.
  static Map<String, LayerPurpose> nameMapping([
    Map<LayerPurpose, String>? customNames,
  ]) {
    final names = customNames ?? defaultLayerNames;
    return {for (final e in names.entries) e.value: e.key};
  }
}

/// Metadaten einer Karte aus der `maps.json`.
///
/// Enthält den Anzeigenamen, den Pfad zur TMX-Datei und optional
/// ein Vorschaubild für die Kartenauswahl.
@immutable
class MapMeta {
  /// Ordner-Pfad (z. B. "assets/maps/map0").
  final String mapPath;

  /// Anzeigename der Karte (z. B. "Street Battle").
  final String title;

  /// Optionaler Pfad zu einem Vorschaubild (z. B. "assets/maps/map0/preview.png").
  final String? previewPath;

  /// Pfad zur .tmx/.tmj-Datei (z. B. "assets/maps/map0/street_battle.tmx").
  final String tmxPath;

  const MapMeta({
    required this.mapPath,
    required this.title,
    this.previewPath,
    required this.tmxPath,
  });

  factory MapMeta.fromJson(Map<String, dynamic> json) => MapMeta(
        mapPath: json['mapPath'] as String,
        title: json['title'] as String,
        previewPath: json['previewPath'] as String?,
        tmxPath: json['tmxPath'] as String,
      );

  Map<String, dynamic> toJson() => {
        'mapPath': mapPath,
        'title': title,
        'previewPath': previewPath,
        'tmxPath': tmxPath,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapMeta &&
          mapPath == other.mapPath &&
          title == other.title &&
          previewPath == other.previewPath &&
          tmxPath == other.tmxPath;

  @override
  int get hashCode => Object.hash(mapPath, title, previewPath, tmxPath);
}

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
  ///
  /// `null`, wenn das Terrain noch nicht geparst wurde.
  final Map<int, TerrainType>? terrain;

  /// Vorberechnete Layer-Lookup-Map: Layer-Name → Layer-Index.
  ///
  /// Wird beim ersten Zugriff aufgebaut und dann für O(1)-Lookups
  /// in [layerByName] und [layerByPurpose] verwendet.
  late final Map<String, int> _layerIndexByName = _buildLayerIndex(layers);

  MapData({
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
    this.terrain,
  });

  /// Erstellt einen Index Layer-Name → Position für O(1)-Lookups.
  static Map<String, int> _buildLayerIndex(List<TileLayer> layers) {
    final index = <String, int>{};
    for (int i = 0; i < layers.length; i++) {
      index[layers[i].name] = i;
    }
    return index;
  }

  // ──────────────────────────────────────────────
  // Effiziente Layer-Lookups
  // ──────────────────────────────────────────────

  /// Gibt den Layer mit dem angegebenen Namen zurück, oder `null`.
  ///
  /// **O(1)** dank vorberechnetem Index.
  TileLayer? layerByName(String name) {
    final i = _layerIndexByName[name];
    return i != null ? layers[i] : null;
  }

  /// Gibt den Layer zurück, der dem angegebenen [LayerPurpose] entspricht.
  ///
  /// Verwendet die Standard-Namenszuordnung aus [LayerPurpose.defaultLayerNames].
  /// **O(1)**.
  TileLayer? layerByPurpose(LayerPurpose purpose) {
    final name = LayerPurpose.defaultLayerNames[purpose];
    if (name == null) return null;
    return layerByName(name);
  }

  /// Gibt alle Layer zurück, deren Purpose über [customMapping] bestimmt wird.
  ///
  /// Nützlich, wenn benutzerdefinierte Layer-Namen verwendet werden.
  TileLayer? layerByPurposeWithMapping(
    LayerPurpose purpose,
    Map<LayerPurpose, String> nameMapping,
  ) {
    final name = nameMapping[purpose];
    if (name == null) return null;
    return layerByName(name);
  }

  // ──────────────────────────────────────────────
  // Kollisionsberechnung
  // ──────────────────────────────────────────────

  /// Berechnet die Kollisions-Tiles aus dem Kollisions-Layer.
  ///
  /// Verwendet den Standard-Layer-Namen `'collision'` (entspricht
  /// [LayerPurpose.collision]).
  /// Ein Tile gilt als blockiert, wenn [TileLayer.tileAt] != 0.
  Set<int> computeCollisionTiles(HexGrid hexGrid) {
    final layer = layerByPurpose(LayerPurpose.collision);
    if (layer == null) return {};
    return _computeCollisionForLayer(layer, hexGrid);
  }

  /// Berechnet Kollisions-Tiles aus einem benannten Layer (Rückwärtskompatibilität).
  ///
  /// [collisionLayerName] – Name des Kollisions-Layers.
  /// [hexGrid] – Hex-Utility für hexKey-Berechnung.
  /// Ein Tile gilt als blockiert, wenn [TileLayer.tileAt] != 0.
  @Deprecated('Use computeCollisionTiles(hexGrid) instead, '
      'which uses the standard collision layer by purpose.')
  Set<int> computeCollisionTilesByName(
    String collisionLayerName,
    HexGrid hexGrid,
  ) {
    final layer = layerByName(collisionLayerName);
    if (layer == null) return {};
    return _computeCollisionForLayer(layer, hexGrid);
  }

  /// Gemeinsame Kollisions-Logik für einen beliebigen TileLayer.
  static Set<int> _computeCollisionForLayer(
    TileLayer layer,
    HexGrid hexGrid,
  ) {
    final collided = <int>{};
    for (int y = 0; y < layer.height; y++) {
      for (int x = 0; x < layer.width; x++) {
        if (layer.tileAt(x, y) != 0) {
          collided.add(hexGrid.hexKey(x, y));
        }
      }
    }
    return collided;
  }

  // ──────────────────────────────────────────────
  // copyWith & Serialisierung
  // ──────────────────────────────────────────────

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
    bool clearTerrain = false,
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
        terrain: clearTerrain ? null : terrain ?? this.terrain,
      );

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'tilewidth': tileWidth,
        'tileheight': tileHeight,
        'orientation': orientation.name,
        'staggeraxis': staggerAxis,
        'staggerindex': staggerIndex,
        'layers': layers.map((l) => l.toJson()).toList(),
        'tilesets': tilesets.map((t) => t.toJson()).toList(),
        'objectgroups': objectGroups.map((g) => g.toJson()).toList(),
        if (terrain != null)
          'terrain': terrain!.map((k, v) => MapEntry(k.toString(), v.name)),
      };

  factory MapData.fromJson(Map<String, dynamic> json, {HexGrid? hexGrid}) {
    final layersList = (json['layers'] as List<dynamic>?)
            ?.map((l) => TileLayer.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [];
    return MapData(
      width: json['width'] as int,
      height: json['height'] as int,
      tileWidth: json['tilewidth'] as int,
      tileHeight: json['tileheight'] as int,
      orientation: MapOrientation.fromString(
          json['orientation'] as String? ?? 'orthogonal'),
      staggerAxis: json['staggeraxis'] as String? ?? 'y',
      staggerIndex: json['staggerindex'] as String? ?? 'odd',
      layers: layersList,
      tilesets: (json['tilesets'] as List<dynamic>?)
              ?.map((t) => TilesetInfo.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      objectGroups: (json['objectgroups'] as List<dynamic>?)
              ?.map((g) => ObjectGroup.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      terrain: json['terrain'] != null
          ? (json['terrain'] as Map<String, dynamic>).map(
              (k, v) =>
                  MapEntry(int.parse(k), TerrainType.fromString(v as String)))
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapData &&
          width == other.width &&
          height == other.height &&
          tileWidth == other.tileWidth &&
          tileHeight == other.tileHeight &&
          orientation == other.orientation &&
          staggerAxis == other.staggerAxis &&
          staggerIndex == other.staggerIndex &&
          listEquals(layers, other.layers) &&
          listEquals(tilesets, other.tilesets) &&
          listEquals(objectGroups, other.objectGroups) &&
          mapEquals(terrain, other.terrain);

  @override
  int get hashCode => Object.hash(
      width, height, tileWidth, tileHeight, orientation, staggerAxis,
      staggerIndex, Object.hashAll(layers), Object.hashAll(tilesets),
      Object.hashAll(objectGroups), terrain);
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

  /// Der [LayerPurpose] dieses Layers, ermittelt aus dem Namen.
  ///
  /// Wird beim ersten Zugriff berechnet und dann zwischengespeichert.
  /// Kann über [MapLoadConfig] benutzerdefiniert zugeordnet werden.
  late final LayerPurpose purpose = LayerPurpose.fromLayerName(name);

  TileLayer({
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

  /// Gibt `true` zurück, wenn dieser Layer keine Tiles enthält.
  bool get isEmpty => tileData.every((id) => id == 0);

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

  /// Erstellt eine Kopie dieses Layers mit optional geänderten Feldern.
  ///
  /// Nützlich für Layertransformationen (z. B. Opacity-Override,
  /// dynamische Tile-Änderungen).
  TileLayer copyWith({
    String? name,
    int? width,
    int? height,
    double? opacity,
    bool? visible,
    Uint32List? tileData,
  }) =>
      TileLayer(
        name: name ?? this.name,
        width: width ?? this.width,
        height: height ?? this.height,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        tileData: tileData ?? this.tileData,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'width': width,
        'height': height,
        'opacity': opacity,
        'visible': visible,
        'data': tileData.toList(),
      };

  factory TileLayer.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();
    return TileLayer(
      name: json['name'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: json['visible'] as bool? ?? true,
      tileData: Uint32List.fromList(dataList),
    );
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
  int get hashCode =>
      Object.hash(name, width, height, opacity, visible, tileData);
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

  Map<String, dynamic> toJson() => {
        'firstgid': firstGid,
        if (source != null) 'source': source,
        if (name != null) 'name': name,
        if (tileWidth != null) 'tilewidth': tileWidth,
        if (tileHeight != null) 'tileheight': tileHeight,
        if (tileCount != null) 'tilecount': tileCount,
        if (columns != null) 'columns': columns,
        if (imageSource != null) 'image': imageSource,
        if (imageWidth != null) 'imagewidth': imageWidth,
        if (imageHeight != null) 'imageheight': imageHeight,
      };

  factory TilesetInfo.fromJson(Map<String, dynamic> json) => TilesetInfo(
        firstGid: json['firstgid'] as int,
        source: json['source'] as String?,
        name: json['name'] as String?,
        tileWidth: json['tilewidth'] as int?,
        tileHeight: json['tileheight'] as int?,
        tileCount: json['tilecount'] as int?,
        columns: json['columns'] as int?,
        imageSource: json['image'] as String?,
        imageWidth: json['imagewidth'] as int?,
        imageHeight: json['imageheight'] as int?,
      );

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

  Map<String, dynamic> toJson() => {
        'name': name,
        'objects': objects.map((o) => o.toJson()).toList(),
      };

  factory ObjectGroup.fromJson(Map<String, dynamic> json) => ObjectGroup(
        name: json['name'] as String,
        objects: (json['objects'] as List<dynamic>?)
                ?.map(
                    (o) => MapObject.fromJson(o as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectGroup &&
          name == other.name &&
          listEquals(objects, other.objects);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(objects));
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

  /// Polygon-Punkte (relativ zu [x], [y]) für `<polygon>`-Objekte.
  ///
  /// Jeder Punkt ist ein `(x, y)`-Offset. Leer, wenn das Objekt kein
  /// Polygon ist (z. B. Rechteck oder Punkt).
  final List<({double x, double y})> points;

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
    this.points = const [],
  });

  /// Gibt die absoluten Polygon-Punkte zurück (Offset + Objekt-Position).
  List<({double x, double y})> get absolutePoints => [
        for (final p in points) (x: x + p.x, y: y + p.y),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'visible': visible,
        'properties': Map<String, dynamic>.from(properties),
        if (points.isNotEmpty)
          'points': [for (final p in points) [p.x, p.y]],
      };

  factory MapObject.fromJson(Map<String, dynamic> json) {
    // Polygon-Punkte aus JSON parsen (Liste von [x, y]-Paaren)
    List<({double x, double y})> parsedPoints = const [];
    final rawPoints = json['points'];
    if (rawPoints is List) {
      parsedPoints = [
        for (final raw in rawPoints)
          if (raw is List && raw.length >= 2)
            (
              x: (raw[0] as num).toDouble(),
              y: (raw[1] as num).toDouble(),
            ),
      ];
    }
    return MapObject(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      visible: json['visible'] as bool? ?? true,
      properties: Map<String, dynamic>.from(
          json['properties'] as Map<String, dynamic>? ?? {}),
      points: parsedPoints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapObject &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height &&
          rotation == other.rotation &&
          visible == other.visible &&
          listEquals(points, other.points) &&
          mapEquals(properties, other.properties);

  @override
  int get hashCode => Object.hash(
      id, name, type, x, y, width, height, rotation, visible,
      Object.hashAll(points), properties);
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
      case 'ruins': // Tiled-Objektgruppen verwenden oft den Plural "ruins"
        return TerrainType.ruin;
      case 'forest':
        return TerrainType.forest;
      case 'water':
        return TerrainType.water;
      case 'wall':
      case 'walls': // Plural-Variante
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

  Map<String, dynamic> toJson() => {
        'movementCostMultiplier': movementCostMultiplier,
        'blocksVision': blocksVision,
        'impassable': impassable,
      };

  static const Map<TerrainType, TerrainConfig> defaults = {
    TerrainType.normal: TerrainConfig(),
    TerrainType.ruin:
        TerrainConfig(movementCostMultiplier: 2.0, blocksVision: true),
    TerrainType.forest:
        TerrainConfig(movementCostMultiplier: 1.5, blocksVision: true),
    TerrainType.water: TerrainConfig(impassable: true),
    TerrainType.wall: TerrainConfig(impassable: true, blocksVision: true),
    TerrainType.openGround: TerrainConfig(),
    TerrainType.swamp: TerrainConfig(movementCostMultiplier: 3.0),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerrainConfig &&
          movementCostMultiplier == other.movementCostMultiplier &&
          blocksVision == other.blocksVision &&
          impassable == other.impassable;

  @override
  int get hashCode =>
      Object.hash(movementCostMultiplier, blocksVision, impassable);
}