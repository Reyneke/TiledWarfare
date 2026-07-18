/// Ergebnis eines Matches.
enum MatchResult { win, loss, draw }

/// Ein einzelner Match-Eintrag in der Historie eines Charakters.
///
/// Enthält Datum, Gegner, Ergebnis, Kills/Deaths sowie optionale
/// Notizen zu besonderen Ereignissen.
class MatchRecord {
  /// Datum und Uhrzeit des Matches.
  final DateTime date;

  /// Name des Gegners.
  final String opponentName;

  /// Ergebnis des Matches (Sieg/Niederlage/Unentschieden).
  final MatchResult result;

  /// Anzahl der Kills in diesem Match.
  final int kills;

  /// Anzahl der Deaths in diesem Match.
  final int deaths;

  /// Optionale Notizen (z. B. besondere Ereignisse).
  final String? notes;

  const MatchRecord({
    required this.date,
    required this.opponentName,
    required this.result,
    this.kills = 0,
    this.deaths = 0,
    this.notes,
  });

  /// Kill/Death-Ratio (0.0 wenn keine Deaths).
  double get kdRatio => deaths == 0 ? kills.toDouble() : kills / deaths;

  /// JSON-Serialisierung.
  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'opponentName': opponentName,
        'result': result.name,
        'kills': kills,
        'deaths': deaths,
        if (notes != null) 'notes': notes,
      };

  /// JSON-Deserialisierung.
  factory MatchRecord.fromJson(Map<String, dynamic> json) => MatchRecord(
        date: DateTime.parse(json['date'] as String),
        opponentName: json['opponentName'] as String,
        result: MatchResult.values.firstWhere(
          (e) => e.name == json['result'],
          orElse: () => MatchResult.draw,
        ),
        kills: json['kills'] as int? ?? 0,
        deaths: json['deaths'] as int? ?? 0,
        notes: json['notes'] as String?,
      );

  @override
  String toString() =>
      'MatchRecord($opponentName, ${result.name}, $kills/$deaths)';
}