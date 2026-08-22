/// Re-Export der Karten-Datenmodelle aus der entkoppelten Engine.
///
/// Die eigentliche Implementierung der Engine-Modelle (z. B. [MapData],
/// [TileLayer], [ObjectGroup], [TerrainType] usw.) lebt in
/// `packages/tilemap_engine` (Paket `tilemap_engine`) und wird hier für die
/// bestehende Codestruktur von TiledWarfare weiterhin unter dem gewohnten
/// Pfad bereitgestellt.
///
/// Die Klasse [MapMeta] ist **spielspezifisch** (Metadaten aus der
/// `maps.json`) und bleibt hier lokal definiert.
library;

import 'package:flutter/foundation.dart';

export 'package:tilemap_engine/tilemap_engine.dart'
    show
        LayerPurpose,
        MapData,
        MapObject,
        MapOrientation,
        ObjectGroup,
        TerrainConfig,
        TerrainType,
        TileLayer,
        TilesetInfo;

/// Metadaten einer Karte aus der `maps.json`.
///
/// Enthält den Anzeigenamen, den Pfad zur TMX-Datei und optional
/// ein Vorschaubild für die Kartenauswahl.
@immutable
class MapMeta {
  /// Ordner-Pfad (z. B. "assets/maps/map0").
  final String mapPath;

  /// Anzeigename der Karte (z. B. "Street Battle").
  final String title;

  /// Optionaler Pfad zu einem Vorschaubild (z. B. "assets/maps/map0/preview.png").
  final String? previewPath;

  /// Pfad zur .tmx/.tmj-Datei (z. B. "assets/maps/map0/street_battle.tmx").
  final String tmxPath;

  const MapMeta({
    required this.mapPath,
    required this.title,
    this.previewPath,
    required this.tmxPath,
  });

  factory MapMeta.fromJson(Map<String, dynamic> json) => MapMeta(
        mapPath: json['mapPath'] as String,
        title: json['title'] as String,
        previewPath: json['previewPath'] as String?,
        tmxPath: json['tmxPath'] as String,
      );

  Map<String, dynamic> toJson() => {
        'mapPath': mapPath,
        'title': title,
        'previewPath': previewPath,
        'tmxPath': tmxPath,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapMeta &&
          mapPath == other.mapPath &&
          title == other.title &&
          previewPath == other.previewPath &&
          tmxPath == other.tmxPath;

  @override
  int get hashCode => Object.hash(mapPath, title, previewPath, tmxPath);
}