import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'hex_grid.dart';
import 'map_data.dart';

/// Signatur für eine Token-Zeichen-Funktion im [HexMapView].
///
/// Wird pro Token aufgerufen, nachdem der Canvas auf das Zentrum des
/// Token-Hex-Feldes transformiert wurde. Die Zeichnung erfolgt in
/// Pixel-Koordinaten relativ zu diesem Zentrum.
typedef TokenPainter = void Function(Canvas canvas, Offset center);

/// Entkoppelter Renderer für Hex-Karten auf Basis von [MapData] und [HexGrid].
///
/// Zeichnet die Tile-Layer der Karte mithilfe eines Tileset-Bildes und ist
/// bewusst **frei von spielspezifischem Token-Code**: Tokens werden über den
/// generischen [tokenPainter]-Callback gezeichnet, der vom Nutzer bereitgestellt
/// wird.
///
/// ## Beispiel
/// ```dart
/// HexMapView(
///   map: mapData,
///   hexGrid: hexGrid,
///   tilesetImage: tilesetImage,
///   tokens: [
///     HexTokenFigure(position: myToken.position, painter: myPainter),
///   ],
/// )
/// ```
class HexMapView extends StatelessWidget {
  /// Die zu zeichnende Karte (geparste TMX/TMJ-Daten).
  final MapData map;

  /// Die Hex-Utility für Pixel↔Hex-Konvertierung und Karten-Dimensionen.
  final HexGrid hexGrid;

  /// Das dekodierte Tileset-Bild. Wenn `null`, wird ein Farb-Fallback verwendet.
  final ui.Image? tilesetImage;

  /// Liste der sichtbaren Token-Figuren auf der Karte.
  final List<HexTokenFigure> tokens;

  /// Ausgewählte Hex-Koordinate (optional, wird hervorgehoben).
  final ({int x, int y})? selectedHex;

  /// Callback bei Tap auf ein Hex-Feld.
  final void Function(int x, int y)? onTileTap;

  const HexMapView({
    super.key,
    required this.map,
    required this.hexGrid,
    this.tilesetImage,
    this.tokens = const [],
    this.selectedHex,
    this.onTileTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (onTileTap == null) return;
        final hex = hexGrid.pixelToHex(details.localPosition);
        onTileTap?.call(hex.x, hex.y);
      },
      child: CustomPaint(
        size: Size(
          hexGrid.mapPixelWidth.toDouble(),
          hexGrid.mapPixelHeight.toDouble(),
        ),
        painter: _HexMapPainter(
          map: map,
          hexGrid: hexGrid,
          tilesetImage: tilesetImage,
          tokens: tokens,
          selectedHex: selectedHex,
        ),
      ),
    );
  }
}

/// Eine einzelne Token-Figur, die auf der Karte gezeichnet werden soll.
///
/// [position] ist die Pixel-Position des Tokens auf der Karte,
/// [painter] zeichnet den Token im lokalen Koordinatensystem um [position].
class HexTokenFigure {
  /// Pixel-Position des Tokens auf der Karte.
  final Offset position;

  /// Zeichen-Funktion für den Token.
  final TokenPainter painter;

  const HexTokenFigure({required this.position, required this.painter});
}

/// CustomPainter, der die Karte rendert.
class _HexMapPainter extends CustomPainter {
  final MapData map;
  final HexGrid hexGrid;
  final ui.Image? tilesetImage;
  final List<HexTokenFigure> tokens;
  final ({int x, int y})? selectedHex;

  _HexMapPainter({
    required this.map,
    required this.hexGrid,
    required this.tilesetImage,
    required this.tokens,
    required this.selectedHex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Hexagon-Pfad (pointy-top) einmal aufbauen und wiederverwenden.
    final hexPath = _buildHexPath();

    final tilePaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black45;

    // Fallback-Farben, falls kein Tileset-Bild vorhanden ist.
    const fallbackColors = {
      0: Color(0xFF2D2D2D),
      73: Color(0xFF4A7C4F),
    };

    for (int row = 0; row < map.height; row++) {
      for (int col = 0; col < map.width; col++) {
        final center = hexGrid.hexToPixel(x: col, y: row);
        final gid = _tileGidAt(col, row);

        canvas.save();
        canvas.translate(center.dx, center.dy);

        if (tilesetImage != null && gid != 0 && map.tilesets.isNotEmpty) {
          final tileset = map.tilesets.first;
          if (tileset.tileWidth != null &&
              tileset.tileHeight != null &&
              tileset.columns != null &&
              tileset.imageSource != null) {
            final localId = gid - tileset.firstGid;
            if (localId >= 0) {
              final srcCol = localId % tileset.columns!;
              final srcRow = localId ~/ tileset.columns!;
              final sw = tileset.tileWidth!.toDouble();
              final sh = tileset.tileHeight!.toDouble();
              canvas.clipPath(hexPath);
              canvas.drawImageRect(
                tilesetImage!,
                Rect.fromLTWH(
                  srcCol * sw,
                  srcRow * sh,
                  sw,
                  sh,
                ),
                Rect.fromCenter(
                  center: Offset.zero,
                  width: sw,
                  height: sh,
                ),
                Paint(),
              );
            } else {
              _drawFallback(canvas, hexPath, tilePaint, fallbackColors, gid);
            }
          } else {
            _drawFallback(canvas, hexPath, tilePaint, fallbackColors, gid);
          }
        } else {
          _drawFallback(canvas, hexPath, tilePaint, fallbackColors, gid);
        }

        final isSelected = selectedHex?.x == col && selectedHex?.y == row;
        if (isSelected) {
          final selPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.amber.withValues(alpha: 100);
          canvas.drawPath(hexPath, selPaint);
        }

        canvas.drawPath(hexPath, borderPaint);
        canvas.restore();
      }
    }

    // Tokens zeichnen.
    for (final token in tokens) {
      final center = token.position;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      token.painter(canvas, Offset.zero);
      canvas.restore();
    }
  }

  /// Ermittelt die Tile-GID an Position (col, row) aus dem ersten
  /// nicht-leeren Tile-Layer. Fällt auf 0 zurück, wenn keine Layer existieren.
  int _tileGidAt(int col, int row) {
    for (final layer in map.layers) {
      if (!layer.visible) continue;
      final gid = layer.tileAt(col, row);
      if (gid != 0) return gid;
    }
    return 0;
  }

  void _drawFallback(
    Canvas canvas,
    Path hexPath,
    Paint tilePaint,
    Map<int, Color> fallbackColors,
    int gid,
  ) {
    tilePaint.color = fallbackColors[gid] ?? const Color(0xFF6B8E6B);
    canvas.drawPath(hexPath, tilePaint);
  }

  Path _buildHexPath() {
    final hexSize = math.min(
      hexGrid.tileWidth,
      hexGrid.tileHeight,
    ).toDouble() /
        2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 180) * (90 - 60 * i);
      final px = hexSize * math.cos(angle);
      final py = hexSize * math.sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexMapPainter oldDelegate) {
    return oldDelegate.map != map ||
        oldDelegate.hexGrid != hexGrid ||
        oldDelegate.tilesetImage != tilesetImage ||
        oldDelegate.selectedHex != selectedHex ||
        !identical(oldDelegate.tokens, tokens);
  }
}