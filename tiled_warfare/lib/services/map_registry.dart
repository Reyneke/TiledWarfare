import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tiled_warfare/models/map_data.dart';

/// Liest [maps.json] aus, parsed sie und stellt die Liste der verfügbaren
/// Karten bereit.
///
/// Usage:
/// ```dart
/// final registry = await MapRegistry.loadFromAsset();
/// for (final map in registry.maps) {
///   print(map.title);
/// }
/// ```
class MapRegistry {
  /// Die geladenen Karten-Metadaten (unmodifiable).
  final List<MapMeta> maps;

  MapRegistry({required this.maps});

  /// Lädt [maps.json] aus dem Asset-Bundle.
  ///
  /// Wirft einen [FormatException], wenn das JSON ungültig ist,
  /// oder einen [FlutterError], wenn die Datei fehlt (z. B. Deployment-Fehler).
  static Future<MapRegistry> loadFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/maps/maps.json');
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    final maps = jsonList
        .map((e) => MapMeta.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return MapRegistry(maps: maps);
  }
}