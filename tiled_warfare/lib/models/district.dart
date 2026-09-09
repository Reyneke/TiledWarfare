import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Represents a neighbourhood / district (restaurant location) on the world map.
///
/// Districts are read from `assets/world/theworld.tmx` - from the object layer
/// **"Nachbarschaften"** (analogous to the sectors in `lib/models/sector.dart`).
/// Each object corresponds to one Manhattan neighbourhood with a name and
/// geometry (rectangle or polygon).
///
/// A profile may own at most one restaurant per district; the district is the
/// key used to select a savegame in `ScreenStart`.
@immutable
class District {
  /// Tiled object id.
  final int id;

  /// Name of the district (e.g. "Harlem").
  final String name;

  /// Pixel position (top-left corner, or base of polygon offsets).
  final double x;
  final double y;

  /// Width/height for rectangle districts (0 for polygon/point).
  final double width;
  final double height;

  /// Absolute polygon points (offset + object position); empty for rectangles.
  final List<({double x, double y})> points;

  const District({
    this.id = 0,
    this.name = '',
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.points = const [],
  });

  /// Returns `true` if the district is defined as a polygon.
  bool get isPolygon => points.isNotEmpty;

  /// Checks whether a pixel point lies inside the district.
  ///
  /// Polygon: ray-casting (point-in-polygon). Rectangle: axis test.
  /// Point: exact coordinate hit.
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

  /// Ray-casting algorithm for point-in-polygon tests.
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
  String toString() => 'District(id=$id, name=$name)';
}
