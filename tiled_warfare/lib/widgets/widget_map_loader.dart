import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/services/map_exceptions.dart';
import 'package:tiled_warfare/services/map_parser.dart';
import 'package:tiled_warfare/services/terrain_service.dart';
import 'package:xml/xml.dart';
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

/// Kategorisiert Fehlertypen für die UI-Entscheidung.
enum _MapErrorType {
  /// Format-Fehler (z. B. ungültiges XML/JSON, fehlende Elemente).
  parseError,

  /// Asset nicht gefunden (z. B. fehlende TMX-Datei, fehlendes Tileset-Bild).
  notFound,

  /// Unbekannter/allgemeiner Fehler.
  unknown,
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
      // Alte Tileset-Bilder disposen, bevor neue geladen werden
      // (verhindert Memory-Leaks bei Kartenwechsel)
      for (final entry in _tilesetImages.values) {
        entry.image.dispose();
      }
      _tilesetImages.clear();

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

      // Kollisions-Set berechnen (verwendet purpose-basierten Lookup)
      final collisionSet = mapData.computeCollisionTiles(widget.hexGrid);

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
    } on MapParseException catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } on MapNotFoundException catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } on FormatException catch (e) {
      setState(() {
        _error = 'Formatfehler: ${e.message}';
        _isLoading = false;
      });
    } on FlutterError catch (e) {
      setState(() {
        _error = 'Asset-Fehler: ${e.message}';
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
      // Externes Tileset (TSX): imageSource nachladen
      String? imageSource = tileset.imageSource;
      if (imageSource == null && tileset.source != null) {
        try {
          final tsxPath = '$basePath/${tileset.source}';
          final tsxContent = await rootBundle.loadString(tsxPath);
          final tsxDoc = XmlDocument.parse(tsxContent);
          final tsxTileset = tsxDoc.findElements('tileset').first;
          final imageElement = tsxTileset.findElements('image').firstOrNull;
          imageSource = imageElement?.getAttribute('source');
        } catch (e) {
          debugPrint('Warning: Could not load external tileset: ${tileset.source} ($e)');
        }
      }

      final imagePath = imageSource != null
          ? '$basePath/$imageSource'
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
      } on FlutterError catch (e) {
        // Asset nicht gefunden – z. B. Tileset-Bild fehlt im Deployment
        debugPrint('Warning: Tileset image not found: $imagePath ($e.message)');
      } on FormatException catch (e) {
        // Bilddaten korrupt – z. B. keine gültige PNG/JPEG-Datei
        debugPrint('Warning: Corrupted tileset image: $imagePath ($e.message)');
      } catch (e) {
        // Alle anderen Fehler (z. B. Codec-Fehler, OOM)
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

  /// Bestimmt den Fehlertyp aus der Fehlermeldung für die UI-Entscheidung.
  _MapErrorType _classifyError() {
    if (_error == null) return _MapErrorType.unknown;
    if (_error!.contains('MapParseException') ||
        _error!.contains('FormatException') ||
        _error!.contains('Formatfehler')) {
      return _MapErrorType.parseError;
    }
    if (_error!.contains('MapNotFoundException') ||
        _error!.contains('Asset-Fehler')) {
      return _MapErrorType.notFound;
    }
    return _MapErrorType.unknown;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final errorType = _classifyError();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                switch (errorType) {
                  _MapErrorType.parseError => Icons.warning_amber_rounded,
                  _MapErrorType.notFound => Icons.map_outlined,
                  _MapErrorType.unknown => Icons.error_outline,
                },
                size: 48,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Fehler beim Laden der Karte:\n$_error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (errorType == _MapErrorType.parseError)
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Erneut versuchen'),
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _loadMap();
                      },
                    ),
                  if (errorType == _MapErrorType.notFound)
                    FilledButton.icon(
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Fallback-Karte laden'),
                      onPressed: () {
                        // Fallback: Standardkarte laden
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        // Hier könnte man die MapRegistry nutzen, um eine
                        // andere Karte zu laden. Vorerst wird erneut versucht.
                        _loadMap();
                      },
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Zurück'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
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

/// Bereich sichtbarer Tiles im Viewport (exklusive Grenzen).
class _VisibleTileRange {
  final int startY;
  final int endY;
  final int startX;
  final int endX;

  const _VisibleTileRange({
    required this.startY,
    required this.endY,
    required this.startX,
    required this.endX,
  });
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
  final List<List<Offset>> _pixelPositions;

  _HexMapPainter({
    required this.tilesetImages,
    required this.tilesets,
    required this.mapData,
    required this.tileWidth,
    required this.tileHeight,
    required this.hexGrid,
    required this.config,
  }) : _pixelPositions = _computePositions(mapData, hexGrid);

  /// Berechnet alle Pixel-Positionen einmal vor, statt sie jedes Frame neu zu berechnen.
  static List<List<Offset>> _computePositions(MapData mapData, HexGrid hexGrid) {
    return List.generate(
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

    // Clip auf sichtbaren Bereich, damit die GPU keine Pixel außerhalb rendert
    canvas.save();
    canvas.clipRect(visibleRect);

    // Sichtbaren Tile-Bereich einmal berechnen (statt 3× in _drawLayer)
    final viewportTiles = _computeVisibleTileRange(visibleRect);

    try {
      // 1. Boden-Layer zeichnen
      _drawLayer(canvas, viewportTiles, config.groundLayerName);

      // 2. Dekorations-Layer zeichnen (falls vorhanden)
      if (config.decorationLayerName != null) {
        _drawLayer(canvas, viewportTiles, config.decorationLayerName!);
      }

      // 3. Oberen Dekorations-Layer zeichnen (falls vorhanden)
      if (config.decorationUpperLayerName != null) {
        _drawLayer(canvas, viewportTiles, config.decorationUpperLayerName!);
      }
    } finally {
      canvas.restore();
    }
  }

  /// Bereich der sichtbaren Tiles im [visibleRect] berechnen.
  ///
  /// Bei odd-r-Hex-Gittern: y-Pixel = y * tileHeight * 3/4, x-Pixel ≈ x * tileWidth.
  /// Padding von 2 Tiles pro Seite fängt die odd-row-Verschiebung (tileWidth/2) ab.
  _VisibleTileRange _computeVisibleTileRange(Rect visibleRect) {
    const padding = 2;
    return _VisibleTileRange(
      startY: max(
        0,
        (visibleRect.top / (tileHeight * 3.0 / 4.0)).floor() - padding,
      ),
      endY: min(
        mapData.height,
        (visibleRect.bottom / (tileHeight * 3.0 / 4.0)).ceil() + padding,
      ),
      startX: max(
        0,
        (visibleRect.left / tileWidth).floor() - padding,
      ),
      endX: min(
        mapData.width,
        (visibleRect.right / tileWidth).ceil() + padding,
      ),
    );
  }

  /// Zeichnet einen benannten Tile-Layer mit effizientem Viewport-Culling.
  ///
  /// Die sichtbaren Tile-Koordinaten werden aus [viewportTiles] übernommen,
  /// das in [paint] einmal pro Frame berechnet wird. Dadurch sinkt die Anzahl
  /// der Iterationen von `mapWidth × mapHeight` auf die tatsächlich sichtbaren
  /// Tiles (z. B. ~50 statt 10.000 bei großen Karten).
  ///
  /// Zusätzlich sorgt [Canvas.clipRect] in der übergeordneten `paint()`-Methode
  /// dafür, dass GPU-Ressourcen nicht für Pixel außerhalb des Viewports
  /// verschwendet werden.
  void _drawLayer(Canvas canvas, _VisibleTileRange viewportTiles, String layerName) {
    // O(1)-Lookup über den vorberechneten Index in MapData
    final layer = mapData.layerByName(layerName);
    if (layer == null) return;

    final paint = Paint();
    if (layer.opacity < 1.0) {
      paint.color = paint.color.withValues(alpha: layer.opacity);
    }

    for (int y = viewportTiles.startY; y < viewportTiles.endY; y++) {
      for (int x = viewportTiles.startX; x < viewportTiles.endX; x++) {
        final tileId = layer.tileAt(x, y);
        if (tileId == 0) continue;

        final pixel = _pixelPositions[y][x];
        final tileRect = Rect.fromLTWH(
          pixel.dx,
          pixel.dy,
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

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
    // Referenzvergleich: Bei setState werden neue Maps/Objekte erzeugt
    if (identical(oldDelegate.tilesetImages, tilesetImages) &&
        identical(oldDelegate.mapData, mapData) &&
        identical(oldDelegate.hexGrid, hexGrid)) {
      return false;
    }

    // Tiefenvergleich der Tileset-Images (Schlüssel reichen, da Bilder stabil sind)
    if (oldDelegate.tilesetImages.length != tilesetImages.length) return true;
    if (!oldDelegate.tilesetImages.keys.toSet().containsAll(tilesetImages.keys)) {
      return true;
    }

    // Tiefenvergleich der Layer-Daten (Namen + Tile-Daten)
    if (oldDelegate.mapData.layers.length != mapData.layers.length) return true;
    for (int i = 0; i < mapData.layers.length; i++) {
      final oldLayer = oldDelegate.mapData.layers[i];
      final newLayer = mapData.layers[i];
      if (oldLayer.name != newLayer.name) return true;
      if (oldLayer.tileData != newLayer.tileData) return true;
    }
    // Prüfe Purpose-Änderungen (wichtig, falls Layer umbenannt wurden)
    for (int i = 0; i < mapData.layers.length; i++) {
      if (oldDelegate.mapData.layers[i].purpose != mapData.layers[i].purpose) return true;
    }

    // HexGrid-Referenz prüfen
    if (oldDelegate.hexGrid != hexGrid) return true;

    return false;
  }
}