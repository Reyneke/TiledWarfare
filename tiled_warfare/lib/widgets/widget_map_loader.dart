import 'dart:collection';
import 'dart:math' show max, min, sqrt;

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
  /// Name der Objektgruppe für Spawnpunkte.
  final String spawnGroupName;

  /// Steuert, ob das `visible`-Flag von Tiled-Layern respektiert wird.
  ///
  /// - `true` (Default): Layer mit `visible = false` in Tiled werden nicht
  ///   gezeichnet. Mapper können Layer gezielt ausblenden.
  /// - `false`: Das `visible`-Flag wird ignoriert – alle Layer werden
  ///   gezeichnet, unabhängig vom Tiled-Status. Nützlich, wenn Layer zur
  ///   Laufzeit dynamisch ein-/ausgeblendet werden sollen.
  final bool respectLayerVisibility;

  /// Benutzerdefinierte Zuordnung von [LayerPurpose] zu Layer-Namen.
  ///
  /// Überschreibt die Standard-Namen aus [LayerPurpose.defaultLayerNames].
  /// Nur die angegebenen Zweige werden überschrieben; nicht aufgeführte
  /// Zweige verwenden weiterhin die Standard-Namen.
  ///
  /// Beispiel:
  /// ```dart
  /// MapLoadConfig(layerNameOverrides: {
  ///   LayerPurpose.ground: 'my_ground',
  ///   LayerPurpose.decorative: 'my_deco',
  /// })
  /// ```
  final Map<LayerPurpose, String> layerNameOverrides;

  /// Erstellt die effektive Namenstabelle: Standard + Overrides.
  Map<LayerPurpose, String> get effectiveLayerNames {
    final result = Map<LayerPurpose, String>.from(
      LayerPurpose.defaultLayerNames,
    );
    result.addAll(layerNameOverrides);
    return result;
  }

  /// Gibt den konfigurierten Layer-Namen für einen [LayerPurpose] zurück.
  String layerNameFor(LayerPurpose purpose) {
    return effectiveLayerNames[purpose] ??
        LayerPurpose.defaultLayerNames[purpose]!;
  }

  const MapLoadConfig({
    this.spawnGroupName = 'Spawns',
    this.respectLayerVisibility = true,
    this.layerNameOverrides = const {},
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
  ///
  /// LRU-Cache (max. [kMaxTilesetImages] Einträge): Beim Kartenwechsel
  /// werden zuletzt genutzte Bilder behalten, damit identische Tilesets
  /// nicht erneut dekodiert werden müssen.
  static const int kMaxTilesetImages = 5;

  final LinkedHashMap<int, ({ui.Image image, int columns})> _tilesetImages =
      LinkedHashMap<int, ({ui.Image image, int columns})>();

  /// Die geladenen Kartendaten.
  MapData? _mapData;

  int _mapWidth = 30;
  int _mapHeight = 30;
  int _tileWidth = 32;
  int _tileHeight = 32;
  bool _isLoading = true;

  /// Fehlermeldung und -typ getrennt speichern (kein string-basierter Typabgleich).
  String? _error;
  _MapErrorType? _errorType;

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
    _disposeTilesetImages();
    super.dispose();
  }

  /// Disposed Tileset-Bilder, die über das LRU-Limit hinausgehen.
  ///
  /// Beim Kartenwechsel wird die Map geleert und neu befüllt. Damit
  /// identische Tilesets (z. B. beide Karten verwenden dasselbe Bild)
  /// nicht erneut dekodiert werden müssen, bleiben die zuletzt
  /// verwendeten Bilder im Cache erhalten.
  void _disposeTilesetImages() {
    // Alle Bilder disposen (Kartenwechsel → keine Referenzen mehr gehalten)
    for (final entry in _tilesetImages.values) {
      entry.image.dispose();
    }
    _tilesetImages.clear();
  }

  /// Fügt ein Tileset-Bild in den LRU-Cache ein.
  ///
  /// Wenn das Limit [kMaxTilesetImages] überschritten wird, wird das
  /// älteste (zuletzt am wenigsten verwendete) Bild disposet und entfernt.
  void _putTilesetImage(int firstGid, ({ui.Image image, int columns}) entry) {
    // Bereits vorhanden → aktualisieren und an das Ende verschieben
    if (_tilesetImages.containsKey(firstGid)) {
      _tilesetImages.remove(firstGid);
    }

    _tilesetImages[firstGid] = entry;

    // LRU-Eviction: Ältestes Bild disposen, wenn Limit überschritten
    while (_tilesetImages.length > kMaxTilesetImages) {
      final oldestKey = _tilesetImages.keys.first;
      final oldest = _tilesetImages.remove(oldestKey);
      oldest?.image.dispose();
    }
  }

  // ──────────────────────────────────────────────
  // Karten-Ladevorgang
  // ──────────────────────────────────────────────

  Future<void> _loadMap() async {
    try {
      _disposeTilesetImages();

      final parser = MapParser.forPath(
        widget.mapPath,
        assetBundle: rootBundle,
      );

      final mapData = await parser.loadFromAsset(widget.mapPath);
      _mapData = mapData;

      // Laufzeit-Validierung: Ground-Layer ist Pflicht
      final groundLayer = mapData.layerByPurpose(LayerPurpose.ground);
      if (groundLayer == null) {
        throw MapParseException(
          message: 'Map has no "ground" layer. '
              'The layer named "ground" (or your custom ground layer name) is required '
              'for the map to be rendered correctly.',
          path: widget.mapPath,
        );
      }

      // Laufzeit-Validierung: Spawn-Gruppe sollte existieren (nur Warnung)
      final hasSpawns = mapData.objectGroups
          .any((g) => g.name == widget.config.spawnGroupName && g.objects.isNotEmpty);
      if (!hasSpawns) {
        debugPrint('Warning: Map "${widget.mapPath}" has no spawn points '
            'in object group "${widget.config.spawnGroupName}". '
            'Players will not be able to spawn.');
      }

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
        _error = null;
        _errorType = null;
      });
    } on MapParseException catch (e) {
      _setErrorState('Kartenformat-Fehler: $e', _MapErrorType.parseError);
    } on MapNotFoundException catch (e) {
      _setErrorState('Karte nicht gefunden: $e', _MapErrorType.notFound);
    } on FormatException catch (e) {
      _setErrorState('Formatfehler: ${e.message}', _MapErrorType.parseError);
    } on FlutterError catch (e) {
      _setErrorState('Asset-Fehler: ${e.message}', _MapErrorType.notFound);
    } catch (e) {
      _setErrorState('Unbekannter Fehler: $e', _MapErrorType.unknown);
    }
  }

  /// Zentrale Methode zum Setzen von Fehlerzuständen.
  void _setErrorState(String message, _MapErrorType type) {
    setState(() {
      _error = message;
      _errorType = type;
      _isLoading = false;
    });
  }

  /// Startet einen erneuten Ladeversuch (für Retry-/Fallback-Buttons).
  void _retryLoad() {
    setState(() {
      _error = null;
      _errorType = null;
      _isLoading = true;
    });
    _loadMap();
  }

  // ──────────────────────────────────────────────
  // Tileset-Bilder laden
  // ──────────────────────────────────────────────

  Future<void> _loadTilesetImages(MapData mapData, String basePath) async {
    for (final tileset in mapData.tilesets) {
      // Externes Tileset (TSX): imageSource nachladen
      String? imageSource = tileset.imageSource;
      if (imageSource == null && tileset.source != null) {
        imageSource = await _resolveExternalTilesetSource(
          tileset.source!,
          basePath,
        );
      }

      final imagePath = imageSource != null
          ? '$basePath/$imageSource'
          : null;
      if (imagePath == null) continue;

      await _loadSingleTilesetImage(tileset.firstGid, imagePath, tileset.columns);
    }
  }

  /// Lädt die Bildquelle eines externen TSX-Tilesets.
  Future<String?> _resolveExternalTilesetSource(
    String source,
    String basePath,
  ) async {
    try {
      final tsxPath = '$basePath/$source';
      final tsxContent = await rootBundle.loadString(tsxPath);
      final tsxDoc = XmlDocument.parse(tsxContent);
      final tsxTileset = tsxDoc.findElements('tileset').first;
      final imageElement = tsxTileset.findElements('image').firstOrNull;
      return imageElement?.getAttribute('source');
    } catch (e) {
      debugPrint('Warning: Could not load external tileset: $source ($e)');
      return null;
    }
  }

  /// Lädt ein einzelnes Tileset-Bild und speichert es im LRU-Cache.
  Future<void> _loadSingleTilesetImage(
    int firstGid,
    String imagePath,
    int? columns,
  ) async {
    try {
      final byteData = await rootBundle.load(imagePath);
      final codec =
          await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      _putTilesetImage(firstGid, (
        image: frameInfo.image,
        columns: columns ?? 16,
      ));
    } on FlutterError catch (e) {
      debugPrint('Warning: Tileset image not found: $imagePath ($e.message)');
    } on FormatException catch (e) {
      debugPrint('Warning: Corrupted tileset image: $imagePath ($e.message)');
    } catch (e) {
      debugPrint('Warning: Could not load tileset image: $imagePath ($e)');
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
      return _buildErrorWidget();
    }

    if (_tilesetImages.isEmpty || _mapData == null) {
      return const Center(child: Text('Keine Kartendaten geladen.'));
    }

    // Berechne die Größe der hexagonalen Karte mittels zentraler HexGrid-Utility
    final mapPixelWidth = widget.hexGrid.mapPixelWidth;
    final mapPixelHeight = widget.hexGrid.mapPixelHeight;

    // Keine boundaryMargin: Der InteractiveViewer darf nicht in weiße
    // Bereiche scrollen. Die Karte wird durch _centerMap() zentriert.
    // boundaryMargin = 0 verhindert den weißen Balken unten.
    return RepaintBoundary(
      child: InteractiveViewer(
        transformationController: _transformationController,
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
            ),
          ),
        ),
      ),
    );
  }

  /// Baut die Fehler-UI basierend auf dem gespeicherten Fehlertyp.
  Widget _buildErrorWidget() {
    final errorType = _errorType ?? _MapErrorType.unknown;
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
                    onPressed: _retryLoad,
                  ),
                if (errorType == _MapErrorType.notFound)
                  FilledButton.icon(
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Fallback-Karte laden'),
                    onPressed: _retryLoad,
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
}

/// Ermittelt das passende Tileset für eine Tile-ID anhand des firstGid-Bereichs.
///
/// Durchläuft die Tileset-Liste rückwärts, da Tilesets mit höherem firstGid
/// später in der Liste stehen und zuerst matchen sollen.
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

  /// Vorberechnete effektive Layer-Namenszuordnung aus der Konfiguration.
  final Map<LayerPurpose, String> _effectiveNames;

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
  })  : _effectiveNames = config.effectiveLayerNames,
        _pixelPositions = _computePositions(mapData, hexGrid);

  /// Berechnet alle Pixel-Positionen einmal vor, statt sie jedes Frame neu zu berechnen.
  static List<List<Offset>> _computePositions(
    MapData mapData,
    HexGrid hexGrid,
  ) {
    return List.generate(
      mapData.height,
      (y) => List.generate(
        mapData.width,
        (x) => hexGrid.hexToPixel(x: x, y: y),
      ),
    );
  }

  /// Gibt die Layer zum Zeichnen in der richtigen Reihenfolge zurück.
  ///
  /// Berücksichtigt die [MapLoadConfig.respectLayerVisibility]-Einstellung:
  /// - Wenn `true` (Default): Layer mit `visible = false` in Tiled werden
  ///   nicht gezeichnet.
  /// - Wenn `false`: Alle Layer werden gezeichnet, unabhängig vom `visible`-Flag.
  Iterable<TileLayer> _getVisibleLayers() sync* {
    final ground = _layerByPurpose(LayerPurpose.ground);
    if (ground != null && _isLayerVisible(ground)) yield ground;

    final decor = _layerByPurpose(LayerPurpose.decorative);
    if (decor != null && _isLayerVisible(decor)) yield decor;

    final decorUpper = _layerByPurpose(LayerPurpose.decorativeUpper);
    if (decorUpper != null && _isLayerVisible(decorUpper)) yield decorUpper;
  }

  /// Prüft, ob ein Layer gezeichnet werden soll.
  /// Berücksichtigt die [config.respectLayerVisibility]-Konfiguration.
  bool _isLayerVisible(TileLayer layer) {
    if (!config.respectLayerVisibility) return true;
    return layer.visible;
  }

  /// Findet einen Layer anhand des Purpose unter Berücksichtigung
  /// der benutzerdefinierten Namenszuordnung.
  TileLayer? _layerByPurpose(LayerPurpose purpose) {
    final name = _effectiveNames[purpose];
    if (name == null) return null;
    return mapData.layerByName(name);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visibleRect = Offset.zero & size;

    // Clip auf sichtbaren Bereich, damit die GPU keine Pixel außerhalb rendert
    canvas.save();
    canvas.clipRect(visibleRect);

    // Sichtbaren Tile-Bereich einmal berechnen
    final viewportTiles = _computeVisibleTileRange(visibleRect);

    try {
      // Alle sichtbaren Layer in der richtigen Reihenfolge zeichnen
      for (final layer in _getVisibleLayers()) {
        _drawLayer(canvas, viewportTiles, layer);
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

  /// Zeichnet einen [TileLayer] mit effizientem Viewport-Culling.
  ///
  /// Die sichtbaren Tile-Koordinaten werden aus [viewportTiles] übernommen,
  /// das in [paint] einmal pro Frame berechnet wird. Dadurch sinkt die Anzahl
  /// der Iterationen von `mapWidth × mapHeight` auf die tatsächlich sichtbaren
  /// Tiles (z. B. ~50 statt 10.000 bei großen Karten).
  ///
  /// Zusätzlich sorgt [Canvas.clipRect] in der übergeordneten `paint()`-Methode
  /// dafür, dass GPU-Ressourcen nicht für Pixel außerhalb des Viewports
  /// verschwendet werden.
  void _drawLayer(
    Canvas canvas,
    _VisibleTileRange viewportTiles,
    TileLayer layer,
  ) {
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
        identical(oldDelegate.hexGrid, hexGrid) &&
        identical(oldDelegate.config, config)) {
      return false;
    }

    // Tiefenvergleich der Tileset-Images (Schlüssel reichen, da Bilder stabil sind)
    if (oldDelegate.tilesetImages.length != tilesetImages.length) return true;
    if (!oldDelegate.tilesetImages.keys.toSet().containsAll(tilesetImages.keys)) {
      return true;
    }

    // Tiefenvergleich der Layer-Daten nur bei unterschiedlichen Referenzen nötig
    if (!identical(oldDelegate.mapData, mapData)) {
      if (oldDelegate.mapData.layers.length != mapData.layers.length) return true;
      for (int i = 0; i < mapData.layers.length; i++) {
        final oldLayer = oldDelegate.mapData.layers[i];
        final newLayer = mapData.layers[i];
        if (oldLayer.name != newLayer.name) return true;
        if (oldLayer.visible != newLayer.visible) return true;
        if (oldLayer.tileData != newLayer.tileData) return true;
      }
    }

    return false;
  }
}