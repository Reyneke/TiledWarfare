import 'package:tiled_warfare/fuzzy_logic/lib/fuzzylogic.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Fuzzy-Variable für die Restaurant-Attraktivität (Domäne 0–4).
class _Attractiveness extends FuzzyVariable<double> {
  final niedrig = FuzzySet.LeftShoulder(0.0, 0.75, 2.0, 'Niedrig');
  final mittel = FuzzySet.Triangle(0.75, 2.0, 3.25, 'Mittel');
  final hoch = FuzzySet.RightShoulder(2.0, 3.25, 4.0, 'Hoch');

  _Attractiveness() {
    sets = [niedrig, mittel, hoch];
    name = 'Attraktivität';
    init();
  }
}

/// Fuzzy-Variable für die Kundenzufriedenheit (Domäne 0–4).
class _Satisfaction extends FuzzyVariable<double> {
  final niedrig = FuzzySet.LeftShoulder(0.0, 0.75, 2.0, 'Niedrig');
  final mittel = FuzzySet.Triangle(0.75, 2.0, 3.25, 'Mittel');
  final hoch = FuzzySet.RightShoulder(2.0, 3.25, 4.0, 'Hoch');

  _Satisfaction() {
    sets = [niedrig, mittel, hoch];
    name = 'Kundenzufriedenheit';
    init();
  }
}

/// Fuzzy-Variable für die Kapazität (Domäne 0–20).
class _Capacity extends FuzzyVariable<double> {
  final niedrig = FuzzySet.LeftShoulder(0.0, 2.0, 8.0, 'Niedrig');
  final mittel = FuzzySet.Triangle(2.0, 8.0, 14.0, 'Mittel');
  final hoch = FuzzySet.RightShoulder(8.0, 14.0, 20.0, 'Hoch');

  _Capacity() {
    sets = [niedrig, mittel, hoch];
    name = 'Kapazität';
    init();
  }
}

/// Ausgangs-Fuzzy-Variable „Kunden pro Woche" (0–100).
class _CustomersPerWeek extends FuzzyVariable<int> {
  final wenig = FuzzySet.LeftShoulder(0, 0, 50, 'Wenig');
  final mittel = FuzzySet.Triangle(0, 50, 100, 'Mittel');
  final viel = FuzzySet.RightShoulder(50, 100, 100, 'Viel');

  _CustomersPerWeek() {
    sets = [wenig, mittel, viel];
    name = 'Kunden/Woche';
    init();
  }
}

/// Fuzzy-Inferenz-Engine für das passive Einkommen (§ 8).
///
/// Wird einmalig aufgebaut und für jeden Aufruf mit frischen Eingabe- und
/// Ausgabe-`FuzzyValue`s verwendet (die Regeln selbst sind unveränderlich).
class _PassiveIncomeEngine {
  final _Attractiveness attractiveness = _Attractiveness();
  final _Satisfaction satisfaction = _Satisfaction();
  final _Capacity capacity = _Capacity();
  final _CustomersPerWeek customers = _CustomersPerWeek();
  final FuzzyRuleBase rules = FuzzyRuleBase();

  _PassiveIncomeEngine() {
    final att = attractiveness;
    final sat = satisfaction;
    final cap = capacity;
    final cust = customers;
    rules.addRules([
      // Niedrige Teilgrößen drücken die Kundenzahl.
      (att.niedrig) >> (cust.wenig),
      (sat.niedrig) >> (cust.wenig),
      (cap.niedrig) >> (cust.wenig),
      // Mittlere Kombinationen heben sie moderat an.
      (att.mittel & sat.mittel) >> (cust.mittel),
      (att.mittel & cap.mittel) >> (cust.mittel),
      (sat.mittel & cap.mittel) >> (cust.mittel),
      // Hohe Kombinationen bringen viele Kunden.
      (att.hoch & sat.hoch) >> (cust.viel),
      (att.hoch & cap.hoch) >> (cust.viel),
      (sat.hoch & cap.hoch) >> (cust.viel),
    ]);
  }

  int resolve(double att, double sat, double cap) {
    final output = customers.createOutputPlaceholder();
    rules.resolve(
      inputs: [
        attractiveness.assign(att),
        satisfaction.assign(sat),
        capacity.assign(cap),
      ],
      outputs: [output],
    );
    return output.crispValue ?? 0;
  }
}

/// Passives Einkommen des Restaurants zwischen den Gefechten (§ 8).
///
/// Reine, testbare Funktionen: Eingangswerte (Attraktivität, Kundenzufriedenheit,
/// Kapazität) → Kunden/Woche → Einkommen/Woche.
class PassiveIncomeService {
  PassiveIncomeService._();

  static final _PassiveIncomeEngine _engine = _PassiveIncomeEngine();

  /// Kunden pro Woche (0–100) aus den drei Eingangswerten.
  ///
  /// **Kein Personal → 0 Kunden** (Kapazität 0).
  static int customersPerWeek({
    required double attractiveness,
    required double satisfaction,
    required double capacity,
  }) {
    if (capacity <= 0) return 0;
    return _engine.resolve(attractiveness, satisfaction, capacity);
  }

  /// Passives Einkommen in Euro pro Woche.
  static int passiveIncomePerWeek({
    required double attractiveness,
    required double satisfaction,
    required double capacity,
  }) {
    final customers = customersPerWeek(
      attractiveness: attractiveness,
      satisfaction: satisfaction,
      capacity: capacity,
    );
    return customers * EconomyBalance.passiveIncomePerCustomerPerWeek;
  }
}

