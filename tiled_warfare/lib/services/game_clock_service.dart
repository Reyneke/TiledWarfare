import 'dart:math';

import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';
import 'package:tiled_warfare/services/stress_service.dart';
import 'package:tiled_warfare/services/support_role_service.dart';

/// Abrechnung eines vollendeten 7-Tage-Blocks (Wochen-Zusammenfassung, § 6).
class WeekSettlement {
  /// Laufender Index des Blocks innerhalb dieses Catch-up (0-basiert).
  final int weekIndex;

  /// Beginn des Blocks (Wochenanker zum Zeitpunkt der Abrechnung).
  final DateTime periodStart;

  /// Ende des Blocks (`periodStart + 1 Woche`).
  final DateTime periodEnd;

  /// Gutgeschriebenes passives Einkommen des Blocks (`= incomePerWeek`).
  final int income;

  /// Abgebuchte Teamarzt-Kosten des Blocks.
  final int medicCosts;

  /// Abgebuchte Wochenlöhne des Personals des Blocks (V10, Phase 7).
  final int staffCosts;

  /// Abgebuchter Erweiterungs-Unterhalt des Blocks.
  final int upgradeUpkeep;

  /// Abgebuchte Negativzinsen des Blocks.
  final int negativeInterest;

  /// Budget nach der Abrechnung des Blocks.
  final int budgetAfter;

  const WeekSettlement({
    required this.weekIndex,
    required this.periodStart,
    required this.periodEnd,
    required this.income,
    required this.medicCosts,
    this.staffCosts = 0,
    required this.upgradeUpkeep,
    required this.negativeInterest,
    required this.budgetAfter,
  });
}

/// Ergebnis eines (nachgeholten) Tages-/Wochenticks (V8/§ 6).
class WeeklyTickResult {
  /// Anzahl der abgerechneten vollen Wochen (Blöcke).
  final int weeks;

  /// Gutgeschriebenes passives Einkommen insgesamt (inkl. Resttage).
  final int passiveIncome;

  /// Abgebuchte Teamarzt-Kosten insgesamt.
  final int medicCosts;

  /// Abgebuchte Wochenlöhne des Personals insgesamt (V10, Phase 7).
  final int staffCosts;

  /// Abgebuchter Erweiterungs-Unterhalt insgesamt.
  final int upgradeUpkeep;

  /// Abgebuchte Negativzinsen insgesamt.
  final int negativeInterest;

  /// Budget nach der Abrechnung.
  final int budgetAfter;

  /// `true`, wenn das Budget die Negativgrenze unterschreitet.
  final bool bankrupt;

  /// Abrechnungen je vollendetem 7-Tage-Block (§ 6, Wochen-Zusammenfassung).
  final List<WeekSettlement> settlements;

  /// Anzahl voller Echtzeittage **außerhalb** des letzten Blocks (§ 6).
  final int leftoverDays;

  /// Summe der Tageserträge dieser Resttage (§ 6).
  final int leftoverIncome;

  const WeeklyTickResult({
    required this.weeks,
    required this.passiveIncome,
    required this.medicCosts,
    this.staffCosts = 0,
    required this.upgradeUpkeep,
    required this.negativeInterest,
    required this.budgetAfter,
    required this.bankrupt,
    this.settlements = const [],
    this.leftoverDays = 0,
    this.leftoverIncome = 0,
  });

  /// Ergebnis ohne fällige Tage/Wochen (No-op).
  factory WeeklyTickResult.none(int budget) => WeeklyTickResult(
        weeks: 0,
        passiveIncome: 0,
        medicCosts: 0,
        staffCosts: 0,
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

  /// Länge eines Ticks: 1 Echtzeitwoche (Entscheidung, § 2/§ 8; V7/P9).
  static const Duration week = EconomyBalance.weeklyTick;

  /// Länge eines Tagesschritts: 1 Echtzeittag (§ 6).
  static const Duration day = EconomyBalance.dailyTick;

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
  static Duration healTimePerStageFor({MedicQuality? quality}) => quality == null
      ? EconomyBalance.healBasePerStage
      : EconomyBalance.medicQualitySpecs[quality]!.healTimePerStage;

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

  /// Anzahl vollständiger Echtzeittage seit [from] (§ 6).
  ///
  /// Feste 24-h-Einheit über `elapsed.inDays` (floor); ein angebrochener Tag
  /// zählt nicht.
  static int daysElapsed(DateTime from, DateTime now) =>
      elapsed(from, now).inDays;

  /// Zeitpunkt des nächsten Wochenticks (für den Countdown in der UI).
  ///
  /// Erwartet den **Wochenanker** (`RestaurantData.weekAnchorAt`), damit der
  /// Countdown über mehrere Catch-ups stabil bleibt (§ 6).
  static DateTime nextWeeklyTick(DateTime lastSeenAt, DateTime now) {
    final weeks = weeksElapsed(lastSeenAt, now);
    return lastSeenAt.add(week * (weeks + 1));
  }

  /// Zeitpunkt der nächsten Tagesbuchung (für einen optionalen UI-Countdown).
  static DateTime nextDailyTick(DateTime from, DateTime now) {
    final days = daysElapsed(from, now);
    return from.add(day * (days + 1));
  }

  /// Holt fällige Tage/Wochen für [restaurant] nach und schreibt die Anker fort.
  ///
  /// Reihenfolge: **Heilung → Spritzen-Rückfall → Tagesschleife** (§ 6). Das
  /// passive Einkommen entsteht **anteilig pro vollem Echtzeittag**; an jeder
  /// Grenze eines vollen 7-Tage-Blocks (`weekAnchorAt`) werden Teamarzt-Kosten,
  /// Erweiterungs-Unterhalt und Negativzinsen abgebucht und eine
  /// [WeekSettlement] erzeugt. Tage nach dem letzten vollen Block (Resttage)
  /// buchen nur Tagesertrag.
  ///
  /// Die Eingangswerte stammen aus dem **Endzustand** (L5-Entscheidung) und
  /// sind über die Lücke konstant; der 7. Tag eines Blocks trägt den
  /// Rundungsrest, damit `Σ Blocktag = incomePerWeek` exakt bleibt.
  ///
  /// Idempotent: `lastSeenAt` (Tagescursor) wird nur um die abgerechneten Tage
  /// fortgeschrieben; ein zweiter Aufruf mit demselben [now] liefert keine
  /// Fälligkeit. Der Sub-Tag-Rest bleibt erhalten, damit häufige Aufrufe (z. B.
  /// ein periodischer UI-Tick) keinen Tag verlieren.
  static WeeklyTickResult catchUp(RestaurantData restaurant, DateTime now,
      {Random? random}) {
    // V3: Echtzeit-Heilung und Spritzen-Rückfall werden **immer** nachgeholt –
    // auch wenn seit dem letzten Anker noch kein voller Tag vergangen ist.
    advanceHealing(restaurant, now);
    rollBackEmergencyShots(restaurant, now);
    // V9 § 6 (Phase 4): Abgelaufene Stress-/Ruhe-Overrides werden entfernt.
    _expireOverrides(restaurant, now);

    final lastSeen = restaurant.lastSeenAt;
    if (lastSeen == null) {
      restaurant.lastSeenAt = now;
      restaurant.weekAnchorAt = now;
      return WeeklyTickResult.none(restaurant.budget);
    }

    final days = daysElapsed(lastSeen, now);
    if (days <= 0) {
      // Kein voller Tag fällig: Anker unangetastet lassen (der Sub-Tag-Rest
      // bleibt erhalten), damit wiederholte Aufrufe nichts verschieben.
      return WeeklyTickResult.none(restaurant.budget);
    }

    // Wochenanker: Fortschreibung nur um volle Wochen (§ 6); Alt-Stände ohne
    // Feld fallen auf den Tagescursor zurück.
    var weekAnchor = restaurant.weekAnchorAt ?? lastSeen;

    // Eingangswerte des passiven Einkommens (§ 8) aus dem Endzustand (L5).
    var incomePerWeek = PassiveIncomeService.passiveIncomePerWeek(
      attractiveness: attractivenessOf(restaurant, now: now),
      satisfaction: satisfactionOf(restaurant),
      capacity: capacityOf(restaurant),
    );
    // V10 (Phase 6)/Option C (`11a`): Aboyeur und Social Media Manager
    // verbessern den Bestellfluss (Einnahmen); beide Zuschläge stapeln additiv.
    final incomeBonusPercent =
        SupportRoleService.incomePercent(restaurant.supportStaff) +
            StaffRoleService.managementIncomePercent(restaurant.staffEntries);
    if (incomeBonusPercent != 0) {
      incomePerWeek = (incomePerWeek * (100 + incomeBonusPercent) / 100).round();
    }
    // Tagesertrag; der 7. Tag eines Blocks trägt den Rundungsrest.
    final incomePerDay = incomePerWeek ~/ 7;
    final incomeLastDayOfBlock = incomePerWeek - incomePerDay * 6;
    final medicPerWeek = EconomyService.billWeeklyMedicCosts(
      restaurant.medics.map((m) => m.costPerWeek),
      1,
    );
    // V10 (Phase 7)/Option C (`11a`): Wochenlöhne des gesamten Brigade-Personals
    // inkl. des Nicht-Kampf-Personals (Hilfs-/Service-Rollen + Verwaltung &
    // Marketing). Quelle ist der generalisierte `staffEntries`-Bestand; die
    // Arztkosten werden separat über `billWeeklyMedicCosts` gebucht.
    final wagePerWeek = EconomyService.billWeeklyStaffWages(
      [
        ...restaurant.staff.map(_staffWagePerWeekOf),
        StaffRoleService.nonCombatWeeklyWages(restaurant.staffEntries),
      ],
      1,
    );
    var upkeepPerWeek =
        EconomyService.totalUpgradeUpkeepPerWeek(restaurant.upgrades);
    // V10 (Phase 6): Der Plongeur senkt die laufenden Betriebskosten.
    final upkeepReductionPercent =
        SupportRoleService.upkeepReductionPercent(restaurant.supportStaff);
    if (upkeepReductionPercent != 0) {
      upkeepPerWeek =
          (upkeepPerWeek * (100 - upkeepReductionPercent) / 100).round();
    }

    var budget = restaurant.budget;
    var totalIncome = 0;
    var totalMedic = 0;
    var totalWage = 0;
    var totalUpkeep = 0;
    var totalInterest = 0;
    final settlements = <WeekSettlement>[];
    var cursor = lastSeen;

    for (var i = 0; i < days; i++) {
      final dayInBlock = daysElapsed(weekAnchor, cursor) + 1; // 1 … 7
      final isBlockEnd = dayInBlock >= 7;
      final dailyIncome = isBlockEnd ? incomeLastDayOfBlock : incomePerDay;
      budget += dailyIncome;
      totalIncome += dailyIncome;
      cursor = cursor.add(day);
      // V9 (Phase 3): Je Echtzeit-Tag sinken Vitalität/Moral des Personals.
      _applyDailyResourceSink(restaurant, cursor);

      if (!isBlockEnd) continue;

      // Blockende: wöchentliche Kosten und Zinsen (§ 8/§ 10) – die Zinsen
      // werden auf den jeweiligen Saldo am Blockende angewandt.
      budget -= medicPerWeek;
      totalMedic += medicPerWeek;
      budget -= wagePerWeek;
      totalWage += wagePerWeek;
      budget -= upkeepPerWeek;
      totalUpkeep += upkeepPerWeek;
      final beforeInterest = budget;
      budget = EconomyService.applyNegativeInterest(budget);
      final interest = beforeInterest - budget;
      totalInterest += interest;

      settlements.add(WeekSettlement(
        weekIndex: settlements.length,
        periodStart: weekAnchor,
        periodEnd: weekAnchor.add(week),
        income: incomePerDay * 6 + incomeLastDayOfBlock,
        medicCosts: medicPerWeek,
        staffCosts: wagePerWeek,
        upgradeUpkeep: upkeepPerWeek,
        negativeInterest: interest,
        budgetAfter: budget,
      ));
      // Wochenraster exakt eine Woche weiterziehen (kein Drift).
      weekAnchor = weekAnchor.add(week);
      // V9 (Phase 3): Am Block-Ende werden Vitalität/Moral auf den Basiswert
      // aufgefüllt (deterministisch aus Persönlichkeit + Charakter-ID).
      _refillStaffResources(restaurant);
    }

    // V9 § 6 (Phase 4): ein Proben-Paar je Staffel und Charakter.
    _probeResources(restaurant, now, random ?? Random());

    restaurant.budget = budget;
    restaurant.lastSeenAt = cursor;
    restaurant.weekAnchorAt = weekAnchor;

    // Resttage = volle Tage im noch unfertigen Block nach dem letzten Abschluss.
    final leftoverDays = daysElapsed(weekAnchor, cursor);

    return WeeklyTickResult(
      weeks: settlements.length,
      passiveIncome: totalIncome,
      medicCosts: totalMedic,
      staffCosts: totalWage,
      upgradeUpkeep: totalUpkeep,
      negativeInterest: totalInterest,
      budgetAfter: budget,
      bankrupt: EconomyService.isBankrupt(budget),
      settlements: settlements,
      leftoverDays: leftoverDays,
      leftoverIncome: incomePerDay * leftoverDays,
    );
  }

  // ── Eingangswerte aus dem Restaurant-Zustand (§ 8) ────────────────────

  /// Senkt Vitalität/Moral um den Tages-Sink und pflegt die Null-Anker
  /// (V9 § 6; die Anker sind die Basis des Erschöpfungs-Malus).
  static void _applyDailyResourceSink(RestaurantData restaurant, DateTime now) {
    for (final s in restaurant.staff) {
      if (s.vitalityCurrent != null) {
        final sink = StressService.sink(
            s.vitalityCurrent!, EconomyBalance.resourceSinkPerDay);
        s.vitalityCurrent = sink.value;
        s.vitalityZeroSinceAt = StressService.updateZeroAnchor(
            s.vitalityZeroSinceAt, atZero: sink.atZero, now: now);
      }
      if (s.moraleCurrent != null) {
        final sink = StressService.sink(
            s.moraleCurrent!, EconomyBalance.resourceSinkPerDay);
        s.moraleCurrent = sink.value;
        s.moraleZeroSinceAt = StressService.updateZeroAnchor(
            s.moraleZeroSinceAt, atZero: sink.atZero, now: now);
      }
    }
  }

  /// Setzt Vitalität/Moral am Wochenblock-Ende auf den Trait-Basiswert zurück
  /// (V9, Phase 3; deterministisch über Persönlichkeit + Charakter-ID).
  ///
  /// Zusätzlich wirkt die Support-Station `Pâtissier` (V10 § 2): Ist sie im
  /// Restaurant vertreten, erhalten die **übrigen** Charaktere einen Bonus auf
  /// den Refill (`EconomyBalance.patissierRefillBonusPercent`).
  static void _refillStaffResources(RestaurantData restaurant) {
    final hasPatissier = restaurant.staff.any(
      (s) => s.station == kStationPatissier,
    );
    // V10 (Phase 6): Der Communard stapelt sich additiv mit dem Pâtissier-Bonus.
    final bonusPercent =
        (hasPatissier ? EconomyBalance.patissierRefillBonusPercent : 0) +
            SupportRoleService.refillBonusPercent(restaurant.supportStaff);

    for (final s in restaurant.staff) {
      if (s.personalityId < 0) continue;
      final base = PersonalityTraits.forProfile(s.personalityId, s.id);
      // Der Pâtissier ist Support und profitiert nicht von seiner eigenen Wirkung.
      final ownBonus =
          bonusPercent > 0 && s.station != kStationPatissier ? bonusPercent : 0;
      s.vitalityCurrent = _withRefillBonus(base.vitality, ownBonus);
      s.moraleCurrent = _withRefillBonus(base.morale, ownBonus);
      // Der Refill löscht die Null-Anker – der Malus fällt auf 0 zurück (§ 6).
      s.vitalityZeroSinceAt = null;
      s.moraleZeroSinceAt = null;
    }
  }

  /// Wendet den Pâtissier-Refill-Bonus an und deckelt auf die Ressourcen-Domäne.
  static int _withRefillBonus(int base, int percent) {
    if (percent == 0) return base;
    final boosted = (base * (100 + percent) / 100).round();
    return boosted.clamp(
      EconomyBalance.resourceMin,
      EconomyBalance.resourceMax,
    );
  }

  /// Führt je Charakter ein Proben-Paar für die abgerechnete Staffel aus
  /// (V9 § 6; der Zufall ist injizierbar, V7/L7).
  static void _probeResources(
      RestaurantData restaurant, DateTime now, Random rng) {
    // V10 (Phase 6): Der Tournant senkt den Erschöpfungs-Malus der Nulltage.
    final reliefPercent =
        SupportRoleService.exhaustionReliefPercent(restaurant.supportStaff);
    for (final s in restaurant.staff) {
      final vitality = s.vitalityCurrent;
      final morale = s.moraleCurrent;
      if (vitality == null || morale == null) continue;
      final malus = StressService.malusPercentForStaffData(s, now);
      final relievedMalus = reliefPercent == 0
          ? malus
          : (malus * (100 - reliefPercent) / 100).round();
      final override = StressService.probe(
        vitalityCurrent: vitality,
        moraleCurrent: morale,
        currentProfileId: s.personalityId < 0 ? 0 : s.personalityId,
        random: rng,
        malusPercent: relievedMalus,
      );
      if (override == null) continue;
      s.personalityOverrideId = override.profileId;
      s.personalityOverrideUntil = now.add(override.duration);
      s.personalityOverrideCause = override.cause;
    }
  }

  /// Entfernt abgelaufene Stress-/Ruhe-Overrides (V9 § 6).
  static void _expireOverrides(RestaurantData restaurant, DateTime now) {
    for (final s in restaurant.staff) {
      final until = s.personalityOverrideUntil;
      if (until != null && !now.isBefore(until)) {
        s.personalityOverrideId = -1;
        s.personalityOverrideUntil = null;
        s.personalityOverrideCause = null;
      }
    }
  }

  /// Ø Hilfsbereitschaft des Personals (nur Charaktere mit zugewiesenem Profil).
  static double _staffHelpfulnessAverage(RestaurantData restaurant) {
    if (restaurant.staff.isEmpty) return 0.0;
    var sum = 0.0;
    var n = 0;
    for (final s in restaurant.staff) {
      if (s.personalityId < 0) continue;
      sum += PersonalityTraits.forProfile(s.personalityId, s.id).helpfulness;
      n++;
    }
    return n == 0 ? 0.0 : sum / n;
  }

  /// `true`, wenn dieses Restaurant einen **aktiven** (zugeteilten)
  /// Chef de cuisine führt (Karrierepfade, V10 § 6).
  static bool hasActiveHeadChef(RestaurantData restaurant) =>
      restaurant.staff.any((s) =>
          s.rank == kRankHeadChef && s.headChefRole == kHeadChefRoleActive);

  /// Management-Faktor des aktiven Chef de cuisine auf die drei Werte des
  /// passiven Einkommens (`1.0` ohne aktiven Chef, sonst `1 + Prozent`).
  static double _headChefManagementFactor(RestaurantData restaurant) =>
      hasActiveHeadChef(restaurant)
          ? 1.0 + EconomyBalance.headChefManagementBuffPercent / 100
          : 1.0;

  /// Wochenlohn eines Charakters inkl. Thriftiness-Faktor (V10, Phase 7).
  ///
  /// Alt-Daten ohne Persönlichkeit erhalten den neutralen Faktor (`50`), damit
  /// der Lohn auch ohne Profil deterministisch bleibt.
  static int _staffWagePerWeekOf(StaffData staff) {
    final rank =
        staff.rank.isNotEmpty ? staff.rank : rankFromType(staff.type);
    final thriftiness = staff.personalityId < 0
        ? 50
        : PersonalityTraits.forProfile(staff.personalityId, staff.id)
            .thriftiness;
    return EconomyService.staffWagePerWeek(rank, thriftiness);
  }

  /// Attraktivität: `1 + (Prestige − 1) + Personalanzahl × Kopf-Bonus`,
  /// geclamped auf die Domäne `0–inputDomainMax`. Ein aktiver Rebranding-Malus
  /// (§ 9) wird abgezogen, sofern [now] übergeben wird und noch innerhalb des
  /// Malus-Fensters liegt.
  static double attractivenessOf(RestaurantData restaurant, {DateTime? now}) {
    final prestige = EconomyBalance.districtPrestigeFor(restaurant.district);
    var value = EconomyBalance.attractivenessBase +
        (prestige - 1.0) +
        restaurant.staff.length * EconomyBalance.staffAttractivityPerHead;
    // V9 (Phase 3): Die Hilfsbereitschaft des Personals trägt zur Attraktivität bei.
    value += EconomyBalance.personalityAttractivenessWeight *
        _staffHelpfulnessAverage(restaurant);
    // V10 (Phase 5): Ein aktiver Chef de cuisine führt das Restaurant.
    value *= _headChefManagementFactor(restaurant);
    // V10 (Phase 6): Commis und Garçon de cuisine heben die Attraktivität.
    value += SupportRoleService.attractivenessBonus(restaurant.supportStaff);
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
    final maxSeverity = CharacterStatus.dying.severity;
    return (1.0 - mean / maxSeverity).clamp(0.0, 1.0);
  }

  /// Kundenzufriedenheit: `1 + Teamgesundheit × Gewicht + Ergebnisbonus`,
  /// geclamped auf die Domäne `0–inputDomainMax`.
  static double satisfactionOf(RestaurantData restaurant) {
    var value = EconomyBalance.satisfactionBase +
        teamHealthOf(restaurant) * EconomyBalance.satisfactionHealthWeight +
        _resultBonus(restaurant.lastMatchResult);
    // V10 (Phase 5): Ein aktiver Chef de cuisine hebt die Zufriedenheit.
    value *= _headChefManagementFactor(restaurant);
    // V10 (Phase 6): Der Garçon de cuisine hebt die Zufriedenheit leicht.
    value += SupportRoleService.satisfactionBonus(restaurant.supportStaff);
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
    // V10 (Phase 5): Ein aktiver Chef de cuisine hebt die Kapazität.
    value *= _headChefManagementFactor(restaurant);
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
