import 'package:tiled_warfare/fuzzy_logic/lib/fuzzylogic.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Fuzzy-Variable für die **Konkurrenzdichte** (Domäne 0–1).
///
/// „Schwach“ = wenig Konkurrenz (Spieler weit oben), „Stark“ = hartes Feld.
class _Competition extends FuzzyVariable<double> {
  final schwach = FuzzySet.LeftShoulder(
    EconomyBalance.ppCompetitionWeakPeak,
    EconomyBalance.ppCompetitionWeakPeak,
    EconomyBalance.ppCompetitionWeakCeiling,
    'Schwach',
  );
  final mittel = FuzzySet.Triangle(
    EconomyBalance.ppCompetitionMidFloor,
    EconomyBalance.ppCompetitionMidPeak,
    EconomyBalance.ppCompetitionMidCeiling,
    'Mittel',
  );
  final stark = FuzzySet.RightShoulder(
    EconomyBalance.ppCompetitionStrongFloor,
    EconomyBalance.ppCompetitionStrongPeak,
    EconomyBalance.ppCompetitionStrongRepresentative,
    'Stark',
  );

  _Competition() {
    sets = [schwach, mittel, stark];
    name = 'Konkurrenz';
    init();
  }
}

/// Fuzzy-Variable für die **Gewinn-/Verlust-Bilanz** (Domäne 0–1).
class _Ratio extends FuzzyVariable<double> {
  final schlecht = FuzzySet.LeftShoulder(
    0.0,
    0.0,
    EconomyBalance.ppRatioBadCeiling,
    'Schlecht',
  );
  final ausgeglichen = FuzzySet.Triangle(
    EconomyBalance.ppRatioBalancedFloor,
    EconomyBalance.ppRatioBalancedPeak,
    EconomyBalance.ppRatioBalancedCeiling,
    'Ausgeglichen',
  );
  final gut = FuzzySet.RightShoulder(
    EconomyBalance.ppRatioGoodFloor,
    1.0,
    1.0,
    'Gut',
  );

  _Ratio() {
    sets = [schlecht, ausgeglichen, gut];
    name = 'Bilanz';
    init();
  }
}

/// Fuzzy-Variable für die **Teamqualität** (Domäne 0–4, wie die §-8-Eingänge).
class _StaffQuality extends FuzzyVariable<double> {
  final schwach = FuzzySet.LeftShoulder(
    0.0,
    EconomyBalance.fuzzyInputLowPeak,
    EconomyBalance.fuzzyInputMidPeak,
    'Schwach',
  );
  final mittel = FuzzySet.Triangle(
    EconomyBalance.fuzzyInputLowPeak,
    EconomyBalance.fuzzyInputMidPeak,
    EconomyBalance.fuzzyInputHighPeak,
    'Mittel',
  );
  final hoch = FuzzySet.RightShoulder(
    EconomyBalance.fuzzyInputMidPeak,
    EconomyBalance.fuzzyInputHighPeak,
    EconomyBalance.inputDomainMax,
    'Hoch',
  );

  _StaffQuality() {
    sets = [schwach, mittel, hoch];
    name = 'Teamqualität';
    init();
  }
}

/// Ausgangs-Fuzzy-Variable „Power Projection“ (0–100).
///
/// Dient zugleich als Eingangsmenge der Einkommensfaktor-Stufe (Q2): identische
/// Domäne (0-100) und Peaks, daher wird dieselbe Variable wiederverwendet.
class _PowerProjection extends FuzzyVariable<int> {
  final schwach = FuzzySet.LeftShoulder(
    EconomyBalance.powerProjectionLowRepresentative,
    0,
    EconomyBalance.powerProjectionLowCeiling,
    'Schwach',
  );
  final mittel = FuzzySet.Triangle(
    0,
    EconomyBalance.powerProjectionMidPeak,
    EconomyBalance.powerProjectionDomainMax,
    'Mittel',
  );
  final stark = FuzzySet.RightShoulder(
    EconomyBalance.powerProjectionHighFloor,
    EconomyBalance.powerProjectionDomainMax,
    EconomyBalance.powerProjectionHighRepresentative,
    'Stark',
  );

  _PowerProjection() {
    sets = [schwach, mittel, stark];
    name = 'PowerProjection';
    init();
  }
}

/// Fuzzy-Inferenz-Engine für die Power Projection (Kapitel 12).
class _PowerProjectionEngine {
  final _Competition competition = _Competition();
  final _Ratio ratio = _Ratio();
  final _StaffQuality staffQuality = _StaffQuality();
  final _PowerProjection pp = _PowerProjection();
  final FuzzyRuleBase rules = FuzzyRuleBase();

  _PowerProjectionEngine() {
    final c = competition;
    final r = ratio;
    final q = staffQuality;
    final out = pp;
    rules.addRules([
      // Wenig Konkurrenz hebt auch mäßige Restaurants nach oben.
      (c.schwach) >> (out.stark),
      (c.schwach & r.gut) >> (out.stark),
      // Harte Konkurrenz mit schlechter Bilanz drückt nach unten.
      (c.stark & r.schlecht) >> (out.schwach),
      // Ausgeglichenes Feld/Ergebnis ⇒ Mitte.
      (c.mittel & r.ausgeglichen) >> (out.mittel),
      (c.mittel & q.mittel) >> (out.mittel),
      // Starke Mannschaft mit guter Bilanz setzt sich durch.
      (q.hoch & r.gut) >> (out.stark),
      // Schwache Mannschaft in hartem Feld fällt zurück.
      (q.schwach & c.stark) >> (out.schwach),
    ]);
  }

  int resolve(double c, double r, double q) {
    final output = pp.createOutputPlaceholder();
    rules.resolve(
      inputs: [competition.assign(c), ratio.assign(r), staffQuality.assign(q)],
      outputs: [output],
    );
    return output.crispValue ?? EconomyBalance.powerProjectionMidPeak;
  }
}

/// Zweite Mini-Fuzzy-Stufe: PP (0–100) → Einkommensfaktor (0.75–1.25).
class _IncomeFactorOutput extends FuzzyVariable<double> {
  final niedrig = FuzzySet.LeftShoulder(
    EconomyBalance.powerProjectionIncomeFactorMin,
    EconomyBalance.powerProjectionIncomeFactorMin,
    1.0,
    'Niedrig',
  );
  final mittel = FuzzySet.Triangle(
    EconomyBalance.powerProjectionIncomeFactorMin,
    1.0,
    EconomyBalance.powerProjectionIncomeFactorMax,
    'Mittel',
  );
  final hoch = FuzzySet.RightShoulder(
    1.0,
    EconomyBalance.powerProjectionIncomeFactorMax,
    EconomyBalance.powerProjectionIncomeFactorMax,
    'Hoch',
  );

  _IncomeFactorOutput() {
    sets = [niedrig, mittel, hoch];
    name = 'PPEinkommensfaktor';
    init();
  }
}

class _IncomeFactorEngine {
  final _PowerProjection input = _PowerProjection();
  final _IncomeFactorOutput factor = _IncomeFactorOutput();
  final FuzzyRuleBase rules = FuzzyRuleBase();

  _IncomeFactorEngine() {
    final i = input;
    final f = factor;
    rules.addRules([
      (i.schwach) >> (f.niedrig),
      (i.mittel) >> (f.mittel),
      (i.stark) >> (f.hoch),
    ]);
  }

  double resolve(int pp) {
    final output = factor.createOutputPlaceholder();
    rules.resolve(inputs: [input.assign(pp)], outputs: [output]);
    return output.crispValue ?? 1.0;
  }
}

/// Eingangsmenge des Konkurrenzdrucks: relativer PP-Abstand (Domäne −1…1).
///
/// Positiv = Spieler führt, negativ = Spieler liegt hinten.
class _PressureInput extends FuzzyVariable<double> {
  final hinten = FuzzySet.LeftShoulder(
    EconomyBalance.competitionPressureLowPeak,
    EconomyBalance.competitionPressureLowPeak,
    EconomyBalance.competitionPressureNeutralHalfWidth,
    'Hinten',
  );
  final gleichauf = FuzzySet.Triangle(
    -EconomyBalance.competitionPressureNeutralHalfWidth,
    0.0,
    EconomyBalance.competitionPressureNeutralHalfWidth,
    'Gleichauf',
  );
  final vorne = FuzzySet.RightShoulder(
    -EconomyBalance.competitionPressureNeutralHalfWidth,
    EconomyBalance.competitionPressureHighPeak,
    EconomyBalance.competitionPressureHighPeak,
    'Vorne',
  );

  _PressureInput() {
    sets = [hinten, gleichauf, vorne];
    name = 'Konkurrenzdruck';
    init();
  }
}

class _PressureFactorOutput extends FuzzyVariable<double> {
  final niedrig = FuzzySet.LeftShoulder(
    EconomyBalance.competitionPressureFactorMin,
    EconomyBalance.competitionPressureFactorMin,
    1.0,
    'Niedrig',
  );
  final mittel = FuzzySet.Triangle(
    EconomyBalance.competitionPressureFactorMin,
    1.0,
    EconomyBalance.competitionPressureFactorMax,
    'Mittel',
  );
  final hoch = FuzzySet.RightShoulder(
    1.0,
    EconomyBalance.competitionPressureFactorMax,
    EconomyBalance.competitionPressureFactorMax,
    'Hoch',
  );

  _PressureFactorOutput() {
    sets = [niedrig, mittel, hoch];
    name = 'KonkurrenzdruckFaktor';
    init();
  }
}

/// Engine der **Gegenwirkung an der Spitze** (Q10): Wer das Feld dominiert,
/// erhält Gegenwind; wer hinten liegt, einen Aufhol-Bonus.
class _PressureEngine {
  final _PressureInput input = _PressureInput();
  final _PressureFactorOutput factor = _PressureFactorOutput();
  final FuzzyRuleBase rules = FuzzyRuleBase();

  _PressureEngine() {
    final i = input;
    final f = factor;
    rules.addRules([
      (i.hinten) >> (f.hoch),
      (i.gleichauf) >> (f.mittel),
      (i.vorne) >> (f.niedrig),
    ]);
  }

  double resolve(double gap) {
    final output = factor.createOutputPlaceholder();
    rules.resolve(inputs: [input.assign(gap)], outputs: [output]);
    return output.crispValue ?? 1.0;
  }
}

/// **Power Projection** des Restaurants (Kapitel 12).
///
/// Reine, testbare Funktionen: Treiber (Konkurrenzdichte, Bilanz, Teamqualität)
/// → PP (0–100) → Einkommensfaktor. Der Faktor ist die **zweite Mini-Fuzzy-Stufe**
/// (Q2) und wird von [competitionPressureFactor] (Q10) weiter skaliert.
///
/// Bewusst **kein** Fuzzy-Eingang des `PassiveIncomeService` (§ 8, P2) – die
/// bestehende Kunden-Fuzzy bleibt unverändert.
class PowerProjectionService {
  PowerProjectionService._();

  static final _PowerProjectionEngine _pp = _PowerProjectionEngine();
  static final _IncomeFactorEngine _factor = _IncomeFactorEngine();
  static final _PressureEngine _pressure = _PressureEngine();

  /// Power Projection (0–100) aus den drei Fuzzy-Treibern.
  static int powerProjection({
    required double competition,
    required double ratio,
    required double staffQuality,
  }) => _pp.resolve(
    competition.clamp(0.0, 1.0),
    ratio.clamp(0.0, 1.0),
    staffQuality.clamp(0.0, EconomyBalance.inputDomainMax),
  );

  /// Bilanz-Eingang aus dem jüngsten Match-Ergebnis (P6: neutral ohne Gefecht).
  ///
  /// Die per-Restaurant-Historie wird **nicht** persistiert; verfügbar ist das
  /// Ergebnis des jüngsten Gefechts ([MatchResult]). Sieg ⇒ 1.0, Niederlage ⇒ 0.0,
  /// Unentschieden/kein Gefecht ⇒ 0.5.
  static double ratioFromResult(MatchResult? result) {
    switch (result) {
      case MatchResult.win:
        return 1.0;
      case MatchResult.loss:
        return 0.0;
      default:
        return EconomyBalance.powerProjectionNeutralInput;
    }
  }

  /// Konkurrenzdichte aus der Platzierung des **vorherigen** Ticks (P1).
  ///
  /// `1 − (rank − 1) / (rivals − 1)`; mit `rivals ≤ 1` oder `rank ≤ 0`
  /// (noch keine Platzierung) neutral ([EconomyBalance.powerProjectionNeutralInput]).
  static double competitionFromRank(int rank, int rivals) {
    if (rank <= 0 || rivals <= 1) {
      return EconomyBalance.powerProjectionNeutralInput;
    }
    final normalized = 1.0 - (rank - 1) / (rivals - 1);
    return normalized.clamp(0.0, 1.0);
  }

  /// Konkurrenzdichte aus dem **relativen PP-Abstand** zur Feldspitze – die
  /// persistenzfreie Variante der 1-Tick-Verzögerung (Q3): Der aktuelle
  /// Feld-Durchschnitt dient als Näherung für den vorherigen Rang.
  static double competitionFromPp(int playerPp, double fieldAveragePp) {
    final gap =
        (playerPp - fieldAveragePp) / EconomyBalance.powerProjectionDomainMax;
    // Spieler über dem Feld ⇒ wenig Konkurrenz (kompetitiv niedrig).
    final value = (1.0 - gap) / 2.0;
    return value.clamp(0.0, 1.0);
  }

  /// Einkommensfaktor (0.75–1.25) aus der PP – zweite Mini-Fuzzy-Stufe (Q2).
  static double incomeFactor(int pp) =>
      _factor.resolve(pp.clamp(0, EconomyBalance.powerProjectionDomainMax));

  /// Konkurrenzdruck-Faktor (0.85–1.15) aus dem relativen PP-Abstand (Q10).
  ///
  /// [playerPp] gegen den Ø der Rivalen-PPs im Stadtteil: Wer dominiert, erhält
  /// Gegenwind (< 1), wer hinten liegt, einen Aufhol-Bonus (> 1).
  static double competitionPressureFactor({
    required int playerPp,
    required double rivalAveragePp,
  }) {
    final gap =
        (playerPp - rivalAveragePp) / EconomyBalance.powerProjectionDomainMax;
    return _pressure.resolve(
      gap.clamp(
        EconomyBalance.competitionPressureLowPeak,
        EconomyBalance.competitionPressureHighPeak,
      ),
    );
  }

  /// Effektiver Einkommensfaktor: PP-Faktor × Konkurrenzdruck-Faktor (Q10).
  static double effectiveIncomeFactor({
    required int playerPp,
    required double rivalAveragePp,
  }) =>
      incomeFactor(playerPp) *
      competitionPressureFactor(
        playerPp: playerPp,
        rivalAveragePp: rivalAveragePp,
      );
}
