import 'dart:math';

import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';
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

  /// Abgebuchte **Strafen** des Blocks (`11a` E14: aufgedeckte Sabotage).
  final int penaltyCosts;

  /// Abgebuchte **laufende Feature-Kosten** des Blocks (V12: „Organisation ist
  /// alles“ je aktivem Tag).
  final int featureCosts;

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
    this.penaltyCosts = 0,
    this.featureCosts = 0,
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

  /// Abgebuchte **Strafen** insgesamt (`11a` E14: aufgedeckte Sabotage).
  final int penaltyCosts;

  /// Abgebuchte **laufende Feature-Kosten** insgesamt (V12).
  final int featureCosts;

  /// Durch **unentdeckte Rivalen-Sabotage** abgeschöpftes Einkommen insgesamt
  /// (V13) – bereits in [passiveIncome] enthalten und dort abgezogen.
  final int rivalSabotageLosses;

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
    this.penaltyCosts = 0,
    this.featureCosts = 0,
    this.rivalSabotageLosses = 0,
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
    RestaurantData restaurant,
    DateTime now,
  ) {
    final perStage = healTimePerStageFor(
      quality: bestMedicQuality(restaurant.medics),
    );
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
    final perStage = healTimePerStageFor(
      quality: bestMedicQuality(restaurant.medics),
    );
    var rolledBack = 0;

    for (final staff in restaurant.staff) {
      final shotAt = staff.emergencyShotAt;
      if (shotAt == null) continue;
      if (now.difference(shotAt) < EconomyBalance.emergencyShotDuration) {
        continue;
      }

      final suppressed = _statusFromName(staff.suppressedStatus);
      final anchor = staff.injuryStartedAt ?? shotAt;
      final healedUnderlying = healedStatus(
        suppressed,
        elapsed(anchor, now),
        perStage,
      );
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
  static WeeklyTickResult catchUp(
    RestaurantData restaurant,
    DateTime now, {
    Random? random,
  }) {
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
      satisfaction: satisfactionOf(restaurant, now: now),
      capacity: capacityOf(restaurant, now: now),
    );
    // V10 (Phase 6)/Option C (`11a`): Aboyeur und Social Media Manager
    // verbessern den Bestellfluss (Einnahmen); beide Zuschläge stapeln additiv.
    final incomeBonusPercent =
        SupportRoleService.incomePercent(restaurant.supportStaff) +
            StaffRoleService.managementIncomePercent(restaurant.staffEntries);
    if (incomeBonusPercent != 0) {
      incomePerWeek = (incomePerWeek * (100 + incomeBonusPercent) / 100)
          .round();
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
    // V12: Der Gewerkschaftschef erhöht die Löhne des Kampfpersonals.
    final brigadeWages = restaurant.staff.map(_staffWagePerWeekOf).toList();
    final unionChiefPercent = StaffRoleService.unionChiefWageIncreasePercent(
      restaurant.staffEntries,
    );
    final adjustedBrigadeWages = unionChiefPercent == 0
        ? brigadeWages
        : brigadeWages
              .map((wage) => (wage * (100 + unionChiefPercent) / 100).round())
              .toList();
    final wagePerWeek = EconomyService.billWeeklyStaffWages([
      ...adjustedBrigadeWages,
      StaffRoleService.nonCombatWeeklyWages(restaurant.staffEntries),
    ], 1);
    var upkeepPerWeek = EconomyService.totalUpgradeUpkeepPerWeek(
      restaurant.upgrades,
    );
    // V10 (Phase 6): Der Plongeur senkt die laufenden Betriebskosten.
    final upkeepReductionPercent = SupportRoleService.upkeepReductionPercent(
      restaurant.supportStaff,
    );
    if (upkeepReductionPercent != 0) {
      upkeepPerWeek = (upkeepPerWeek * (100 - upkeepReductionPercent) / 100)
          .round();
    }

    // `11a` E12: passive Kosten-Minderung der Verwaltungsrollen.
    // Chefsekretärin (−5 %) und Buchhalter (−5 %) mindern die Löhne; „alle
    // laufenden Kosten“ des Buchhalters decken zusätzlich Arztkosten und
    // Erweiterungs-Unterhalt ab. Beide Werte sind binär (Anwesenheit), die
    // Rundung erfolgt kaufmännisch (`StaffRoleService.reduceByPercent`).
    final staffCostReductionPercent =
        StaffRoleService.chefSecretaryStaffCostReductionPercent(
          restaurant.staffEntries,
        ) +
        StaffRoleService.accountantOngoingCostReductionPercent(
          restaurant.staffEntries,
        );
    final ongoingCostReductionPercent =
        StaffRoleService.accountantOngoingCostReductionPercent(
          restaurant.staffEntries,
        );
    final reducedMedicPerWeek = StaffRoleService.reduceByPercent(
      medicPerWeek,
      ongoingCostReductionPercent,
    );
    final reducedWagePerWeek = StaffRoleService.reduceByPercent(
      wagePerWeek,
      staffCostReductionPercent,
    );
    final reducedUpkeepPerWeek = StaffRoleService.reduceByPercent(
      upkeepPerWeek,
      ongoingCostReductionPercent,
    );

    var budget = restaurant.budget;
    var totalIncome = 0;
    var totalMedic = 0;
    var totalWage = 0;
    var totalUpkeep = 0;
    var totalInterest = 0;
    var totalPenalty = 0;
    // V12: im laufenden Block aufgelaufene laufende Feature-Kosten (Tageskosten).
    var totalFeature = 0;
    var featureForBlock = 0;
    // `11a` E16: Tage im laufenden Block, an denen die Kreative Buchführung
    // alle laufenden Kosten negiert (tagesanteilig am Blockende).
    var negatedCostDays = 0;
    // `11a` E14: im laufenden Block aufgelaufene Strafen (Sabotage).
    var penaltyForBlock = 0;
    // `11a` E14: zusätzliche Tageserträge aus einem Sabotage-Fenster.
    var sabotageBonusForBlock = 0;
    // V13: Abschöpfung durch **unentdeckte** Rivalen-Sabotage (je Block).
    var rivalLossForBlock = 0;
    var totalRivalLoss = 0;
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
      // `11a`: Ein aktives Feature schüttet je Tagestick XP an sein Ziel aus
      // (wie nach einem Gefechtssieg) – anker-basiert und damit idempotent.
      _applyFeatureDailyXp(restaurant, cursor);
      // `11a` E16: Kreative Buchführung negiert tagesanteilig die Kosten.
      if (_creativeAccountingActive(restaurant, cursor)) negatedCostDays++;
      // V12: Laufende Tageskosten aktiver Features („Organisation ist alles“).
      featureForBlock += ManagementFeatureService.featureDailyCosts(
        restaurant.staffEntries,
        cursor,
      );
      // `11a` E14: Tagesgenauer Einkommens-Bonus eines Sabotage-Fensters
      // (der Rivale verliert Kunden – die wechseln zum Spieler über).
      final sabotagePercent = RivalService.sabotageIncomeBonusPercent(
        restaurant,
        cursor,
      );
      if (sabotagePercent > 0) {
        final bonus = (dailyIncome * sabotagePercent / 100).round();
        budget += bonus;
        totalIncome += bonus;
        sabotageBonusForBlock += bonus;
      }
      // `11a` E14: fällige Sabotagen werden taggenau aufgelöst (idempotent über
      // `featureResolvedAt`) – Erfolg ⇒ Wirkungsfenster, Misserfolg ⇒ Strafe.
      // Die Strafe wird hier im lokalen Wochenbudget gebucht (die Auflösung
      // selbst fasst `restaurant.budget` nicht an).
      final penalty = _resolveDueSabotage(restaurant, cursor);
      if (penalty > 0) {
        budget -= penalty;
        penaltyForBlock += penalty;
      }

      if (!isBlockEnd) continue;

      // V13: Eingehende Rivalen-Sabotage wird am **Blockende** abgerechnet –
      // deterministisch je Rivale und Blockanker (idempotent, V8). Ein im
      // eigenen Fenster entdeckter Angriff kann den Gegenschlag des
      // Sicherheitschefs auslösen; seine Strafe zählt wie jede andere Strafe
      // zum Block (die Wirkung eines erfolgreichen Gegenschlags läuft als
      // Einkommens-Fenster in den Folgeblock).
      final incoming = RivalService.resolveIncomingSabotage(
        restaurant,
        weekAnchor,
        now: cursor,
      );
      final counterFine = incoming?.counter?.fine ?? 0;
      if (counterFine > 0) {
        budget -= counterFine;
        penaltyForBlock += counterFine;
      }

      // V13: **Unentdeckte** Versuche schöpfen Einkommen ab – je Angreifer
      // `incomingSabotageIncomePenaltyPercent` des Brutto-Blockeinkommens,
      // gedeckelt über `incomingSabotageIncomePenaltyMaxPercent`. Der Angreifer
      // bleibt dabei unbekannt (kein Gegenschlag); die Abschöpfung mindert
      // Blockbudget und ausgewiesenes Einkommen, nicht die Strafen. Das Fenster
      // eines erfolgreichen Gegenschlags läuft erst im Folgeblock.
      final blockIncomeGross =
          incomePerDay * 6 + incomeLastDayOfBlock + sabotageBonusForBlock;
      final rivalPenaltyPercent =
          ((incoming?.undetectedCount ?? 0) *
                  EconomyBalance.incomingSabotageIncomePenaltyPercent)
              .clamp(0, EconomyBalance.incomingSabotageIncomePenaltyMaxPercent);
      rivalLossForBlock = rivalPenaltyPercent == 0
          ? 0
          : (blockIncomeGross * rivalPenaltyPercent / 100).round();
      if (rivalLossForBlock > 0) {
        budget -= rivalLossForBlock;
        totalIncome -= rivalLossForBlock;
        totalRivalLoss += rivalLossForBlock;
      }

      // Blockende: wöchentliche Kosten und Zinsen (§ 8/§ 10) – die Zinsen
      // werden auf den jeweiligen Saldo am Blockende angewandt.
      final blockMedic = _negateCostDays(reducedMedicPerWeek, negatedCostDays);
      final blockWage = _negateCostDays(reducedWagePerWeek, negatedCostDays);
      final blockUpkeep = _negateCostDays(
        reducedUpkeepPerWeek,
        negatedCostDays,
      );
      final blockFeature = _negateCostDays(featureForBlock, negatedCostDays);
      budget -= blockMedic;
      totalMedic += blockMedic;
      budget -= blockWage;
      totalWage += blockWage;
      budget -= blockUpkeep;
      totalUpkeep += blockUpkeep;
      budget -= blockFeature;
      totalFeature += blockFeature;
      final beforeInterest = budget;
      budget = EconomyService.applyNegativeInterest(budget);
      final interest = beforeInterest - budget;
      totalInterest += interest;
      totalPenalty += penaltyForBlock;

      settlements.add(
        WeekSettlement(
          weekIndex: settlements.length,
          periodStart: weekAnchor,
          periodEnd: weekAnchor.add(week),
          income:
              incomePerDay * 6 +
              incomeLastDayOfBlock +
              sabotageBonusForBlock -
              rivalLossForBlock,
          medicCosts: blockMedic,
          staffCosts: blockWage,
          upgradeUpkeep: blockUpkeep,
          negativeInterest: interest,
          penaltyCosts: penaltyForBlock,
          featureCosts: blockFeature,
          budgetAfter: budget,
        ),
      );
      // Wochenraster exakt eine Woche weiterziehen (kein Drift).
      weekAnchor = weekAnchor.add(week);
      negatedCostDays = 0;
      penaltyForBlock = 0;
      sabotageBonusForBlock = 0;
      rivalLossForBlock = 0;
      featureForBlock = 0;
      // V9 (Phase 3): Am Block-Ende werden Vitalität/Moral auf den Basiswert
      // aufgefüllt (deterministisch aus Persönlichkeit + Charakter-ID).
      // `11a`: In der Nachteilphase eines Features nur mit halbem Delta.
      _refillStaffResources(restaurant, cursor);
    }

    // V9 § 6 (Phase 4): ein Proben-Paar je Staffel und Charakter.
    _probeResources(restaurant, now, random ?? Random());

    // `11a`: Abgelaufene Features (aktive Phase **und** Nachteilphase beendet)
    // werden zurückgesetzt, damit der Träger neu aktivieren kann.
    ManagementFeatureService.clearFinished(restaurant.staffEntries, cursor);

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
      penaltyCosts: totalPenalty,
      featureCosts: totalFeature,
      rivalSabotageLosses: totalRivalLoss,
      budgetAfter: budget,
      bankrupt: EconomyService.isBankrupt(budget),
      settlements: settlements,
      leftoverDays: leftoverDays,
      leftoverIncome: incomePerDay * leftoverDays,
    );
  }

  /// `true`, wenn die **Kreative Buchführung** zum Zeitpunkt [now] läuft
  /// (negiert die laufenden Kosten des Tages, `11a` E16).
  static bool _creativeAccountingActive(
    RestaurantData restaurant,
    DateTime now,
  ) =>
      ManagementFeatureService.activeEntry(
        restaurant.staffEntries,
        ManagementFeature.creativeAccounting,
        now,
      ) !=
      null;

  /// Mindert [amount] um den Tagesanteil der negierten Kostentage eines Blocks
  /// (`negatedDays` von 7) – kaufmännisch gerundet (`11a` E16).
  static int _negateCostDays(int amount, int negatedDays) {
    if (negatedDays <= 0) return amount;
    if (negatedDays >= 7) return 0;
    return amount - (amount * negatedDays / 7).round();
  }

  /// Löst alle fälligen Sabotagen des Restaurants zum Zeitpunkt [now] auf und
  /// gibt die dabei aufgelaufenen Strafen zurück (`11a` E14).
  static int _resolveDueSabotage(RestaurantData restaurant, DateTime now) {
    var penalties = 0;
    for (final entry in restaurant.staffEntries) {
      final outcome = RivalService.resolveSabotage(restaurant, entry, now);
      if (outcome != null) penalties += outcome.fine;
    }
    return penalties;
  }

  // ── Eingangswerte aus dem Restaurant-Zustand (§ 8) ────────────────────

  /// Senkt Vitalität/Moral um den Tages-Sink und pflegt die Null-Anker
  /// (V9 § 6; die Anker sind die Basis des Erschöpfungs-Malus).
  ///
  /// V12: Der passive Gewerkschaftschef und die aktiven Features „Rush Hour“
  /// bzw. „Lagertetris“ (Mali entfallen) sowie „Organisation ist alles“ senken
  /// den Sink; die „Rush Hour“ erzeugt zusätzlich eine **rangverteilte**
  /// Erschöpfungslast.
  static void _applyDailyResourceSink(RestaurantData restaurant, DateTime now) {
    // `11a`: In der Nachteilphase eines Features sinkt die Ressource des
    // Kampagnen-Ziels doppelt (`featureAftermathSinkMultiplier`).
    final multipliers = ManagementFeatureService.aftermathSinkMultipliers(
      restaurant.staffEntries,
      now,
    );
    // V12: prozentuale Sink-Senkung (Gewerkschaftschef + Feature-Mali).
    final reliefPercent = ManagementFeatureService.sinkReliefPercent(
      restaurant.staffEntries,
      now,
    );
    // V12: Zusatzlast der „Rush Hour“, ranggewichtet verteilt.
    final extraSink = _rushHourExhaustionShares(restaurant, now);
    for (final s in restaurant.staff) {
      final multiplier = multipliers[s.id] ?? 1;
      var sinkAmount = EconomyBalance.resourceSinkPerDay * multiplier;
      if (reliefPercent > 0) {
        sinkAmount = (sinkAmount * (100 - reliefPercent) / 100).round();
      }
      sinkAmount += extraSink[s.id] ?? 0;
      if (sinkAmount <= 0) continue;
      if (s.vitalityCurrent != null) {
        final sink = StressService.sink(s.vitalityCurrent!, sinkAmount);
        s.vitalityCurrent = sink.value;
        s.vitalityZeroSinceAt = StressService.updateZeroAnchor(
          s.vitalityZeroSinceAt,
          atZero: sink.atZero,
          now: now,
        );
      }
      if (s.moraleCurrent != null) {
        final sink = StressService.sink(s.moraleCurrent!, sinkAmount);
        s.moraleCurrent = sink.value;
        s.moraleZeroSinceAt = StressService.updateZeroAnchor(
          s.moraleZeroSinceAt,
          atZero: sink.atZero,
          now: now,
        );
      }
    }
  }

  /// Verteilt die Zusatzlast einer aktiven „Rush Hour“ **ranggewichtet** auf das
  /// Personal (V12: „von oben herab“): höhere Ränge tragen mehr als niedrigere,
  /// und je mehr Mitarbeiter anwesend sind, desto geringer die Last des
  /// Einzelnen. Der Rundungsrest geht deterministisch an den ranghöchsten
  /// Charakter.
  static Map<int, int> _rushHourExhaustionShares(
    RestaurantData restaurant,
    DateTime now,
  ) {
    final total = ManagementFeatureService.rushHourExtraSink(
      restaurant.staffEntries,
      now,
    );
    if (total <= 0 || restaurant.staff.isEmpty) return const {};

    final weights = <int, int>{};
    var weightSum = 0;
    for (final s in restaurant.staff) {
      final rank = s.rank.isNotEmpty ? s.rank : rankFromType(s.type);
      final weight = EconomyService.promotionLevel(rank) + 1;
      weights[s.id] = weight;
      weightSum += weight;
    }
    if (weightSum <= 0) return const {};

    final shares = <int, int>{};
    var assigned = 0;
    for (final s in restaurant.staff) {
      final share = total * weights[s.id]! ~/ weightSum;
      shares[s.id] = share;
      assigned += share;
    }
    if (assigned < total) {
      var bestId = restaurant.staff.first.id;
      var bestWeight = -1;
      for (final s in restaurant.staff) {
        final weight = weights[s.id]!;
        if (weight > bestWeight) {
          bestWeight = weight;
          bestId = s.id;
        }
      }
      shares[bestId] = (shares[bestId] ?? 0) + (total - assigned);
    }
    return shares;
  }

  /// Setzt Vitalität/Moral am Wochenblock-Ende auf den Trait-Basiswert zurück
  /// (V9, Phase 3; deterministisch über Persönlichkeit + Charakter-ID).
  ///
  /// Zusätzlich wirkt die Support-Station `Pâtissier` (V10 § 2): Ist sie im
  /// Restaurant vertreten, erhalten die **übrigen** Charaktere einen Bonus auf
  /// den Refill (`EconomyBalance.patissierRefillBonusPercent`).
  static void _refillStaffResources(RestaurantData restaurant, DateTime now) {
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
      // `11a`: In der Nachteilphase regeneriert das Kampagnen-Ziel nur halb.
      final fraction = ManagementFeatureService.refillFractionFor(
        restaurant.staffEntries,
        s.id,
        now,
      );
      s.vitalityCurrent = _refilledValue(
        _withRefillBonus(base.vitality, ownBonus),
        s.vitalityCurrent,
        fraction,
      );
      s.moraleCurrent = _refilledValue(
        _withRefillBonus(base.morale, ownBonus),
        s.moraleCurrent,
        fraction,
      );
      // Der Refill löscht die Null-Anker – der Malus fällt auf 0 zurück (§ 6).
      s.vitalityZeroSinceAt = null;
      s.moraleZeroSinceAt = null;
    }
  }

  /// Füllt [current] auf [base] auf; bei [fraction] `< 1` nur um diesen Anteil
  /// des Deltas (Nachteilphase eines Features, `11a`).
  static int _refilledValue(int base, int? current, double fraction) {
    if (fraction >= 1.0 || current == null || base <= current) return base;
    final refilled = current + ((base - current) * fraction).round();
    return refilled.clamp(
      EconomyBalance.resourceMin,
      EconomyBalance.resourceMax,
    );
  }

  /// Schüttet je abgerechnetem Tagestick XP an das Kampagnen-Ziel eines aktiven
  /// Features aus (`11a`).
  ///
  /// Der Betrag entspricht einem Gefechtssieg (`EconomyService.xpForBattle`) und
  /// wird um den Kompetenz-Zuschlag des Trägers erhöht. Die Aufstiegslogik läuft
  /// zentral über [`EconomyService.grantXp`].
  static void _applyFeatureDailyXp(RestaurantData restaurant, DateTime now) {
    for (final feature in kAllManagementFeatures) {
      final entry = ManagementFeatureService.activeEntry(
        restaurant.staffEntries,
        feature,
        now,
      );
      final targetId = entry?.featureTargetId;
      if (entry == null || targetId == null) continue;
      final target = _staffById(restaurant, targetId);
      if (target == null) continue;
      final boost = ManagementFeatureService.boostPercentFor(
        ManagementFeatureService.competenceOf(entry),
      );
      final xp = EconomyService.boostedXp(
        ManagementFeatureService.dailyXpFor(target.levelValue),
        boost,
      );
      if (xp <= 0) continue;
      final grant = EconomyService.grantXp(
        level: target.levelValue,
        currentXp: target.currentXPValue,
        xp: xp,
      );
      target.levelValue = grant.level;
      target.currentXPValue = grant.currentXp;
    }
  }

  /// Charakter aus [restaurant] mit der stabilen [staffId] (oder `null`).
  static StaffData? _staffById(RestaurantData restaurant, int staffId) {
    for (final s in restaurant.staff) {
      if (s.id == staffId) return s;
    }
    return null;
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
    RestaurantData restaurant,
    DateTime now,
    Random rng,
  ) {
    // V10 (Phase 6): Der Tournant senkt den Erschöpfungs-Malus der Nulltage.
    // V12: Der Gewerkschaftschef und die aktiven Features „Rush Hour“/
    // „Lagertetris“ (Mali entfallen) sowie „Organisation ist alles“ senken ihn
    // zusätzlich (additiv, auf 100 % gedeckelt).
    final reliefPercent =
        (SupportRoleService.exhaustionReliefPercent(restaurant.supportStaff) +
                ManagementFeatureService.malusReliefPercent(
                  restaurant.staffEntries,
                  now,
                ))
            .clamp(0, 100);
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
      restaurant.staff.any(
        (s) => s.rank == kRankHeadChef && s.headChefRole == kHeadChefRoleActive,
      );

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
        : PersonalityTraits.forProfile(
            staff.personalityId,
            staff.id,
          ).thriftiness;
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
    // V12: Der Oberkellner hebt die Attraktivität (binär).
    value += StaffRoleService.headWaiterAttractivenessBonus(
      restaurant.staffEntries,
    );
    // V12: Eine aktive „Rush Hour“ hebt alle Eingangswerte befristet an.
    if (now != null) {
      final boost = ManagementFeatureService.inputBoostPercent(
        restaurant.staffEntries,
        now,
      );
      if (boost != 0) value *= 1.0 + boost / 100;
    }
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
  ///
  /// [now] aktiviert die befristeten V12-Zuschläge (Personalchef-Passiv wirkt
  /// unabhängig davon; „Rush Hour“ nur innerhalb der Wirkdauer).
  static double satisfactionOf(RestaurantData restaurant, {DateTime? now}) {
    var value =
        EconomyBalance.satisfactionBase +
        teamHealthOf(restaurant) * EconomyBalance.satisfactionHealthWeight +
        _resultBonus(restaurant.lastMatchResult);
    // V10 (Phase 5): Ein aktiver Chef de cuisine hebt die Zufriedenheit.
    value *= _headChefManagementFactor(restaurant);
    // V10 (Phase 6): Der Garçon de cuisine hebt die Zufriedenheit leicht.
    value += SupportRoleService.satisfactionBonus(restaurant.supportStaff);
    // V12: Der Personalchef hebt die Zufriedenheit (binär).
    value += StaffRoleService.personnelManagerSatisfactionBonus(
      restaurant.staffEntries,
    );
    // V12: Eine aktive „Rush Hour“ hebt alle Eingangswerte befristet an.
    if (now != null) {
      final boost = ManagementFeatureService.inputBoostPercent(
        restaurant.staffEntries,
        now,
      );
      if (boost != 0) value *= 1.0 + boost / 100;
    }
    value *=
        1.0 + EconomyService.upgradeEffects(restaurant.upgrades).satisfaction;
    return value.clamp(0.0, EconomyBalance.inputDomainMax);
  }

  /// Kapazität: `Ø(moneyValue des Personals) / Norm`, geclamped auf
  /// `0–capacityMax`. Ohne Personal: 0.
  ///
  /// V12: Oberkellner, Personalchef und Lagerist heben die Kapazität prozentual;
  /// eine aktive „Rush Hour“ hebt alle Eingangswerte, ein aktives „Lagertetris“
  /// vervielfacht die Kapazität.
  static double capacityOf(RestaurantData restaurant, {DateTime? now}) {
    if (restaurant.staff.isEmpty) return 0.0;
    final sum = restaurant.staff
        .map((s) => s.moneyValue)
        .fold<int>(0, (a, b) => a + b);
    final mean = sum / restaurant.staff.length;
    var value = mean / EconomyBalance.capacityMoneyNorm;
    // V10 (Phase 5): Ein aktiver Chef de cuisine hebt die Kapazität.
    value *= _headChefManagementFactor(restaurant);
    // V12: passive Kapazitäts-Zuschläge der Verwaltungsrollen.
    final capacityPercent = StaffRoleService.capacityPercent(
      restaurant.staffEntries,
    );
    if (capacityPercent != 0) value *= 1.0 + capacityPercent / 100;
    if (now != null) {
      final boost = ManagementFeatureService.inputBoostPercent(
        restaurant.staffEntries,
        now,
      );
      if (boost != 0) value *= 1.0 + boost / 100;
      value *= ManagementFeatureService.capacityFactor(
        restaurant.staffEntries,
        now,
      );
    }
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
