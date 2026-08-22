/// Tilemap Engine – entkoppelte Tilemap-Engine für Tiled-Karten (TMX/TMJ).
///
/// Bietet:
/// - [MapParser] / [TmxParser] / [TmjParser] – robustes Parsen von TMX/TMJ
/// - [MapData] / [TileLayer] / [ObjectGroup] – Datenmodelle
/// - [HexGrid] – zentralisierte Hex-Utility
/// - [MapException] & Ableitungen – spezifische Fehlerbehandlung
library;

export 'src/hex_grid.dart';
export 'src/hex_map_view.dart';
export 'src/map_data.dart';
export 'src/map_exceptions.dart';
export 'src/map_parser.dart';
