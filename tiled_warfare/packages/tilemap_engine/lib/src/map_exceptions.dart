/// Basis-Klasse für alle Karten-bezogenen Fehler.
///
/// Enthält eine [message] und optional den betroffenen [path] sowie
/// die [lineNumber] in der Map-Datei (für Parser-Fehler).
abstract class MapException implements Exception {
  /// Fehlermeldung (menschenlesbar).
  final String message;

  /// Pfad zur Map-Datei, falls bekannt.
  final String? path;

  /// Zeilennummer in der Map-Datei, falls bekannt (optional).
  final int? lineNumber;

  const MapException({
    required this.message,
    this.path,
    this.lineNumber,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (path != null) buffer.write(' (path: $path)');
    if (lineNumber != null) buffer.write(' line: $lineNumber');
    return buffer.toString();
  }
}

/// Fehler beim Parsen einer Map-Datei (Format-Fehler).
///
/// Wird geworfen, wenn eine TMX-/TMJ-Datei syntaktisch oder semantisch
/// ungültig ist (z. B. fehlende Elemente, falsche Kodierung, ungültige
/// Abmessungen).
class MapParseException extends MapException {
  const MapParseException({
    required super.message,
    super.path,
    super.lineNumber,
  });
}

/// Fehler beim Laden einer Map (z. B. Asset nicht gefunden).
///
/// Wird geworfen, wenn eine erforderliche Datei (TMX, TMJ, TSX,
/// Tileset-Bild) nicht im Asset-Bundle existiert.
class MapNotFoundException extends MapException {
  const MapNotFoundException({
    required super.message,
    super.path,
  });
}

/// Allgemeiner Lade-Fehler beim Verarbeiten einer Map.
///
/// Wird geworfen bei Fehlern, die nicht durch fehlende Assets oder
/// Format-Probleme abgedeckt sind (z. B. Codec-Fehler bei Bildern,
/// Netzwerk-Fehler bei zukünftigen Remote-Maps).
class MapLoadException extends MapException {
  /// Ursprüngliche Exception (falls vorhanden).
  final Object? originalError;

  const MapLoadException({
    required super.message,
    super.path,
    this.originalError,
  });
}