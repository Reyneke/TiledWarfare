import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Deterministische **Teamdynamik** (V9 „Teamdynamik“): Affinitäten und
/// Spannungen zwischen den Persönlichkeiten des Personals.
///
/// Die Paar-Affinität ist eine **reine Funktion** der beiden
/// Persönlichkeits-IDs und der stabilen Charakter-IDs (`StaffData.id`) – es gibt
/// **keinen** `Random`, keine Persistenz und keinen neuen Schema-Wert. Damit ist
/// sie bei jedem Aufruf (Catch-up, UI-Vorschau, Test) identisch, symmetrisch
/// (`affinity(a, b) == affinity(b, a)`) und ohne Reihenfolge-Abhängigkeit.
///
/// Wirkung (verdrahtet in `GameClockService.attractivenessOf`/`satisfactionOf`):
/// die Ø-Affinität des Teams skaliert als kleiner Bonus/Malus auf die beiden
/// Eingangswerte des passiven Einkommens – Freundschaften heben die Stimmung,
/// Spannungen drücken sie.
class TeamDynamicsService {
  TeamDynamicsService._();

  /// Affinität eines **Paares** als diskreter Wert:
  /// `+1` = Sympathie, `0` = neutral, `−1` = Spannung.
  ///
  /// Symmetrisch (Sortierung der beiden Paar-Schlüssel) und RNG-frei. Paare mit
  /// fehlendem Profil (`personalityId < 0`, Alt-Daten) sind neutral, damit die
  /// Migration nichts an der Balance dreht.
  static int pairAffinity(StaffData a, StaffData b) {
    if (a.personalityId < 0 || b.personalityId < 0) return 0;
    final key = _pairKey(a, b);
    final bucket =
        CRC32.compute(key) % EconomyBalance.teamChemistryBucketModulo;
    if (bucket < EconomyBalance.teamChemistryPositiveBound) return 1;
    if (bucket < EconomyBalance.teamChemistryNegativeBound) return -1;
    return 0;
  }

  /// Ø-Affinität über alle **ungeordneten** Paare des Teams (`−1 … +1`).
  ///
  /// `0.0` für Teams mit weniger als zwei Charakteren (kein Paar ⇒ keine
  /// Chemie) – Einzelpersonen werden also weder belohnt noch bestraft.
  static double averageAffinity(Iterable<StaffData> staff) {
    final list = staff.toList(growable: false);
    if (list.length < 2) return 0.0;
    var sum = 0;
    var pairs = 0;
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        sum += pairAffinity(list[i], list[j]);
        pairs++;
      }
    }
    return pairs == 0 ? 0.0 : sum / pairs;
  }

  /// Zuschlag der Team-Chemie auf die **Attraktivität** (Ø-Affinität × Gewicht).
  static double attractivenessBonus(Iterable<StaffData> staff) =>
      averageAffinity(staff) * EconomyBalance.teamChemistryAttractivenessWeight;

  /// Zuschlag der Team-Chemie auf die **Zufriedenheit** (Ø-Affinität × Gewicht).
  static double satisfactionBonus(Iterable<StaffData> staff) =>
      averageAffinity(staff) * EconomyBalance.teamChemistrySatisfactionWeight;

  /// Symmetrischer Paar-Schlüssel: kleinere Kombination zuerst, damit die
  /// Reihenfolge der Übergabe das Ergebnis nicht verändert.
  static String _pairKey(StaffData a, StaffData b) {
    final first = _key(a);
    final second = _key(b);
    return first.compareTo(second) <= 0
        ? '$first|$second'
        : '$second|$first';
  }

  static String _key(StaffData s) => '${s.personalityId}:${s.id}';
}
