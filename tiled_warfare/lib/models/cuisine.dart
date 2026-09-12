import 'package:random_name_generator/random_name_generator.dart';

/// Küchen-Typ (Konzept) eines Restaurants (§ 9).
///
/// Bestimmt den Namensstamm des Personals über [zone].
enum Cuisine {
  italian,
  japanese,
  chinese,
  german,
  canadian,
  mexican;

  /// Zufallsgenerator-Zone für die Namenserzeugung des Personals.
  ///
  /// Hinweis: Die Bibliothek hat kein `Zone.mexico`; Mexikanisch nutzt `Zone.spain`.
  Zone get zone {
    switch (this) {
      case Cuisine.italian:
        return Zone.italy;
      case Cuisine.japanese:
        return Zone.japan;
      case Cuisine.chinese:
        return Zone.china;
      case Cuisine.german:
        return Zone.germany;
      case Cuisine.canadian:
        return Zone.canada;
      case Cuisine.mexican:
        return Zone.spain;
    }
  }

  /// Token-/Personal-Grafik der Küche (§ 9, Küchen-Art-Assets).
  ///
  /// Die Dateien werden von `scripts/generate_cuisine_tokens.py` erzeugt und
  /// liegen unter `assets/images/token/`. Der Name folgt dem Enum-Namen,
  /// damit Asset und Küche stabil gekoppelt bleiben.
  String get tokenImagePath => 'assets/images/token/token_cook_$name.png';

  /// Liest eine Küche aus ihrem Serialisierungs-Namen (Default: italienisch).
  static Cuisine fromName(String? name) => Cuisine.values.firstWhere(
        (c) => c.name == name,
        orElse: () => Cuisine.italian,
      );
}
