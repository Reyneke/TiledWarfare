/// Re-Export der zentralen Hex-Utility aus der entkoppelten Engine.
///
/// Die eigentliche Implementierung lebt in `packages/tilemap_engine`
/// (Paket `tilemap_engine`) und wird hier für die bestehende Codestruktur
/// von TiledWarfare weiterhin unter dem gewohnten Pfad bereitgestellt.
library;

export 'package:tilemap_engine/tilemap_engine.dart' show HexGrid;