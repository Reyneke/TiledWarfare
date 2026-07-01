import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:xml/xml.dart';

/// Lädt die Karte "street_battle.tmx" aus dem "assets" Ordner und zeigt sie an.
class WidgetMapLoader extends StatefulWidget {
  const WidgetMapLoader({super.key});

  @override
  State<WidgetMapLoader> createState() => _WidgetMapLoaderState();
}

class _WidgetMapLoaderState extends State<WidgetMapLoader> {
  ui.Image? _tilesetImage;
  List<List<int>>? _tileData;
  int _mapWidth = 30;
  int _mapHeight = 30;
  int _tileWidth = 32;
  int _tileHeight = 32;
  final int _tilesetColumns = 16;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    try {
      // TMX-Datei laden und parsen
      final tmxString = await rootBundle.loadString('assets/maps/street_battle.tmx');
      final document = XmlDocument.parse(tmxString);
      final mapElement = document.findElements('map').first;

      _mapWidth = int.parse(mapElement.getAttribute('width') ?? '30');
      _mapHeight = int.parse(mapElement.getAttribute('height') ?? '30');
      _tileWidth = int.parse(mapElement.getAttribute('tilewidth') ?? '32');
      _tileHeight = int.parse(mapElement.getAttribute('tileheight') ?? '32');

      // Tile-Layer-Daten parsen
      final layer = mapElement.findElements('layer').first;
      final dataElement = layer.findElements('data').first;
      final csvData = dataElement.innerText.trim();
      final tileIds = csvData
          .split(',')
          .map((s) => int.parse(s.trim()))
          .toList();

      final tileData = <List<int>>[];
      for (int y = 0; y < _mapHeight; y++) {
        final row = <int>[];
        for (int x = 0; x < _mapWidth; x++) {
          row.add(tileIds[y * _mapWidth + x]);
        }
        tileData.add(row);
      }
      _tileData = tileData;

      // Tileset-Bild laden
      final byteData = await rootBundle.load('assets/maps/Thespazztikone_tilemaps_005_neu.png');
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      _tilesetImage = frameInfo.image;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

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

    if (_tilesetImage == null || _tileData == null) {
      return const Center(child: Text('Keine Kartendaten geladen.'));
    }

    // Berechne die Größe der hexagonalen Karte
    // Bei staggeraxis="y" (pointy-topped hexagons):
    // Breite = columns * tileWidth + tileWidth / 2
    // Höhe = rows * (tileHeight * 3/4) + tileHeight / 4
    final mapPixelWidth = _mapWidth * _tileWidth + _tileWidth ~/ 2;
    final mapPixelHeight = (_mapHeight * _tileHeight * 3 ~/ 4) + _tileHeight ~/ 4;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SizedBox(
          width: mapPixelWidth.toDouble(),
          height: mapPixelHeight.toDouble(),
          child: CustomPaint(
            painter: _HexMapPainter(
              tilesetImage: _tilesetImage!,
              tileData: _tileData!,
              mapWidth: _mapWidth,
              mapHeight: _mapHeight,
              tileWidth: _tileWidth,
              tileHeight: _tileHeight,
              tilesetColumns: _tilesetColumns,
            ),
          ),
        ),
      ),
    );
  }
}

class _HexMapPainter extends CustomPainter {
  final ui.Image tilesetImage;
  final List<List<int>> tileData;
  final int mapWidth;
  final int mapHeight;
  final int tileWidth;
  final int tileHeight;
  final int tilesetColumns;

  _HexMapPainter({
    required this.tilesetImage,
    required this.tileData,
    required this.mapWidth,
    required this.mapHeight,
    required this.tileWidth,
    required this.tileHeight,
    required this.tilesetColumns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int y = 0; y < mapHeight; y++) {
      for (int x = 0; x < mapWidth; x++) {
        final tileId = tileData[y][x];
        if (tileId == 0) continue; // Leeres Tile überspringen

        // Berechne Position im Tileset (tileId - 1, da firstgid=1)
        final tilesetIndex = tileId - 1;
        final tilesetX = (tilesetIndex % tilesetColumns) * tileWidth;
        final tilesetY = (tilesetIndex ~/ tilesetColumns) * tileHeight;

        // Berechne Pixel-Position auf der Karte
        // Hexagonales Gitter mit staggeraxis="y", staggerindex="odd"
        final double pixelX;
        final double pixelY;

        if (y % 2 == 1) {
          // Ungerade Zeilen sind nach rechts versetzt
          pixelX = (x * tileWidth).toDouble() + tileWidth / 2;
        } else {
          pixelX = (x * tileWidth).toDouble();
        }
        pixelY = y * (tileHeight * 3.0 / 4.0);

        // Source-Rechteck im Tileset
        final srcRect = Rect.fromLTWH(
          tilesetX.toDouble(),
          tilesetY.toDouble(),
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

        // Destination-Rechteck auf der Karte
        final dstRect = Rect.fromLTWH(
          pixelX,
          pixelY,
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

        // Tile zeichnen
        canvas.drawImageRect(
          tilesetImage,
          srcRect,
          dstRect,
          Paint(),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexMapPainter oldDelegate) {
    return oldDelegate.tilesetImage != tilesetImage ||
        oldDelegate.tileData != tileData;
  }
}