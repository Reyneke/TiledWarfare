import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/services/map_exceptions.dart';

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

  /// Lädt eine [maps.json]-Datei aus dem Asset-Bundle.
  ///
  /// [path] – Pfad zur maps.json-Datei (Standard: `'assets/maps/maps.json'`).
  ///
  /// Wirft [MapNotFoundException], wenn die Datei nicht gefunden wird,
  /// oder [MapParseException], wenn das JSON ungültig ist.
  static Future<MapRegistry> loadFromAsset({String path = 'assets/maps/maps.json'}) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final maps = jsonList
          .map((e) => MapMeta.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      return MapRegistry(maps: maps);
    } on FlutterError {
      throw MapNotFoundException(
        message: 'maps.json not found in assets',
        path: path,
      );
    } on FormatException catch (e) {
      throw MapParseException(
        message: 'Invalid JSON in maps.json: ${e.message}',
        path: path,
      );
    }
  }
}