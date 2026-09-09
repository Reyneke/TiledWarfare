import 'package:tiled_warfare/models/district.dart';
import 'package:tiled_warfare/services/map_parser.dart';

/// Standard name of the "Nachbarschaften" object layer in Tiled.
const String kDistrictGroupName = 'Nachbarschaften';

/// Asset path of the world map that defines the districts (locations).
const String kWorldMapAssetPath = 'assets/world/theworld.tmx';

/// Loads the districts (restaurant locations) from the world map.
///
/// The districts are Manhattan neighbourhoods from the **"Nachbarschaften"**
/// object layer in `theworld.tmx` (rectangles/polygons). The list is global:
/// it belongs to the asset, not to profile or restaurant data.
///
/// Throws a map exception (see `map_exceptions.dart`) if the world map cannot
/// be loaded or parsed.
class DistrictService {
  /// Loads and parses the district list from [path].
  ///
  /// Returns an empty list if the object layer is missing.
  static Future<List<District>> loadDistricts({
    String path = kWorldMapAssetPath,
  }) async {
    final parser = TmxParser();
    final mapData = await parser.loadFromAsset(path);

    final index = mapData.objectGroups
        .indexWhere((g) => g.name == kDistrictGroupName);
    if (index < 0) return const [];
    final group = mapData.objectGroups[index];

    return [
      for (final obj in group.objects)
        District(
          id: obj.id,
          name: obj.name,
          x: obj.x,
          y: obj.y,
          width: obj.width,
          height: obj.height,
          points: obj.absolutePoints,
        ),
    ];
  }
}
