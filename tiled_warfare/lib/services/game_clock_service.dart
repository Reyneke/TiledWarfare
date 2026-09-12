import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';

/// Ergebnis eines (nachgeholten) Wochenticks (V8).
class WeeklyTickResult {
  /// Anzahl der abgerechneten Wochen.
  final int weeks;

  /// Gutgeschriebenes passives Einkommen insgesamt.
  final int passiveIncome;

  /// Abgebuchte Teamarzt-Kosten insgesamt.
  final int medicCosts;

  /// Abgebuchter Erweiterungs-Unterhalt insgesamt.
  final int upgradeUpkeep;

  /// Abgebuchte Negativzinsen insgesamt.
  final int negativeInterest;

  /// Budget nach der Abrechnung.
  final int budgetAfter;

  /// `true`, wenn das Budget die Negativgrenze unterschreitet.
  final bool bankrupt;

  const WeeklyTickResult({
    required this.weeks,
    required this.passiveIncome,
    required this.medicCosts,
    required this.upgradeUpkeep,
    required this.negativeInterest,
    required this.budgetAfter,
    required this.bankrupt,
  });

  /// Ergebnis ohne fällige Wochen (No-op).
  factory WeeklyTickResult.none(int budget) => WeeklyTickResult(
        weeks: 0,
        passiveIncome: 0,
        medicCosts: 0,
        upgradeUpkeep: 0,
        negativeInterest: 0,
        budgetAfter: budget,
        bankrupt: EconomyService.isBankrupt(budget),
      );
}

/// Ergebnis eines Heilungs-Ticks (V3).
class HealingTickResult {
  /// Verwendete Heilzeit pro Verletzungsstufe.
  final Duration perStage;

  /// Anzahl der Charaktere, deren Status sich verändert hat.
  final int healedCount;

  /// Anzahl der zurückgenommenen Notfall-Spritzen.
  final int shotRolledBackCount;

  const HealingTickResult({
    required this.perStage,
    required this.healedCount,
    required this.shotRolledBackCount,
  });
}

/// Echtzeit-Zeitsystem (V8).
///
/// Reine Zeitrechnung auf injiziertem `now` (deterministisch testbar) plus der
/// idempotente Wochen-`catchUp`: verpasste Wochen werden beim App-Start bzw.
/// Restaurant-Wechsel nachgeholt.
class GameClockService {
  GameClockService._();

  /// Länge eines Ticks: 1 Echtzeitwoche (Entscheidung, § 2/§ 8).
  static const Duration week = Duration(days: 7);

  /// Status→Schweregrad (0 = `ready` … 7 = `overkilled`).
  static const Map<String, int> _severityByStatus = {
    'ready': 0,
    'reeling': 1,
    'hurt': 2,
    'afraid': 3,
    'injured': 4,
    'dying': 5,
    'dead': 6,
    'overkilled': 7,
  };

  /// Verstrichene Zeit seit [lastSeenAt] (negativ → `Duration.zero`).
  static Duration elapsed(DateTime lastSeenAt, DateTime now) {
    final diff = now.difference(lastSeenAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  // ── Heilung & Notfall-Spritze (V3) ────────────────────────────────────

  /// Status→Position in der Heilungskette (0 = `ready`, 5 = `dying`).
  ///
  /// Bewusst **nicht** `severity`: In der Heilungskette liegt `afraid` (3)
  /// zwischen `hurt` (2) und `reeling` (1), also *leichter* als `hurt`.
  /// `dead`/`overkilled` liegen außerhalb der heilbaren Kette.
  static const Map<CharacterStatus, int> _chainPosition = {
    CharacterStatus.ready: 0,
    CharacterStatus.reeling: 1,
    CharacterStatus.afraid: 2,
    CharacterStatus.hurt: 3,
    CharacterStatus.injured: 4,
    CharacterStatus.dying: 5,
    CharacterStatus.dead: 6,
    CharacterStatus.overkilled: 7,
  };

  /// Status aufsteigend nach Kettenposition (0 = `ready` … 5 = `dying`).
  static const List<CharacterStatus> _statusByChainPosition = [
    CharacterStatus.ready,
    CharacterStatus.reeling,
    CharacterStatus.afraid,
    CharacterStatus.hurt,
    CharacterStatus.injured,
    CharacterStatus.dying,
  ];

  /// Verstrichene Echtzeit zwischen [from] und [now] (Analog zu [weeksElapsed]).
  static Duration hoursElapsed(DateTime from, DateTime now) =>
      elapsed(from, now);

  /// Heilzeit pro Verletzungsstufe für [quality] (ohne Arzt: 24 h, § 4.3).
  static Duration healTimePerStageFor({MedicQuality? quality}) =>
      quality?.healTimePerStage ?? EconomyBalance.healBasePerStage;

  /// Kettenposition eines Status (höher = schwerer).
  static int chainPositionOf(CharacterStatus status) =>
      _chainPosition[status] ?? 0;

  /// Ob [status] überhaupt Teil der heilbaren Kette ist.
  static bool isHealable(CharacterStatus status) =>
      status != CharacterStatus.dead && status != CharacterStatus.overkilled;

  /// Anzahl der Stufen bis `ready` (0 für `ready`, `null` für Unheilbare).
  static int? healingStepsToReady(CharacterStatus status) =>
      isHealable(status) ? chainPositionOf(status) : null;

  /// Gibt den schwereren der beiden Status anhand der **Kettenposition** zurück
  /// (nicht `severity`; dadurch gewinnt `hurt` gegen `afraid`).
  static CharacterStatus heavierByChain(CharacterStatus a, CharacterStatus b) =>
      chainPositionOf(a) >= chainPositionOf(b) ? a : b;

  /// Trefferpunkte, die beim Gefechtsstart aus [status] abgeleitet werden
  /// (§ 1, eine Quelle der Wahrheit): `max(1, maxWoundValue − severity)`.
  static int woundValueFor(CharacterStatus status) {
    final value = EconomyBalance.maxWoundValue - status.severity;
    return value < 1 ? 1 : value;
  }

  /// Höchste Qualitätsstufe der angestellten [medics] (deterministisch).
  static MedicQuality? bestMedicQuality(Iterable<MedicData> medics) {
    MedicQuality? best;
    for (final md in medics) {
      final quality = _medicQualityFromName(md.quality);
      if (quality == null) continue;
      if (best == null ||
          MedicQuality.values.indexOf(quality) >
              MedicQuality.values.indexOf(best)) {
        best = quality;
      }
    }
    return best;
  }

  /// Höchste Qualitätsstufe angestellter [ObjectTeamMedic]s (UI-Ebene, V3).
  static MedicQuality? bestHiredQuality(Iterable<ObjectTeamMedic> medics) {
    MedicQuality? best;
    for (final medic in medics) {
      if (best == null ||
          MedicQuality.values.indexOf(medic.quality) >
              MedicQuality.values.indexOf(best)) {
        best = medic.quality;
      }
    }
    return best;
  }

  /// Heilt [current] um `floor(elapsed / perStage)` Stufen in der Kette
  /// `dying → injured → hurt → afraid → reeling → ready` (bis maximal `ready`).
  ///
  /// Reine Vorwärtsrechnung – wiederholtes Anwenden mit demselben `now` liefert
  /// dasselbe Ergebnis (idempotent).
  static CharacterStatus healedStatus(
    CharacterStatus current,
    Duration elapsed,
    Duration perStage,
  ) {
    if (!isHealable(current) || perStage <= Duration.zero) return current;
    final steps = elapsed.inSeconds ~/ perStage.inSeconds;
    if (steps <= 0) return current;
    final target = chainPositionOf(current) - steps;
    final clamped = target < 0 ? 0 : target;
    if (clamped >= _statusByChainPosition.length) {
      return CharacterStatus.ready;
    }
    return _statusByChainPosition[clamped];
  }

  /// Verbleibende Zeit bis `ready` für den UI-Countdown (V3).
  ///
  /// `Stufen bis ready × perStage` minus der bereits verstrichenen Zeit;
  /// liefert `Duration.zero` für `ready`/Unheilbare.
  static Duration remainingHealingTime({
    required CharacterStatus status,
    required DateTime? injuryStartedAt,
    required Duration perStage,
    required DateTime now,
  }) {
    final steps = healingStepsToReady(status);
    if (steps == null || steps <= 0 || perStage <= Duration.zero) {
      return Duration.zero;
    }
    final total = perStage * steps;
    if (injuryStartedAt == null) return total;
    final remaining = total - elapsed(injuryStartedAt, now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Verbleibende Wirkungsdauer einer verabreichten Notfall-Spritze (V3).
  static Duration remainingShotTime(DateTime? emergencyShotAt, DateTime now) {
    if (emergencyShotAt == null) return Duration.zero;
    final remaining =
        EconomyBalance.emergencyShotDuration - elapsed(emergencyShotAt, now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Wendet die Echtzeit-Heilung auf `restaurant.staff` an (V3).
  ///
  /// Der Fortschritt wird **immer** aus `injuryStartedAt` + [now] neu berechnet
  /// (`Stufen = floor(elapsed / perStage)`), nie fortgeschrieben. Alt-Stände
  /// ohne `injuryStartedAt` heilen rückwirkend ab `lastSeenAt` (Fallback `now`).
  /// Charaktere mit aktiver Notfall-Spritze bleiben bis zum Rückfall `ready`.
  static HealingTickResult advanceHealing(
      RestaurantData restaurant, DateTime now) {
    final perStage =
        healTimePerStageFor(quality: bestMedicQuality(restaurant.medics));
    final defaultAnchor = restaurant.lastSeenAt ?? now;
    var healed = 0;

    for (final staff in restaurant.staff) {
      // Während einer aktiven Spritze ist der Charakter einsatzfähig; die
      // zugrunde liegende Heilung wird erst beim Rückfall ausgewertet.
      if (staff.emergencyShotAt != null) continue;

      final current = _statusFromName(staff.status);
      if (!isHealable(current) || current == CharacterStatus.ready) continue;

      // Migration (V3): rückwirkende Heilung ab dem letzten bekannten Anker.
      staff.injuryStartedAt ??= defaultAnchor;
      // Ausgangsstatus fixieren, damit die Neuberechnung idempotent bleibt
      // (ansonsten würde jeder weitere Aufruf von der bereits geheilten Stufe
      // aus erneut heilen).
      staff.injuryStartStatus ??= current.name;

      final anchor = staff.injuryStartedAt!;
      final baseStatus = _statusFromName(staff.injuryStartStatus);
      final next = healedStatus(baseStatus, elapsed(anchor, now), perStage);
      if (next != current) {
        staff.status = next.name;
        healed++;
      }
    }

    return HealingTickResult(
      perStage: perStage,
      healedCount: healed,
      shotRolledBackCount: 0,
    );
  }

  /// Nimmt automatisch verabreichte Notfall-Spritzen nach
  /// [EconomyBalance.emergencyShotDuration] zurück (V3, § 4.5).
  ///
  /// Der Rückfall zählt als **neuer Verletzungsbeginn** (`injuryStartedAt = now`);
  /// es gewinnt der schwerere Status gemäß Kettenposition. Idempotent: Nach dem
  /// Rückfall sind die Spritzen-Marker gelöscht.
  static int rollBackEmergencyShots(RestaurantData restaurant, DateTime now) {
    final perStage =
        healTimePerStageFor(quality: bestMedicQuality(restaurant.medics));
    var rolledBack = 0;

    for (final staff in restaurant.staff) {
      final shotAt = staff.emergencyShotAt;
      if (shotAt == null) continue;
      if (now.difference(shotAt) < EconomyBalance.emergencyShotDuration) {
        continue;
      }

      final suppressed = _statusFromName(staff.suppressedStatus);
      final anchor = staff.injuryStartedAt ?? shotAt;
      final healedUnderlying =
          healedStatus(suppressed, elapsed(anchor, now), perStage);
      final current = _statusFromName(staff.status);

      var result = heavierByChain(suppressed, healedUnderlying);
      result = heavierByChain(result, current);

      staff.status = result.name;
      staff.injuryStartedAt = now;
      staff.injuryStartStatus = result.name;
      staff.emergencyShotAt = null;
      staff.suppressedStatus = null;
      rolledBack++;
    }
    return rolledBack;
  }

  static MedicQuality? _medicQualityFromName(String? name) {
    if (name == null) return null;
    for (final quality in MedicQuality.values) {
      if (quality.name == name) return quality;
    }
    return null;
  }

  static CharacterStatus _statusFromName(String? name) {
    for (final status in CharacterStatus.values) {
      if (status.name == name) return status;
    }
    return CharacterStatus.ready;
  }

  /// Anzahl vollständiger Echtzeitwochen seit [lastSeenAt].
  static int weeksElapsed(DateTime lastSeenAt, DateTime now) =>
      elapsed(lastSeenAt, now).inDays ~/ 7;

  /// Zeitpunkt des nächsten Wochenticks (für den Countdown in der UI).
  static DateTime nextWeeklyTick(DateTime lastSeenAt, DateTime now) {
    final weeks = weeksElapsed(lastSeenAt, now);
    return lastSeenAt.add(week * (weeks + 1));
  }

  /// Holt fällige Wochen für [restaurant] nach und schreibt `lastSeenAt` fort.
  ///
  /// Reihenfolge **pro Woche**: **passives Einkommen → Teamarzt-Kosten →
  /// Erweiterungs-Unterhalt → Negativzinsen → Bankrott-Check** (§ 8/§ 10).
  /// Wiederholtes Anwenden ist idempotent: Da `lastSeenAt` auf [now] gesetzt
  /// wird, liefert ein zweiter Aufruf mit demselben [now] keine Fälligkeit.
  static WeeklyTickResult catchUp(RestaurantData restaurant, DateTime now) {
    // V3: Echtzeit-Heilung und Spritzen-Rückfall werden **immer** nachgeholt –
    // auch wenn seit dem letzten Anker noch keine volle Woche vergangen ist.
    advanceHealing(restaurant, now);
    rollBackEmergencyShots(restaurant, now);

    final lastSeen = restaurant.lastSeenAt;
    if (lastSeen == null) {
      restaurant.lastSeenAt = now;
      return WeeklyTickResult.none(restaurant.budget);
    }

    final weeks = weeksElapsed(lastSeen, now);
    if (weeks <= 0) {
      restaurant.lastSeenAt = now;
      return WeeklyTickResult.none(restaurant.budget);
    }

    // Eingangswerte des passiven Einkommens (§ 8).
    final incomePerWeek = PassiveIncomeService.passiveIncomePerWeek(
      attractiveness: attractivenessOf(restaurant, now: now),
      satisfaction: satisfactionOf(restaurant),
      capacity: capacityOf(restaurant),
    );
    final medicPerWeek = EconomyService.billWeeklyMedicCosts(
      restaurant.medics.map((m) => m.costPerWeek),
      1,
    );
    final upkeepPerWeek =
        EconomyService.totalUpgradeUpkeepPerWeek(restaurant.upgrades);

    // Wochenweise abrechnen (Reihenfolge je Woche, § 8/§ 10): passives
    // Einkommen → Teamarzt-Kosten → Erweiterungs-Unterhalt → Negativzinsen.
    // Die Zinsen werden **pro fälliger Woche** auf den jeweiligen Saldo
    // angewandt (und damit ggf. über mehrere Wochen „verzinst").
    var budget = restaurant.budget;
    var totalIncome = 0;
    var totalMedic = 0;
    var totalUpkeep = 0;
    var totalInterest = 0;
    for (var week = 0; week < weeks; week++) {
      budget += incomePerWeek;
      totalIncome += incomePerWeek;
      budget -= medicPerWeek;
      totalMedic += medicPerWeek;
      budget -= upkeepPerWeek;
      totalUpkeep += upkeepPerWeek;
      final beforeInterest = budget;
      budget = EconomyService.applyNegativeInterest(budget);
      totalInterest += beforeInterest - budget;
    }

    restaurant.budget = budget;
    restaurant.lastSeenAt = now;

    return WeeklyTickResult(
      weeks: weeks,
      passiveIncome: totalIncome,
      medicCosts: totalMedic,
      upgradeUpkeep: totalUpkeep,
      negativeInterest: totalInterest,
      budgetAfter: budget,
      bankrupt: EconomyService.isBankrupt(budget),
    );
  }

  // ── Eingangswerte aus dem Restaurant-Zustand (§ 8) ────────────────────

  /// Attraktivität: `1 + (Prestige − 1) + Personalanzahl × Kopf-Bonus`,
  /// geclamped auf die Domäne `0–inputDomainMax`. Ein aktiver Rebranding-Malus
  /// (§ 9) wird abgezogen, sofern [now] übergeben wird und noch innerhalb des
  /// Malus-Fensters liegt.
  static double attractivenessOf(RestaurantData restaurant, {DateTime? now}) {
    final prestige = EconomyBalance.districtPrestigeFor(restaurant.district);
    var value = EconomyBalance.attractivenessBase +
        (prestige - 1.0) +
        restaurant.staff.length * EconomyBalance.staffAttractivityPerHead;
    // Erweiterungen wirken multiplikativ vor dem Clamp (§ 10).
    value *= 1.0 + EconomyService.upgradeEffects(restaurant.upgrades).attractiveness;
    final penaltyUntil = restaurant.rebrandingPenaltyUntil;
    if (now != null && penaltyUntil != null && now.isBefore(penaltyUntil)) {
      value -= EconomyBalance.rebrandingAttractivityPenalty;
    }
    return value.clamp(0.0, EconomyBalance.inputDomainMax);
  }

  /// Teamgesundheit: `1 − Ø(severity)/5` (0.0 … 1.0). Ohne Personal: 0.0.
  static double teamHealthOf(RestaurantData restaurant) {
    if (restaurant.staff.isEmpty) return 0.0;
    final sum = restaurant.staff
        .map((s) => _severityByStatus[s.status] ?? 0)
        .fold<int>(0, (a, b) => a + b);
    final mean = sum / restaurant.staff.length;
    return (1.0 - mean / 5.0).clamp(0.0, 1.0);
  }

  /// Kundenzufriedenheit: `1 + Teamgesundheit × Gewicht + Ergebnisbonus`,
  /// geclamped auf die Domäne `0–inputDomainMax`.
  static double satisfactionOf(RestaurantData restaurant) {
    var value = EconomyBalance.satisfactionBase +
        teamHealthOf(restaurant) * EconomyBalance.satisfactionHealthWeight +
        _resultBonus(restaurant.lastMatchResult);
    value *= 1.0 + EconomyService.upgradeEffects(restaurant.upgrades).satisfaction;
    return value.clamp(0.0, EconomyBalance.inputDomainMax);
  }

  /// Kapazität: `Ø(moneyValue des Personals) / Norm`, geclamped auf
  /// `0–capacityMax`. Ohne Personal: 0.
  static double capacityOf(RestaurantData restaurant) {
    if (restaurant.staff.isEmpty) return 0.0;
    final sum = restaurant.staff
        .map((s) => s.moneyValue)
        .fold<int>(0, (a, b) => a + b);
    final mean = sum / restaurant.staff.length;
    var value = mean / EconomyBalance.capacityMoneyNorm;
    value *= 1.0 + EconomyService.upgradeEffects(restaurant.upgrades).capacity;
    return value.clamp(0.0, EconomyBalance.capacityMax);
  }

  static double _resultBonus(MatchResult? result) {
    switch (result) {
      case MatchResult.win:
        return EconomyBalance.satisfactionWinBonus;
      case MatchResult.loss:
        return -EconomyBalance.satisfactionLossPenalty;
      default:
        return 0.0;
    }
  }
}
