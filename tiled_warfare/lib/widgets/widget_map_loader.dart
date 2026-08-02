import 'dart:collection';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/services/fog_of_war.dart';
import 'package:tiled_warfare/services/map_exceptions.dart';
import 'package:tiled_warfare/services/map_parser.dart';
import 'package:tiled_warfare/services/terrain_service.dart';
import 'package:xml/xml.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

class MapLoadConfig {
  final String spawnGroupName;
  final bool respectLayerVisibility;
  final Map<LayerPurpose, String> layerNameOverrides;

  Map<LayerPurpose, String> get effectiveLayerNames {
    final result = Map<LayerPurpose, String>.from(LayerPurpose.defaultLayerNames);
    result.addAll(layerNameOverrides);
    return result;
  }

  String layerNameFor(LayerPurpose purpose) =>
      effectiveLayerNames[purpose] ?? LayerPurpose.defaultLayerNames[purpose]!;

  const MapLoadConfig({
    this.spawnGroupName = 'Spawns',
    this.respectLayerVisibility = true,
    this.layerNameOverrides = const {},
  });
}

class WidgetMapLoader extends StatefulWidget {
  final HexGrid hexGrid;
  final void Function({required int tileWidth, required int tileHeight, required int mapWidth, required int mapHeight})? onMapLoaded;
  final void Function(TransformationController controller)? onTransformationControllerCreated;
  final void Function(List<({String name, double x, double y})> spawnPoints)? onSpawnPointsParsed;
  final void Function(Map<int, TerrainType> terrainMap, Set<int> collisionSet)? onTerrainParsed;
  final String mapPath;
  final MapLoadConfig config;

  /// Optionaler Fog-of-War-Service für die Sichtbarkeits-Darstellung.
  ///
  /// Wenn gesetzt, werden nicht sichtbare Hex-Felder abgedunkelt und
  /// nicht aufgedeckte Felder schwarz gezeichnet.
  final FogOfWarService? fogOfWarService;

  const WidgetMapLoader({
    super.key,
    required this.hexGrid,
    this.onMapLoaded,
    this.onTransformationControllerCreated,
    this.onSpawnPointsParsed,
    this.onTerrainParsed,
    this.mapPath = 'assets/maps/street_battle.tmx',
    this.config = const MapLoadConfig(),
    this.fogOfWarService,
  });

  @override
  State<WidgetMapLoader> createState() => _WidgetMapLoaderState();
}

enum _MapErrorType { parseError, notFound, unknown }

class _WidgetMapLoaderState extends State<WidgetMapLoader> {
  static const int kMaxTilesetImages = 5;
  final LinkedHashMap<int, ({ui.Image image, int columns})> _tilesetImages = LinkedHashMap();
  MapData? _mapData;
  int _mapWidth = 30, _mapHeight = 30;
  int _tileWidth = 32, _tileHeight = 32;
  bool _isLoading = true;
  String? _error;
  _MapErrorType? _errorType;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    widget.onTransformationControllerCreated?.call(_transformationController);
    // Auf Fog-of-War-Änderungen lauschen, um die Karte neu zu zeichnen
    widget.fogOfWarService?.addListener(_onFogOfWarChanged);
    _loadMap();
  }

  @override
  void dispose() {
    widget.fogOfWarService?.removeListener(_onFogOfWarChanged);
    _transformationController.dispose();
    _disposeTilesetImages();
    super.dispose();
  }

  /// Wird aufgerufen, wenn sich die Sichtbarkeit (Fog of War) geändert hat.
  /// Löst ein Neuzeichnen der Karte aus.
  void _onFogOfWarChanged() {
    if (mounted) setState(() {});
  }

  void _disposeTilesetImages() {
    for (final entry in _tilesetImages.values) entry.image.dispose();
    _tilesetImages.clear();
  }

  void _putTilesetImage(int firstGid, ({ui.Image image, int columns}) entry) {
    if (_tilesetImages.containsKey(firstGid)) _tilesetImages.remove(firstGid);
    _tilesetImages[firstGid] = entry;
    while (_tilesetImages.length > kMaxTilesetImages) {
      final oldest = _tilesetImages.remove(_tilesetImages.keys.first);
      oldest?.image.dispose();
    }
  }

  Future<void> _loadMap() async {
    try {
      _disposeTilesetImages();
      final parser = MapParser.forPath(widget.mapPath, assetBundle: rootBundle);
      final mapData = await parser.loadFromAsset(widget.mapPath);
      _mapData = mapData;
      final groundLayer = mapData.layerByPurpose(LayerPurpose.ground);
      if (groundLayer == null) throw MapParseException(message: 'Map has no "ground" layer.', path: widget.mapPath);
      _mapWidth = mapData.width; _mapHeight = mapData.height;
      _tileWidth = mapData.tileWidth; _tileHeight = mapData.tileHeight;
      final basePath = MapParser.basePath(widget.mapPath);
      await _loadTilesetImages(mapData, basePath);
      final spawnPoints = _extractSpawnPoints(mapData);
      widget.onSpawnPointsParsed?.call(spawnPoints);
      final terrainGroup = mapData.objectGroups.where((g) => g.name == 'Gelaendetypen').firstOrNull;
      final terrainMap = parseTerrain(terrainGroup, widget.hexGrid);
      final collisionSet = mapData.computeCollisionTiles(widget.hexGrid);
      widget.onTerrainParsed?.call(terrainMap, collisionSet);
      widget.onMapLoaded?.call(tileWidth: _tileWidth, tileHeight: _tileHeight, mapWidth: _mapWidth, mapHeight: _mapHeight);
      setState(() { _isLoading = false; _error = null; _errorType = null; });
    } on MapParseException catch (e) { _setErrorState('Kartenformat-Fehler: $e', _MapErrorType.parseError); }
    on MapNotFoundException catch (e) { _setErrorState('Karte nicht gefunden: $e', _MapErrorType.notFound); }
    on FormatException catch (e) { _setErrorState('Formatfehler: ${e.message}', _MapErrorType.parseError); }
    on FlutterError catch (e) { _setErrorState('Asset-Fehler: ${e.message}', _MapErrorType.notFound); }
    catch (e) { _setErrorState('Unbekannter Fehler: $e', _MapErrorType.unknown); }
  }

  void _setErrorState(String message, _MapErrorType type) => setState(() { _error = message; _errorType = type; _isLoading = false; });
  void _retryLoad() => setState(() { _error = null; _errorType = null; _isLoading = true; _loadMap(); });

  Future<void> _loadTilesetImages(MapData mapData, String basePath) async {
    for (final tileset in mapData.tilesets) {
      String? imageSource = tileset.imageSource;
      if (imageSource == null && tileset.source != null) imageSource = await _resolveExternalTilesetSource(tileset.source!, basePath);
      if (imageSource != null) await _loadSingleTilesetImage(tileset.firstGid, '$basePath/$imageSource', tileset.columns);
    }
  }

  Future<String?> _resolveExternalTilesetSource(String source, String basePath) async {
    try {
      final tsxContent = await rootBundle.loadString('$basePath/$source');
      final tsxDoc = XmlDocument.parse(tsxContent);
      final imageElement = tsxDoc.findElements('tileset').first.findElements('image').firstOrNull;
      return imageElement?.getAttribute('source');
    } catch (e) { return null; }
  }

  Future<void> _loadSingleTilesetImage(int firstGid, String imagePath, int? columns) async {
    try {
      final byteData = await rootBundle.load(imagePath);
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      _putTilesetImage(firstGid, (image: frameInfo.image, columns: columns ?? 16));
    } on FlutterError catch (_) {} on FormatException catch (_) {} catch (_) {}
  }

  List<({String name, double x, double y})> _extractSpawnPoints(MapData mapData) {
    final spawnPoints = <({String name, double x, double y})>[];
    for (final group in mapData.objectGroups) {
      if (group.name == widget.config.spawnGroupName) {
        for (final obj in group.objects) {
          if (obj.name.isNotEmpty) spawnPoints.add((name: obj.name, x: obj.x, y: obj.y));
        }
      }
    }
    return spawnPoints;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildErrorWidget();
    if (_tilesetImages.isEmpty || _mapData == null) return const Center(child: Text('Keine Kartendaten geladen.'));

    final mapPixelWidth = widget.hexGrid.mapPixelWidth;
    final mapPixelHeight = widget.hexGrid.mapPixelHeight;

    return RepaintBoundary(
      child: InteractiveViewer(
        transformationController: _transformationController,
        constrained: false,
        boundaryMargin: EdgeInsets.zero,
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
              fogOfWarService: widget.fogOfWarService,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text('Fehler beim Laden der Karte:\n$_error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Erneut versuchen'), onPressed: _retryLoad),
      ],
    )));
  }
}

TilesetInfo? findTileset(int tileId, List<TilesetInfo> tilesets) {
  if (tileId == 0) return null;
  for (int i = tilesets.length - 1; i >= 0; i--) {
    if (tileId >= tilesets[i].firstGid) return tilesets[i];
  }
  return null;
}

class _VisibleTileRange {
  final int startY, endY, startX, endX;
  const _VisibleTileRange({required this.startY, required this.endY, required this.startX, required this.endX});
}

class _HexMapPainter extends CustomPainter {
  final Map<int, ({ui.Image image, int columns})> tilesetImages;
  final List<TilesetInfo> tilesets;
  final MapData mapData;
  final int tileWidth, tileHeight;
  final HexGrid hexGrid;
  final MapLoadConfig config;
  final FogOfWarService? fogOfWarService;
  final Map<LayerPurpose, String> _effectiveNames;
  final List<List<Offset>> _pixelPositions;

  _HexMapPainter({
    required this.tilesetImages, required this.tilesets, required this.mapData,
    required this.tileWidth, required this.tileHeight,
    required this.hexGrid, required this.config,
    this.fogOfWarService,
  }) : _effectiveNames = config.effectiveLayerNames,
       _pixelPositions = List.generate(mapData.height, (y) => List.generate(mapData.width, (x) => hexGrid.hexToPixel(x: x, y: y)));

  Iterable<TileLayer> _getVisibleLayers() sync* {
    for (final purpose in [LayerPurpose.ground, LayerPurpose.decorative, LayerPurpose.decorativeUpper]) {
      final name = _effectiveNames[purpose];
      if (name == null) continue;
      final layer = mapData.layerByName(name);
      if (layer != null && (config.respectLayerVisibility ? layer.visible : true)) yield layer;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visibleRect = Offset.zero & size;
    canvas.save(); canvas.clipRect(visibleRect);
    try {
      final viewportTiles = _computeVisibleTileRange(visibleRect);
      for (final layer in _getVisibleLayers()) _drawLayer(canvas, viewportTiles, layer);
      // Fog of War Overlay über die Karte zeichnen
      if (fogOfWarService != null) {
        _drawFogOfWar(canvas, viewportTiles);
      }
    } finally { canvas.restore(); }
  }

  /// Zeichnet den Fog of War als Overlay über die Karte.
  ///
  /// - Sichtbare Felder: kein Overlay (normal gezeichnet)
  /// - Aufgedeckte, aber nicht sichtbare Felder: dunkles Overlay (50% schwarz)
  /// - Weder sichtbar noch aufgedeckt: schwarzes Overlay (komplett verdeckt)
  void _drawFogOfWar(Canvas canvas, _VisibleTileRange v) {
    final fog = fogOfWarService!;
    final revealedPaint = Paint()..color = const Color(0x80000000); // 50% schwarz
    final hiddenPaint = Paint()..color = const Color(0xFF000000);   // komplett schwarz

    for (int y = v.startY; y < v.endY; y++) {
      for (int x = v.startX; x < v.endX; x++) {
        final key = hexGrid.hexKey(x, y);
        if (fog.isVisible(key)) continue; // sichtbar → kein Overlay

        final pixel = _pixelPositions[y][x];
        final hexPath = _createHexPath(
          centerX: pixel.dx + tileWidth / 2,
          centerY: pixel.dy + tileHeight / 2,
          size: tileWidth ~/ 2,
        );

        canvas.save();
        canvas.clipPath(hexPath);
        if (fog.isRevealed(key)) {
          canvas.drawRect(
            Rect.fromLTWH(pixel.dx, pixel.dy, tileWidth.toDouble(), tileHeight.toDouble()),
            revealedPaint,
          );
        } else {
          canvas.drawRect(
            Rect.fromLTWH(pixel.dx, pixel.dy, tileWidth.toDouble(), tileHeight.toDouble()),
            hiddenPaint,
          );
        }
        canvas.restore();
      }
    }
  }

  _VisibleTileRange _computeVisibleTileRange(Rect visibleRect) {
    const padding = 2;
    return _VisibleTileRange(
      startY: max(0, (visibleRect.top / (tileHeight * 0.75)).floor() - padding),
      endY: min(mapData.height, (visibleRect.bottom / (tileHeight * 0.75)).ceil() + padding),
      startX: max(0, (visibleRect.left / tileWidth).floor() - padding),
      endX: min(mapData.width, (visibleRect.right / tileWidth).ceil() + padding),
    );
  }

  void _drawLayer(Canvas canvas, _VisibleTileRange v, TileLayer layer) {
    final paint = Paint();
    if (layer.opacity < 1.0) paint.color = paint.color.withValues(alpha: layer.opacity);
    for (int y = v.startY; y < v.endY; y++) {
      for (int x = v.startX; x < v.endX; x++) {
        final tileId = layer.tileAt(x, y);
        if (tileId == 0) continue;
        final pixel = _pixelPositions[y][x];
        final tileRect = Rect.fromLTWH(pixel.dx, pixel.dy, tileWidth.toDouble(), tileHeight.toDouble());
        final tilesetInfo = findTileset(tileId, tilesets);
        if (tilesetInfo == null) continue;
        final tilesetEntry = tilesetImages[tilesetInfo.firstGid];
        if (tilesetEntry == null) continue;
        final localId = tileId - tilesetInfo.firstGid;
        final srcRect = Rect.fromLTWH(
          (localId % tilesetEntry.columns * tileWidth).toDouble(),
          (localId ~/ tilesetEntry.columns * tileHeight).toDouble(),
          tileWidth.toDouble(), tileHeight.toDouble());
        canvas.save();
        canvas.clipPath(_createHexPath(centerX: pixel.dx + tileWidth / 2, centerY: pixel.dy + tileHeight / 2, size: tileWidth ~/ 2));
        canvas.drawImageRect(tilesetEntry.image, srcRect, tileRect, paint);
        canvas.restore();
      }
    }
  }

  static Path _createHexPath({required double centerX, required double centerY, required int size}) {
    final path = Path();
    const sqrt3over2 = 0.8660254037844386;
    final hHalf = size * sqrt3over2;
    path.moveTo(centerX, centerY - size);
    path.lineTo(centerX + hHalf, centerY - size / 2);
    path.lineTo(centerX + hHalf, centerY + size / 2);
    path.lineTo(centerX, centerY + size);
    path.lineTo(centerX - hHalf, centerY + size / 2);
    path.lineTo(centerX - hHalf, centerY - size / 2);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexMapPainter old) {
    if (identical(old.tilesetImages, tilesetImages) && identical(old.mapData, mapData) && identical(old.hexGrid, hexGrid) && identical(old.config, config) && identical(old.fogOfWarService, fogOfWarService)) {
      // Fog of War: Neu zeichnen, wenn sich die Sichtbarkeit geändert hat
      if (fogOfWarService != null && old.fogOfWarService != null) {
        if (fogOfWarService!.visibilityVersion != old.fogOfWarService!.visibilityVersion) {
          return true;
        }
      }
      return false;
    }
    if (old.tilesetImages.length != tilesetImages.length) return true;
    if (old.mapData.layers.length != mapData.layers.length) return true;
    for (int i = 0; i < mapData.layers.length; i++) {
      if (old.mapData.layers[i].name != mapData.layers[i].name) return true;
      if (old.mapData.layers[i].tileData != mapData.layers[i].tileData) return true;
    }
    return false;
  }
}