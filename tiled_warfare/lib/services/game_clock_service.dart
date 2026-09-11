import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
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
