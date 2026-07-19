import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/services/map_parser.dart';
import 'package:tiled_warfare/services/terrain_service.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

/// Konfiguration für das Karten-Laden.
///
/// Erlaubt die Anpassung, welche Layer und Objektgruppen verwendet werden.
class MapLoadConfig {
  /// Name des Boden-Layers (TileLayer), der als Karten-Boden gezeichnet wird.
  final String groundLayerName;

  /// Name des Kollisions-Layers (TileLayer), falls vorhanden.
  final String? collisionLayerName;

  /// Name der Objektgruppe für Spawnpunkte.
  final String spawnGroupName;

  /// Name des Dekorations-Layers (TileLayer), der über dem Boden gezeichnet wird.
  final String? decorationLayerName;

  /// Name des oberen Dekorations-Layers (TileLayer), ganz oben gezeichnet.
  final String? decorationUpperLayerName;

  const MapLoadConfig({
    this.groundLayerName = 'ground',
    this.collisionLayerName = 'collision',
    this.spawnGroupName = 'Spawns',
    this.decorationLayerName = 'decoration',
    this.decorationUpperLayerName = 'decoration - upper',
  });
}

/// Lädt eine Tiled-Karte (TMX oder TMJ) und zeigt sie an.
/// Die Karte kann gezoomt und gescrollt werden.
class WidgetMapLoader extends StatefulWidget {
  /// Die zentrale Hex-Utility-Instanz für alle Gitter-Berechnungen.
  final HexGrid hexGrid;

  /// Callback, der aufgerufen wird, sobald die Karte geladen wurde.
  /// Übergibt die Kartendimensionen (Tile-Größe und Karten-Größe).
  final void Function({
    required int tileWidth,
    required int tileHeight,
    required int mapWidth,
    required int mapHeight,
  })? onMapLoaded;

  /// Callback, der den [TransformationController] des [InteractiveViewer]
  /// an das übergeordnete Widget weitergibt, damit z. B. der [WidgetCaretaker]
  /// die Token-Positionen mit dem Zoom/Scroll der Karte synchronisieren kann.
  final void Function(TransformationController controller)?
      onTransformationControllerCreated;

  /// Callback, der die geparsten Spawnpunkte aus der Map an das übergeordnete
  /// Widget weitergibt.
  /// Jeder Spawnpunkt hat einen Namen (z. B. "spawn_player1", "spawn_monster")
  /// und Pixel-Koordinaten (x, y) aus der TMX-Datei.
  final void Function(List<({String name, double x, double y})> spawnPoints)?
      onSpawnPointsParsed;

  /// Callback, der die geparsten Terrain-Daten und das Kollisions-Set
  /// an das übergeordnete Widget weitergibt.
  final void Function(
    Map<int, TerrainType> terrainMap,
    Set<int> collisionSet,
  )? onTerrainParsed;

  /// Der Pfad zur .tmx/.tmj-Datei, die geladen werden soll.
  /// Standardmäßig wird "assets/maps/street_battle.tmx" verwendet.
  final String mapPath;

  /// Konfiguration für das Karten-Laden.
  final MapLoadConfig config;

  const WidgetMapLoader({
    super.key,
    required this.hexGrid,
    this.onMapLoaded,
    this.onTransformationControllerCreated,
    this.onSpawnPointsParsed,
    this.onTerrainParsed,
    this.mapPath = 'assets/maps/street_battle.tmx',
    this.config = const MapLoadConfig(),
  });

  @override
  State<WidgetMapLoader> createState() => _WidgetMapLoaderState();
}

class _WidgetMapLoaderState extends State<WidgetMapLoader> {
  /// Alle geladenen Tileset-Bilder, indiziert nach firstGid.
  final Map<int, ({ui.Image image, int columns})> _tilesetImages = {};

  /// Die geladenen Kartendaten.
  MapData? _mapData;

  int _mapWidth = 30;
  int _mapHeight = 30;
  int _tileWidth = 32;
  int _tileHeight = 32;
  bool _isLoading = true;
  String? _error;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    widget.onTransformationControllerCreated?.call(_transformationController);
    _loadMap();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    for (final entry in _tilesetImages.values) {
      entry.image.dispose();
    }
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Karten-Ladevorgang
  // ──────────────────────────────────────────────

  Future<void> _loadMap() async {
    try {
      final parser = MapParser.forPath(
        widget.mapPath,
        assetBundle: rootBundle,
      );

      final mapData = await parser.loadFromAsset(widget.mapPath);
      _mapData = mapData;

      _mapWidth = mapData.width;
      _mapHeight = mapData.height;
      _tileWidth = mapData.tileWidth;
      _tileHeight = mapData.tileHeight;

      final basePath = MapParser.basePath(widget.mapPath);
      await _loadTilesetImages(mapData, basePath);

      final spawnPoints = _extractSpawnPoints(mapData);
      widget.onSpawnPointsParsed?.call(spawnPoints);

      // Terrain aus "Gelaendetypen"-Objektgruppe parsen
      final terrainGroup = mapData.objectGroups
          .where((g) => g.name == 'Gelaendetypen')
          .firstOrNull;
      final terrainMap = parseTerrain(terrainGroup, widget.hexGrid);

      // Kollisions-Set berechnen
      final collisionSet = mapData.computeCollisionTiles(
        widget.config.collisionLayerName ?? 'collision',
      );

      // Beides an den Callback übergeben
      widget.onTerrainParsed?.call(terrainMap, collisionSet);

      widget.onMapLoaded?.call(
        tileWidth: _tileWidth,
        tileHeight: _tileHeight,
        mapWidth: _mapWidth,
        mapHeight: _mapHeight,
      );

      setState(() {
        _isLoading = false;
      });
    } on FormatException catch (e) {
      setState(() {
        _error = 'Formatfehler: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unbekannter Fehler: $e';
        _isLoading = false;
      });
    }
  }

  // ──────────────────────────────────────────────
  // Tileset-Bilder laden
  // ──────────────────────────────────────────────

  Future<void> _loadTilesetImages(MapData mapData, String basePath) async {
    for (final tileset in mapData.tilesets) {
      final imagePath = tileset.imageSource != null
          ? '$basePath/${tileset.imageSource}'
          : null;
      if (imagePath == null) continue;

      try {
        final byteData = await rootBundle.load(imagePath);
        final codec =
            await ui.instantiateImageCodec(byteData.buffer.asUint8List());
        final frameInfo = await codec.getNextFrame();
        _tilesetImages[tileset.firstGid] = (
          image: frameInfo.image,
          columns: tileset.columns ?? 16,
        );
      } catch (e) {
        // Tileset-Bild konnte nicht geladen werden – überspringen
        debugPrint('Warning: Could not load tileset image: $imagePath ($e)');
      }
    }
  }

  // ──────────────────────────────────────────────
  // Spawnpunkte extrahieren
  // ──────────────────────────────────────────────

  List<({String name, double x, double y})> _extractSpawnPoints(
    MapData mapData,
  ) {
    final spawnPoints = <({String name, double x, double y})>[];
    for (final group in mapData.objectGroups) {
      if (group.name == widget.config.spawnGroupName) {
        for (final obj in group.objects) {
          if (obj.name.isNotEmpty) {
            spawnPoints.add((name: obj.name, x: obj.x, y: obj.y));
          }
        }
      }
    }
    return spawnPoints;
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Fehler beim Laden der Karte:\n$_error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_tilesetImages.isEmpty || _mapData == null) {
      return const Center(child: Text('Keine Kartendaten geladen.'));
    }

    // Berechne die Größe der hexagonalen Karte mittels zentraler HexGrid-Utility
    final mapPixelWidth = widget.hexGrid.mapPixelWidth;
    final mapPixelHeight = widget.hexGrid.mapPixelHeight;

    // Der Rand muss groß genug sein, damit _centerMap() in ScreenMain
    // die Karte mittig positionieren kann. Der minimale Offset für die
    // Zentrierung ist mapPixelWidth/2 (linker Rand der Karte), also
    // setzen wir die Grenze auf die gesamte Kartenbreite.
    final boundary = max(mapPixelWidth, mapPixelHeight).toDouble();

    return RepaintBoundary(
      child: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: EdgeInsets.all(boundary),
        minScale: 0.25,
        maxScale: 4.0,
        child: SizedBox(
          width: mapPixelWidth.toDouble(),
          height: mapPixelHeight.toDouble(),
          child: CustomPaint(
            painter: _HexMapPainter(
              tilesetImages: _tilesetImages,
              tilesets: _mapData!.tilesets,
              mapData: _mapData!,
              tileWidth: _tileWidth,
              tileHeight: _tileHeight,
              hexGrid: widget.hexGrid,
              config: widget.config,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ermittelt das passende Tileset für eine Tile-ID anhand des firstGid-Bereichs.
TilesetInfo? findTileset(int tileId, List<TilesetInfo> tilesets) {
  if (tileId == 0) return null;
  for (int i = tilesets.length - 1; i >= 0; i--) {
    if (tileId >= tilesets[i].firstGid) {
      return tilesets[i];
    }
  }
  return null;
}

class _HexMapPainter extends CustomPainter {
  /// Alle geladenen Tileset-Bilder, indiziert nach firstGid.
  final Map<int, ({ui.Image image, int columns})> tilesetImages;

  /// Alle Tileset-Informationen (für firstGid-Mapping).
  final List<TilesetInfo> tilesets;

  /// Die vollständigen Kartendaten.
  final MapData mapData;

  final int tileWidth;
  final int tileHeight;
  final HexGrid hexGrid;
  final MapLoadConfig config;

  /// Vorberechnete Pixel-Positionen für jedes Hex-Feld.
  late final List<List<Offset>> _pixelPositions;

  _HexMapPainter({
    required this.tilesetImages,
    required this.tilesets,
    required this.mapData,
    required this.tileWidth,
    required this.tileHeight,
    required this.hexGrid,
    required this.config,
  }) {
    _precomputePositions();
  }

  /// Berechnet alle Pixel-Positionen einmal vor, statt sie jedes Frame neu zu berechnen.
  void _precomputePositions() {
    _pixelPositions = List.generate(
      mapData.height,
      (y) => List.generate(
        mapData.width,
        (x) => hexGrid.hexToPixel(x: x, y: y),
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visibleRect = Offset.zero & size;

    // 1. Boden-Layer zeichnen
    _drawLayer(canvas, visibleRect, config.groundLayerName);

    // 2. Dekorations-Layer zeichnen (falls vorhanden)
    if (config.decorationLayerName != null) {
      _drawLayer(canvas, visibleRect, config.decorationLayerName!);
    }

    // 3. Oberen Dekorations-Layer zeichnen (falls vorhanden)
    if (config.decorationUpperLayerName != null) {
      _drawLayer(canvas, visibleRect, config.decorationUpperLayerName!);
    }
  }

  /// Zeichnet einen benannten Tile-Layer mit Viewport-Culling.
  void _drawLayer(Canvas canvas, Rect visibleRect, String layerName) {
    TileLayer? layer;
    for (final l in mapData.layers) {
      if (l.name == layerName) {
        layer = l;
        break;
      }
    }
    if (layer == null) return;

    final paint = Paint();
    if (layer.opacity < 1.0) {
      paint.color = paint.color.withValues(alpha: layer.opacity);
    }

    for (int y = 0; y < layer.height; y++) {
      for (int x = 0; x < layer.width; x++) {
        final tileId = layer.tileAt(x, y);
        if (tileId == 0) continue;

        final pixel = _pixelPositions[y][x];
        final tileRect = Rect.fromLTWH(
          pixel.dx,
          pixel.dy,
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

        // Viewport-Culling: Nur zeichnen, wenn Tile sichtbar ist
        if (!visibleRect.overlaps(tileRect)) continue;

        // Korrektes Tileset anhand firstGid ermitteln
        final tilesetInfo = findTileset(tileId, tilesets);
        if (tilesetInfo == null) continue;

        final tilesetEntry = tilesetImages[tilesetInfo.firstGid];
        if (tilesetEntry == null) continue;

        // Lokale ID innerhalb des Tilesets (0-basiert)
        final localId = tileId - tilesetInfo.firstGid;
        final tilesetX = (localId % tilesetEntry.columns) * tileWidth;
        final tilesetY = (localId ~/ tilesetEntry.columns) * tileHeight;

        canvas.drawImageRect(
          tilesetEntry.image,
          Rect.fromLTWH(
            tilesetX.toDouble(),
            tilesetY.toDouble(),
            tileWidth.toDouble(),
            tileHeight.toDouble(),
          ),
          tileRect,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexMapPainter oldDelegate) {
    return oldDelegate.tilesetImages != tilesetImages ||
        oldDelegate.mapData != mapData ||
        oldDelegate.hexGrid != hexGrid;
  }
}