/// Tolerante JSON-Lese-Helfer (V6).
///
/// Die Persistenz darf an einem einzelnen defekten Feld nicht scheitern:
/// Diese Funktionen werfen nie, sondern liefern bei fehlenden oder
/// abweichenden Werten den vom Aufrufer gewünschten Default.
library;

/// Liest einen ganzzahligen Wert (akzeptiert auch `double` oder numerische
/// Strings). Liefert `null`, wenn kein Zahlwert vorliegt.
int? readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Liest einen String. Liefert `null`, wenn der Wert kein String ist.
String? readString(dynamic value) => value is String ? value : null;

/// Liest einen Bool-Wert (akzeptiert `bool`, `num` und `'true'`/`'false'`).
bool? readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
    }
  }
  return null;
}

/// Liest ein Datum aus einem ISO-8601-String. Liefert `null` bei ungültigem
/// oder fehlendem Wert (statt zu werfen).
DateTime? readDateTime(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Liest eine Liste von Maps (z. B. Match-Historie); nicht-passende Einträge
/// werden verworfen statt zu werfen.
List<Map<String, dynamic>> readMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
