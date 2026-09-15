import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Repräsentiert ein Enneagramm-Persönlichkeitsprofil.
///
/// Die zwölf Enneagramme basieren auf der Enneagramm-Persönlichkeitstheorie
/// (siehe https://en.wikipedia.org/wiki/Enneagram_of_Personality).
///
/// Ein Profil ist die **Wurzel** aller Persönlichkeits-Traits und gilt
/// einheitlich für Host und Personal (V9; vormals Teil von `object_host.dart`).
class EnneagramProfile {
  final String name;
  final String description;

  const EnneagramProfile(this.name, this.description);

  static const List<EnneagramProfile> all = [
    EnneagramProfile('Der Reformierte', 'Prinzipientreu, zielstrebig, perfektionistisch'),
    EnneagramProfile('Der Helfer', 'Fürsorglich, großzügig, besitzergreifend'),
    EnneagramProfile('Der Erfolgsorientierte', 'Ehrgeizig, anpassungsfähig, imagebewusst'),
    EnneagramProfile('Der Individualist', 'Kreativ, sensibel, selbstbezogen'),
    EnneagramProfile('Der Denker', 'Analytisch, zurückhaltend, geizig'),
    EnneagramProfile('Der Loyalist', 'Verantwortungsbewusst, misstrauisch, ängstlich'),
    EnneagramProfile('Der Enthusiast', 'Lebhaft, impulsiv, zerstreut'),
    EnneagramProfile('Der Herausforderer', 'Durchsetzungsfähig, beschützend, konfrontativ'),
    EnneagramProfile('Der Friedfertige', 'Ausgeglichen, bestätigend, träge'),
    EnneagramProfile('Der Stratege', 'Vorausschauend, berechnend, unnahbar'),
    EnneagramProfile('Der Beschützer', 'Mutig, territorial, stur'),
    EnneagramProfile('Der Chaot', 'Unberechenbar, kreativ, destruktiv'),
  ];

  /// Sucht ein Profil über seinen Namen.
  ///
  /// Toleranter Fallback (V6): unbekannte/leere Namen liefern das erste Profil.
  static EnneagramProfile byName(String? name) =>
      all.firstWhere((p) => p.name == name, orElse: () => all.first);

  /// Stabile, sprachunabhängige Kennung (Index in [all]) – für die Persistenz.
  int get id => all.indexOf(this);

  /// Gültiger Index für [id] (defensiv: außerhalb der Liste → 0).
  static int normalizeId(int id) => (id >= 0 && id < all.length) ? id : 0;
}

/// Deterministische Persönlichkeits-Traits eines Charakters (Domäne 0–100).
///
/// Ableitung (V9, `9_Personal.md` § 4.1):
/// `Trait = clamp(TraitBasis(Profil) + Varianz(charId, Trait), 0, 100)`
///
/// - `TraitBasis` hängt allein am Enneagramm-Profil,
/// - die Varianz (±1W20) wird **deterministisch** aus der Charakter-ID gezogen
///   (kein RNG, keine Plattformabhängigkeit),
/// - es wird **nichts** zusätzlich persistiert: die Traits sind eine reine
///   Funktion von `(personalityId, StaffData.id)`.
class PersonalityTraits {
  final int aggressiveness;
  final int riskTolerance;
  final int tacticalComplexity;
  final int helpfulness;
  final int thriftiness;
  final int vitality;
  final int morale;
  final int shadiness;

  const PersonalityTraits({
    required this.aggressiveness,
    required this.riskTolerance,
    required this.tacticalComplexity,
    required this.helpfulness,
    required this.thriftiness,
    required this.vitality,
    required this.morale,
    required this.shadiness,
  });

  /// Leitet die Traits aus [profileId] und [charId] deterministisch ab.
  factory PersonalityTraits.forProfile(int profileId, int charId) {
    final index = EnneagramProfile.normalizeId(profileId);
    int trait(String name) => _valueFor(index, charId, name);
    return PersonalityTraits(
      aggressiveness: trait('aggressiveness'),
      riskTolerance: trait('riskTolerance'),
      tacticalComplexity: trait('tacticalComplexity'),
      helpfulness: trait('helpfulness'),
      thriftiness: trait('thriftiness'),
      vitality: trait('vitality'),
      morale: trait('morale'),
      shadiness: trait('shadiness'),
    );
  }

  /// Bequemer Zugriff über das Profil-Objekt.
  factory PersonalityTraits.forPersonality(EnneagramProfile profile, int charId) =>
      PersonalityTraits.forProfile(profile.id, charId);

  /// Profil-Anteil: `(offset + (index + 1) × step) % modulo`.
  static int _basisFor(int index) =>
      (EconomyBalance.personalityTraitOffset +
              (index + 1) * EconomyBalance.personalityTraitStep) %
          EconomyBalance.personalityTraitModulo;

  /// Individuelle Varianz: `(CRC32('charId:trait') % modulo) − range`.
  static int _varianceFor(int charId, String traitName) =>
      (CRC32.compute('$charId:$traitName') %
              EconomyBalance.personalityVarianceModulo) -
          EconomyBalance.personalityVarianceRange;

  static int _valueFor(int index, int charId, String traitName) =>
      (_basisFor(index) + _varianceFor(charId, traitName)).clamp(
          EconomyBalance.personalityTraitMin, EconomyBalance.personalityTraitMax);

  @override
  String toString() => 'PersonalityTraits(aggressiveness: $aggressiveness, '
      'riskTolerance: $riskTolerance, tacticalComplexity: $tacticalComplexity, '
      'helpfulness: $helpfulness, thriftiness: $thriftiness, vitality: $vitality, '
      'morale: $morale, shadiness: $shadiness)';
}