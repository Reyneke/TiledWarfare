import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

/// Repräsentiert einen Sektor auf der Karte.
///
/// Ein Sektor ist ein benannter Bereich (Rechteck oder Polygon), der über
/// die Objektebene **"Sektoren"** in Tiled definiert wird. Sektoren können
/// für gebiets-basierte Spielmechaniken verwendet werden (z. B. Spawn-Zonen,
/// Kontrollpunkte, Gefahrenzonen, Deckungsbereiche).
///
/// ## Beispiel aus Tiled
/// ```xml
/// <objectgroup name="Sektoren">
///   <object id="1" name="Sektor Nord" x="128" y="64" width="256" height="192"/>
///   <object id="2" name="Sektor Arena" type="kampfzone" x="512" y="128">
///     <polygon points="0,0 160,0 160,96 80,160 0,96"/>
///   </object>
/// </objectgroup>
/// ```
@immutable
class Sector {
  /// Name des Sektors (aus dem `name`-Attribut des Tiled-Objekts).
  final String name;

  /// Pixel-Position des Sektors (linke obere Ecke des Rechtecks bzw. Basis
  /// der Polygon-Offsets).
  final double x;
  final double y;

  /// Breite/Höhe bei Rechteck-Sektoren (0 bei Punkt/Polygon).
  final double width;
  final double height;

  /// **Absolute** Polygon-Punkte (Offset + Objekt-Position).
  ///
  /// Leer, wenn der Sektor kein Polygon ist (Rechteck oder Punkt).
  final List<({double x, double y})> points;

  /// Optionale Properties aus Tiled (z. B. `type`, `label`).
  final Map<String, dynamic> properties;

  const Sector({
    this.name = '',
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.points = const [],
    this.properties = const {},
  });

  /// Gibt `true` zurück, wenn der Sektor ein Polygon besitzt.
  bool get isPolygon => points.isNotEmpty;

  /// Gibt `true` zurück, wenn der Sektor ein Rechteck oder Punkt ist.
  bool get isRectangle => !isPolygon;

  /// Prüft, ob ein Pixel-Punkt innerhalb des Sektors liegt.
  ///
  /// - Polygon-Sektoren: Ray-Casting-Algorithmus (Punkt-in-Polygon).
  /// - Rechteck-Sektoren: Achsenparalleler Bereichstest.
  /// - Punkt-Sektoren (`width == 0 && height == 0`): Exakter Koordinatentreffer.
  bool containsPixel(Offset pixel) {
    if (isPolygon) {
      return _pointInPolygon(pixel, points);
    }
    if (width <= 0 && height <= 0) {
      return pixel.dx == x && pixel.dy == y;
    }
    return pixel.dx >= x &&
        pixel.dx <= x + width &&
        pixel.dy >= y &&
        pixel.dy <= y + height;
  }

  /// Prüft, ob ein Hex-Feld (x, y) innerhalb des Sektors liegt.
  ///
  /// Konvertiert das Hex-Zentrum in Pixel-Koordinaten und delegiert an
  /// [containsPixel].
  bool containsHex(HexGrid hexGrid, int hexX, int hexY) {
    final pixel = hexGrid.hexToPixel(x: hexX, y: hexY);
    return containsPixel(pixel);
  }

  /// Ray-Casting-Algorithmus für Punkt-in-Polygon-Tests.
  ///
  /// Zählt die Schnittpunkte eines Strahls vom Punkt nach rechts mit den
  /// Polygon-Kanten. Ungerade Anzahl → Punkt liegt im Polygon.
  static bool _pointInPolygon(
    Offset point,
    List<({double x, double y})> polygon,
  ) {
    if (polygon.length < 3) return false;
    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final intersects = ((pi.y > point.dy) != (pj.y > point.dy)) &&
          (point.dx <
              (pj.x - pi.x) * (point.dy - pi.y) / (pj.y - pi.y) + pi.x);
      if (intersects) inside = !inside;
      j = i;
    }
    return inside;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sector &&
          name == other.name &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height &&
          listEquals(points, other.points) &&
          mapEquals(properties, other.properties);

  @override
  int get hashCode => Object.hash(
      name, x, y, width, height, Object.hashAll(points), properties);
}