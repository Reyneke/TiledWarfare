import 'package:tiled_warfare/services/economy_balance.dart';

/// Reine, deterministisch testbare Korruptions-Simulation der **FRT**
/// (Kapitel 14).
///
/// Die FRT ist die übergeordnete Gegner-Fraktion („der wahre Gegner des
/// Spiels“). Mit jedem vollendeten Wochen-Block (V8) steigt die — **je
/// Stadtteil** geführte — Korruption langsam an; Sabotagen und Eliminierungen
/// treiben sie zusätzlich, gewonnene Gefechte senken sie. Alle Formeln sind
/// reine Funktionen ohne Zufall und ohne versteckten Zustand: Der Zustand lebt
/// allein in `RestaurantData.corruptionPercent` und wird über die injizierte
/// Zeit (Wochen-Tick) **monoton** fortgeschrieben (V8-Idempotenz).
///
/// Alle Beträge stehen zentral in [EconomyBalance] (V7).
class FrtService {
  FrtService._();

  /// Klemmt einen Korruptionswert in den gültigen Bereich (0–100).
  static double clampCorruption(double percent) => percent.clamp(
        EconomyBalance.frtCorruptionFloorPercent,
        EconomyBalance.frtCorruptionCeilingPercent,
      );

  /// Anteil `f = korruption / 100` (bei 100 % Korruption also `f = 1`).
  static double _fraction(double percent) =>
      clampCorruption(percent) / EconomyBalance.frtCorruptionCeilingPercent;

  /// Fortschreibung am Ende eines **vollendeten** 7-Tage-Blocks: Anstieg um
  /// [EconomyBalance.frtCorruptionPerWeekPercent], geklemmt auf 0–100.
  static double afterBlock(double current) =>
      clampCorruption(current + EconomyBalance.frtCorruptionPerWeekPercent);

  /// Zusätzlicher Anstieg je **unbemerkt gebliebener** FRT-Sabotage (Q8).
  static double addSabotage(double current, [int count = 1]) => clampCorruption(
        current + count * EconomyBalance.frtCorruptionPerSabotagePercent,
      );

  /// Zusätzlicher Anstieg je **eliminiertem** Rivalen (Q8).
  static double addElimination(double current, [int count = 1]) =>
      clampCorruption(
        current + count * EconomyBalance.frtCorruptionPerEliminationPercent,
      );

  /// Senkung durch ein Gefecht (Kapitel 14, „Senkung“): je getötetem Monster
  /// und zusätzlich je Sieg. Geklemmt auf 0–100.
  static double reduce(
    double current, {
    int monstersKilled = 0,
    bool victory = false,
  }) {
    var result = current -
        monstersKilled * EconomyBalance.frtCorruptionReducePerMonsterPercent;
    if (victory) {
      result -= EconomyBalance.frtCorruptionReducePerVictoryPercent;
    }
    return clampCorruption(result);
  }

  /// `true`, wenn der Stadtteil ab dieser Korruption als **verloren** gilt
  /// (Schwelle `frtCorruptionLostThresholdPercent`, Q4).
  static bool isDistrictLost(double percent) =>
      clampCorruption(percent) >=
      EconomyBalance.frtCorruptionLostThresholdPercent;

  /// Deterministischer Monsterstärke-Faktor zum Spawn-Zeitpunkt.
  ///
  /// `monsterFaktor = 1 + f × (frtMonsterStrengthScalePercent / 100)`
  /// (Beispiel: 50 % Korruption, Scale 100 % ⇒ Faktor 1.5).
  static double monsterStrengthFactor(double percent) =>
      1 +
      _fraction(percent) *
          (EconomyBalance.frtMonsterStrengthScalePercent / 100);

  /// Skaliert einen einzelnen Statwert deterministisch (kaufmännische Rundung),
  /// z. B. `(wert × monsterFaktor).round()` (Q3).
  static int scaleStat(int value, double factor) => (value * factor).round();

  /// Einkommens-Malus in Prozent: `malusProzent = f ×
  /// frtCorruptionIncomePenaltyMaxPercent` (max. bei 100 % Korruption).
  static double incomeMalusPercent(double percent) =>
      _fraction(percent) *
      EconomyBalance.frtCorruptionIncomePenaltyMaxPercent;

  /// Effektives Wochen-Einkommen **nach** Korruptions-Malus:
  /// `incomePerWeek − round(incomePerWeek × malusProzent / 100)`.
  static int applyIncomeMalus(int incomePerWeek, double percent) {
    final malus = incomeMalusPercent(percent);
    if (malus <= 0) return incomePerWeek;
    return incomePerWeek - (incomePerWeek * malus / 100).round();
  }

  /// Abzug auf den Power-Projection-Einkommensfaktor (Q8):
  /// `baseFactor × (1 − f × frtPowerProjectionPenaltyPercent / 100)`,
  /// geklemmt auf ≥ 0.
  static double powerProjectionIncomeFactor(double baseFactor, double percent) {
    final effektiv = baseFactor *
        (1 -
            _fraction(percent) *
                (EconomyBalance.frtPowerProjectionPenaltyPercent / 100));
    return effektiv < 0 ? 0 : effektiv;
  }
}
