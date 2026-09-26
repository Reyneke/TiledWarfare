import 'dart:math' as math;

import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Auswertung der **aktiven Features** spezieller Nicht-Kampf-Mitarbeiter
/// (Option C, `11a`).
///
/// Features sind eine dokumentierte **Ausnahme** zur binären Passiv-Wirkung der
/// Rollen: Sie werden aktiv ausgelöst, kosten einmalig Geld und laufen über zwei
/// befristete Phasen – die **aktive Phase** (XP-Boost für ein Ziel) und die
/// **Nachteilphase** (verdoppelter Tages-Sink, halbierter Wochen-Refill).
///
/// Alle Funktionen sind reine Funktionen über die Personal-Liste plus einem
/// injizierten `now` und damit ohne Widgets testbar; die Tuning-Werte liegen in
/// `EconomyBalance`. Die Zeitrechnung ist **anker-basiert** (`featureActivatedAt`)
/// und damit idempotent – ein zweiter Lauf mit demselben `now` ändert nichts.
class ManagementFeatureService {
  ManagementFeatureService._();

  /// Deterministische Kompetenz-Stufe des Feature-Trägers (Domäne
  /// `featureCompetenceMin`–`featureCompetenceMax`).
  ///
  /// Abgeleitet aus der stabilen Personal-ID – kein Zufall, kein Pool; damit
  /// über Ladevorgänge hinweg reproduzierbar.
  static int competenceOf(StaffEntryData entry) {
    final span =
        EconomyBalance.featureCompetenceMax -
        EconomyBalance.featureCompetenceMin +
        1;
    if (span <= 1) return EconomyBalance.featureCompetenceMin;
    return EconomyBalance.featureCompetenceMin + (entry.id.abs() % span);
  }

  /// XP-Zuschlag (Prozent) für [competence].
  static int boostPercentFor(int competence) =>
      competence * EconomyBalance.featureCompetenceBoostPercentPerStep;

  /// Einmalkosten der Aktivierung für ein Ziel auf [targetLevel].
  static int featureCostFor(int targetLevel) =>
      math.max(1, targetLevel) * EconomyBalance.featureCostPerLevel;

  /// XP-Bonus eines Tagesticks „wie nach einem Gefechtssieg“.
  static int dailyXpFor(int level) =>
      EconomyService.xpForBattle(won: true, level: level);

  /// Ende der **aktiven** Phase von [entry] (oder `null`).
  static DateTime? activeEndOf(StaffEntryData entry) {
    final start = entry.featureActivatedAt;
    return start?.add(activeDurationOf(entry));
  }

  /// Ende der **Nachteilphase** von [entry] (oder `null`).
  static DateTime? aftermathEndOf(StaffEntryData entry) {
    final end = activeEndOf(entry);
    return end?.add(aftermathDurationOf(entry));
  }

  /// Dauer der **aktiven** Phase des von [entry] getragenen Features.
  ///
  /// Feature-spezifisch (`11a` E14–E16); die PR-Kampagne nutzt unverändert die
  /// generischen Fenster aus `EconomyBalance`. Die Kompetenz-abhängigen Fenster
  /// (Kreative Buchführung) leiten sich aus [competenceOf] ab.
  static Duration activeDurationOf(StaffEntryData entry) {
    final feature = managementFeatureFromName(entry.activeFeature);
    switch (feature) {
      case ManagementFeature.sabotage:
        return EconomyBalance.sabotageActiveDuration;
      case ManagementFeature.legalTrick:
        return EconomyBalance.legalTrickActiveDuration;
      case ManagementFeature.creativeAccounting:
        return EconomyBalance.creativeAccountingPerCompetence *
            competenceOf(entry);
      case ManagementFeature.rushHour:
        return EconomyBalance.rushHourPerCompetence * competenceOf(entry);
      case ManagementFeature.organisationIsEverything:
        return EconomyBalance.organisationPerCompetence * competenceOf(entry);
      case ManagementFeature.storageTetris:
        return EconomyBalance.storageTetrisActiveDuration;
      case ManagementFeature.unionWorkers:
        return EconomyBalance.unionWorkersActiveDuration;
      case ManagementFeature.counterSabotage:
        return EconomyBalance.counterSabotageActiveDuration;
      case ManagementFeature.prCampaign:
      case null:
        return EconomyBalance.featureActiveDuration;
    }
  }

  /// Dauer der **Nachteilphase** des von [entry] getragenen Features.
  static Duration aftermathDurationOf(StaffEntryData entry) {
    final feature = managementFeatureFromName(entry.activeFeature);
    switch (feature) {
      case ManagementFeature.sabotage:
        return EconomyBalance.sabotageAftermathDuration;
      case ManagementFeature.counterSabotage:
        return EconomyBalance.counterSabotageAftermathDuration;
      case ManagementFeature.legalTrick:
        return EconomyBalance.legalTrickAftermathDuration;
      case ManagementFeature.creativeAccounting:
        return EconomyBalance.creativeAccountingAftermathPerCompetence *
            competenceOf(entry);
      case ManagementFeature.rushHour:
      case ManagementFeature.organisationIsEverything:
      case ManagementFeature.storageTetris:
      case ManagementFeature.unionWorkers:
        // Die V12-Features haben keine Nachteilphase (die Kosten bzw. die
        // Erschöpfung fallen während der Wirkdauer an).
        return Duration.zero;
      case ManagementFeature.prCampaign:
      case null:
        return EconomyBalance.featureAftermathDuration;
    }
  }

  /// Feste Einmalkosten eines ziel-losen Features (oder `null`, wenn die Kosten
  /// mit dem Ziel oder der Kompetenz skalieren – PR-Kampagne, E9; Lagertetris,
  /// „Organisation ist alles“, V12).
  static int? fixedCostOf(ManagementFeature feature) => switch (feature) {
    ManagementFeature.sabotage => EconomyBalance.sabotageCost,
    ManagementFeature.legalTrick => EconomyBalance.legalTrickCost,
    ManagementFeature.creativeAccounting =>
      EconomyBalance.creativeAccountingCost,
    ManagementFeature.rushHour => EconomyBalance.rushHourCost,
    ManagementFeature.unionWorkers => EconomyBalance.unionWorkersCost,
    ManagementFeature.counterSabotage => EconomyBalance.counterSabotageCost,
    ManagementFeature.organisationIsEverything => null,
    ManagementFeature.storageTetris => null,
    ManagementFeature.prCampaign => null,
  };

  /// Einmalkosten der Aktivierung von [feature] durch den Träger [entry].
  ///
  /// „Organisation ist alles“ kostet nichts im Voraus – sie wird **je aktivem
  /// Tag** bezahlt (`featureDailyCosts`, `V12`). „Lagertetris“ skaliert mit der
  /// Kompetenz (`storageTetrisCostPerCompetence`).
  static int activationCostFor(
    ManagementFeature feature,
    StaffEntryData entry,
  ) {
    final fixed = fixedCostOf(feature);
    if (fixed != null) return fixed;
    if (feature == ManagementFeature.storageTetris) {
      return competenceOf(entry) *
          EconomyBalance.storageTetrisCostPerCompetence;
    }
    return 0;
  }

  /// Erfolgswahrscheinlichkeit einer Sabotage (Prozent) für den Träger [entry]:
  /// Grundwert plus Kompetenz-Zuschlag (E14).
  static int sabotageSuccessPercentFor(StaffEntryData entry) =>
      EconomyBalance.sabotageBaseSuccessPercent +
      competenceOf(entry) * EconomyBalance.sabotageSuccessPercentPerStep;

  /// Deterministischer Wurf (0–99) einer Sabotage auf den Rivalen [rivalId].
  ///
  /// Abgeleitet aus Träger-ID, Anker der Aktivierung, Rivalen-ID und
  /// Versuchs-Nummer – **kein** Zufall im Catch-up (V8-Idempotenz). Die
  /// Versuchs-Nummer (`attempt`, ab 0) bildet den **Reroll** je zusätzlichem
  /// Teammitglied ab („Alle Räder …“, V12).
  static int sabotageRollFor(
    StaffEntryData entry,
    int rivalId, {
    int attempt = 0,
  }) {
    final anchor = entry.featureActivatedAt?.toIso8601String() ?? '';
    return CRC32
            .compute('sabotage:${entry.id}:$rivalId:$anchor:$attempt')
            .abs() %
        100;
  }

  /// `true`, wenn die Sabotage von [entry] gegen [rivalId] gelingt.
  ///
  /// Bei [attempts] `> 1` genügt ein erfolgreicher Versuch (Reroll je
  /// zusätzlichem Teammitglied, V12); `attempts: 1` ist das unveränderte
  /// Verhalten aus `11a` E14.
  static bool sabotageSucceeds(
    StaffEntryData entry,
    int rivalId, {
    int attempts = 1,
    int? chancePercent,
  }) {
    final chance = chancePercent ?? sabotageSuccessPercentFor(entry);
    final tries = attempts < 1 ? 1 : attempts;
    for (var attempt = 0; attempt < tries; attempt++) {
      if (sabotageRollFor(entry, rivalId, attempt: attempt) < chance) {
        return true;
      }
    }
    return false;
  }

  /// `shadiness`-Bonus (Prozent) auf die Sabotage-Erfolgschance aus der
  /// **gemittelten** `shadiness` der Beteiligten (V12).
  ///
  /// Linear zwischen den Extremwerten: `0` (`−shadinessMaxBonusPercent`) über
  /// `shadinessNeutral` (`0`) bis `100` (`+shadinessMaxBonusPercent`). Ohne
  /// Beteiligte (`teamIds` leer bzw. keine Shadiness bekannt) → `0`.
  static int shadinessBonusPercent(
    Iterable<int> teamIds,
    Map<int, int> shadinessById,
  ) {
    var sum = 0;
    var count = 0;
    for (final id in teamIds) {
      final shadiness = shadinessById[id];
      if (shadiness == null) continue;
      sum += shadiness;
      count++;
    }
    if (count == 0) return 0;
    final average = sum / count;
    return ((average - EconomyBalance.shadinessNeutral) *
            EconomyBalance.shadinessMaxBonusPercent /
            EconomyBalance.shadinessNeutral)
        .round();
  }

  /// Mannschafts-IDs des Trägers von „Alle Räder …“ zum Zeitpunkt [now]
  /// (leer, wenn das Feature nicht aktiv ist).
  static List<int> unionWorkersTeamIds(
    Iterable<StaffEntryData> entries,
    DateTime now,
  ) {
    final entry = activeEntry(entries, ManagementFeature.unionWorkers, now);
    final ids = entry?.featureTeamIds;
    return ids == null ? const [] : List<int>.unmodifiable(ids);
  }

  /// Größe der Sabotage-Mannschaft zum Zeitpunkt [now]: ohne „Alle Räder …“
  /// genau `1`, sonst `1 + Anzahl der gewählten Mitglieder`. Die Mitgliederzahl
  /// ist bereits bei der Aktivierung auf die Kompetenz begrenzt.
  static int sabotageTeamSize(Iterable<StaffEntryData> entries, DateTime now) {
    final team = unionWorkersTeamIds(entries, now);
    return 1 + team.length;
  }

  /// Anzahl der Sabotage-Versuche (ein Reroll je zusätzlichem Teammitglied).
  static int sabotageAttempts(Iterable<StaffEntryData> entries, DateTime now) =>
      sabotageTeamSize(entries, now);

  /// Erschöpfung, die **jedes** beteiligte Teammitglied eines Sabotage-Auftrags
  /// trifft (Vitalität **und** Moral): `sabotageExhaustionPerMission` gemittelt
  /// über die Mannschaftsgröße (mindestens `1`, wenn überhaupt jemand dabei ist).
  static int sabotageExhaustionPerMember(int teamSize) {
    if (teamSize <= 0) return 0;
    final share = EconomyBalance.sabotageExhaustionPerMission ~/ teamSize;
    return share < 1 ? 1 : share;
  }

  /// Strafen-Minderung eines aktiven **Winkelzugs** (Prozent): Kompetenz ×
  /// `legalTrickPenaltyReductionPercentPerStep` (E15).
  static int legalTrickReductionPercentFor(StaffEntryData entry) =>
      competenceOf(entry) *
      EconomyBalance.legalTrickPenaltyReductionPercentPerStep;

  // ── Sicherheitschef / „Rache ist Blutwurst“ (V13) ──────────────────────

  /// Entdeckungs-Zuschlag (Prozent) des passiven **Sicherheitschefs**:
  /// höchste Kompetenz-Stufe × `securityChiefDetectionBonusPercentPerCompetence`
  /// (`0` ohne Träger). Analog zum passiven Gewerkschaftschef.
  static int securityChiefDetectionBonusPercent(
    Iterable<StaffEntryData> entries,
  ) {
    var best = 0;
    for (final entry in entries) {
      if (entry.kind != RoleKind.management) continue;
      if (entry.role != ManagementRole.securityChief.name) continue;
      final competence = competenceOf(entry);
      if (competence > best) best = competence;
    }
    return best * EconomyBalance.securityChiefDetectionBonusPercentPerCompetence;
  }

  /// Maximale Mannschaftsgröße eines Gegenschlags des Trägers [leader]
  /// (Kompetenz × `counterSabotageTeamPerCompetence`).
  static int counterSabotageTeamLimit(StaffEntryData leader) =>
      competenceOf(leader) * EconomyBalance.counterSabotageTeamPerCompetence;

  /// Grund-Erfolgschance (Prozent) eines Gegenschlags des Trägers [leader]:
  /// `sabotageBaseSuccessPercent` plus Kompetenz-Zuschlag (V13).
  static int counterSabotageSuccessPercentFor(StaffEntryData leader) =>
      EconomyBalance.sabotageBaseSuccessPercent +
      competenceOf(leader) *
          EconomyBalance.counterSabotageLeaderBonusPercentPerCompetence;

  /// Deterministischer Wurf (0–99) eines Gegenschlags auf den Angreifer
  /// [rivalId] zum Anker [anchor].
  ///
  /// Eigener Namensraum (`counter-sabotage:`) – der Wurf korreliert damit
  /// **nicht** mit der regulären Sabotage; `attempt` bildet einen Reroll ab.
  static int counterSabotageRollFor(
    StaffEntryData leader,
    DateTime anchor,
    int rivalId, {
    int attempt = 0,
  }) {
    final stamp = anchor.toIso8601String();
    return CRC32
            .compute('counter-sabotage:${leader.id}:$rivalId:$stamp:$attempt')
            .abs() %
        100;
  }

  /// `true`, wenn der Gegenschlag des Trägers [leader] gegen den Angreifer
  /// [rivalId] gelingt ([attempts] Versuche, Erfolg beim ersten Treffer).
  static bool counterSabotageSucceeds(
    StaffEntryData leader,
    DateTime anchor,
    int rivalId, {
    int attempts = 1,
    int? chancePercent,
  }) {
    final chance = chancePercent ?? counterSabotageSuccessPercentFor(leader);
    final tries = attempts < 1 ? 1 : attempts;
    for (var attempt = 0; attempt < tries; attempt++) {
      if (counterSabotageRollFor(leader, anchor, rivalId, attempt: attempt) <
          chance) {
        return true;
      }
    }
    return false;
  }

  /// `true`, wenn das **ziel-lose** Feature [feature] zum Zeitpunkt [now]
  /// scharf geschaltet ist, aber noch **nicht** aufgelöst wurde (kein
  /// `featureResolvedAt`).
  ///
  /// Für das reaktive „Rache ist Blutwurst“ (V13): Trifft im Fenster kein
  /// entdeckter Angriff ein, bleibt der Marker leer und das Fenster verfällt.
  static bool isArmed(
    Iterable<StaffEntryData> entries,
    ManagementFeature feature,
    DateTime now,
  ) {
    final entry = activeEntry(entries, feature, now);
    return entry != null && entry.featureResolvedAt == null;
  }

  /// `true`, wenn der Träger [entry] sein Feature zum Zeitpunkt [now] **aktiv**
  /// trägt (Fenster `[start, start + activeDuration]`, inklusiv).
  static bool isActiveFor(StaffEntryData entry, DateTime now) {
    if (entry.activeFeature == null) return false;
    final start = entry.featureActivatedAt;
    final end = activeEndOf(entry);
    if (start == null || end == null) return false;
    return !now.isBefore(start) && !now.isAfter(end);
  }

  /// `true`, wenn ein **tick-aufgelöstes** Feature (Sabotage, E14) fällig ist:
  /// Die aktive Phase ist vorbei, aber die Auflösung wurde noch nicht gebucht.
  static bool isResolutionDue(StaffEntryData entry, DateTime now) {
    if (entry.featureResolvedAt != null) return false;
    final end = activeEndOf(entry);
    return end != null && !now.isBefore(end);
  }

  /// Träger-Eintrag eines Features: der Management-Eintrag, dessen Rolle das
  /// Feature liefert (oder `null`).
  static StaffEntryData? ownerOf(
    Iterable<StaffEntryData> entries,
    ManagementFeature feature,
  ) {
    for (final entry in entries) {
      if (entry.kind != RoleKind.management) continue;
      final role = managementRoleFromName(entry.role);
      if (role != null && managementFeatureOf(role) == feature) return entry;
    }
    return null;
  }

  /// `true`, wenn [feature] zum Zeitpunkt [now] **aktiv** ist.
  ///
  /// Das Fenster ist **inklusiv** über eine volle Woche definiert
  /// (`[activatedAt, activatedAt + featureActiveDuration]`), damit genau sieben
  /// Tagesticks in die aktive Phase fallen.
  static bool isActive(
    Iterable<StaffEntryData> entries,
    ManagementFeature feature,
    DateTime now,
  ) => activeEntry(entries, feature, now) != null;

  /// Träger-Eintrag, solange [feature] zum Zeitpunkt [now] aktiv ist.
  static StaffEntryData? activeEntry(
    Iterable<StaffEntryData> entries,
    ManagementFeature feature,
    DateTime now,
  ) {
    final owner = ownerOf(entries, feature);
    if (owner == null) return null;
    if (owner.activeFeature != feature.name) return null;
    final start = owner.featureActivatedAt;
    final end = activeEndOf(owner);
    if (start == null || end == null) return null;
    return !now.isBefore(start) && !now.isAfter(end) ? owner : null;
  }

  /// Träger-Eintrag, solange [feature] zum Zeitpunkt [now] in der
  /// **Nachteilphase** ist (`(activatedAt + featureActiveDuration,
  /// activatedAt + featureActiveDuration + featureAftermathDuration]`).
  static StaffEntryData? aftermathEntry(
    Iterable<StaffEntryData> entries,
    ManagementFeature feature,
    DateTime now,
  ) {
    final owner = ownerOf(entries, feature);
    if (owner == null) return null;
    if (owner.activeFeature != feature.name) return null;
    final start = activeEndOf(owner);
    final end = aftermathEndOf(owner);
    if (start == null || end == null) return null;
    return now.isAfter(start) && !now.isAfter(end) ? owner : null;
  }

  /// `true`, wenn beide Phasen von [entry] zum Zeitpunkt [now] abgelaufen sind.
  static bool isFinished(StaffEntryData entry, DateTime now) {
    final end = aftermathEndOf(entry);
    return end != null && now.isAfter(end);
  }

  /// Setzt abgelaufene Features zurück (beide Phasen beendet) – danach kann neu
  /// aktiviert werden. Die Einträge werden **in place** verändert.
  static void clearFinished(Iterable<StaffEntryData> entries, DateTime now) {
    for (final entry in entries) {
      if (entry.featureActivatedAt == null) continue;
      if (!isFinished(entry, now)) continue;
      entry.activeFeature = null;
      entry.featureTargetId = null;
      entry.featureActivatedAt = null;
      entry.featureResolvedAt = null;
      entry.featureTeamIds = null;
    }
  }

  /// Faktor auf den Tages-Sink je Ziel-Charakter-ID: `featureAftermathSinkMultiplier`
  /// für Ziele in der Nachteilphase, sonst `1`.
  static Map<int, int> aftermathSinkMultipliers(
    Iterable<StaffEntryData> entries,
    DateTime now,
  ) {
    final result = <int, int>{};
    for (final feature in kAllManagementFeatures) {
      final entry = aftermathEntry(entries, feature, now);
      final targetId = entry?.featureTargetId;
      if (targetId == null) continue;
      result[targetId] = EconomyBalance.featureAftermathSinkMultiplier;
    }
    return result;
  }

  /// Anteil des Refill-Deltas, der [staffId] zum Zeitpunkt [now] zusteht
  /// (`1.0` normal, `featureAftermathRefillFraction` in der Nachteilphase).
  static double refillFractionFor(
    Iterable<StaffEntryData> entries,
    int staffId,
    DateTime now,
  ) {
    for (final feature in kAllManagementFeatures) {
      final entry = aftermathEntry(entries, feature, now);
      if (entry != null && entry.featureTargetId == staffId) {
        return EconomyBalance.featureAftermathRefillFraction;
      }
    }
    return 1.0;
  }

  /// Prozentualer XP-Zuschlag für [staffId] – `0`, wenn kein Feature aktiv ist
  /// oder [staffId] nicht das Kampagnen-Ziel ist.
  static int xpBoostPercentFor(
    Iterable<StaffEntryData> entries,
    int staffId,
    DateTime now,
  ) {
    for (final feature in kAllManagementFeatures) {
      final entry = activeEntry(entries, feature, now);
      if (entry != null && entry.featureTargetId == staffId) {
        return boostPercentFor(competenceOf(entry));
      }
    }
    return 0;
  }

  // ── Wirkungen der V12-Features ─────────────────────────────────────────

  /// Prozentualer Zuschlag auf die drei Eingangswerte des passiven Einkommens
  /// (Attraktivität, Zufriedenheit, Kapazität) durch ein aktives **Rush Hour**
  /// (`0` außerhalb der Wirkdauer).
  static int inputBoostPercent(
    Iterable<StaffEntryData> entries,
    DateTime now,
  ) => activeEntry(entries, ManagementFeature.rushHour, now) == null
      ? 0
      : EconomyBalance.rushHourInputBonusPercent;

  /// Kapazitäts-Faktor aus einem aktiven **Lagertetris**
  /// (`1 + Faktor × Kompetenz`; `1.0` außerhalb der Wirkdauer).
  static double capacityFactor(Iterable<StaffEntryData> entries, DateTime now) {
    final entry = activeEntry(entries, ManagementFeature.storageTetris, now);
    if (entry == null) return 1.0;
    return 1.0 +
        EconomyBalance.storageTetrisCapacityFactorPerCompetence *
            competenceOf(entry);
  }

  /// Senkung des **Tages-Sinks** (Vitalität/Moral) in Prozent zum Zeitpunkt
  /// [now].
  ///
  /// Quellen: der passive Gewerkschaftschef (Kompetenz-abhängig) sowie die
  /// aktiven Features Rush Hour und Lagertetris (Mali entfallen vollständig)
  /// und „Organisation ist alles“ (`organisationSinkReductionPercent`).
  /// Auf `100` gedeckelt.
  static int sinkReliefPercent(Iterable<StaffEntryData> entries, DateTime now) {
    var percent = unionChiefSinkReliefPercent(entries);
    if (activeEntry(entries, ManagementFeature.rushHour, now) != null) {
      percent += 100;
    }
    if (activeEntry(entries, ManagementFeature.storageTetris, now) != null) {
      percent += 100;
    }
    if (activeEntry(entries, ManagementFeature.organisationIsEverything, now) !=
        null) {
      percent += EconomyBalance.organisationSinkReductionPercent;
    }
    return percent.clamp(0, 100);
  }

  /// Senkung des **Erschöpfungs-Malus** (Nulltage) in Prozent – dieselben
  /// Quellen wie [sinkReliefPercent] (V12).
  static int malusReliefPercent(
    Iterable<StaffEntryData> entries,
    DateTime now,
  ) => sinkReliefPercent(entries, now);

  /// Zusätzlicher Tages-Sink durch eine aktive **Rush Hour**
  /// (`Kompetenz × rushHourExhaustionPerCompetence`); `0` sonst.
  ///
  /// Der Wert ist die **Gesamtlast** eines Tages und wird in
  /// `GameClockService` ranggewichtet auf das Personal verteilt („von oben
  /// herab“).
  static int rushHourExtraSink(Iterable<StaffEntryData> entries, DateTime now) {
    final entry = activeEntry(entries, ManagementFeature.rushHour, now);
    if (entry == null) return 0;
    return competenceOf(entry) * EconomyBalance.rushHourExhaustionPerCompetence;
  }

  /// Laufende **Tageskosten** aktiver Features zum Zeitpunkt [now] (Euro).
  ///
  /// Derzeit nur „Organisation ist alles“ (`organisationCostPerDay`, V12); der
  /// Betrag wird im Catch-up am Blockende als `featureCosts` gebucht.
  static int featureDailyCosts(
    Iterable<StaffEntryData> entries,
    DateTime now,
  ) =>
      activeEntry(entries, ManagementFeature.organisationIsEverything, now) ==
          null
      ? 0
      : EconomyBalance.organisationCostPerDay;

  /// Prozentuale Sink-Senkung des passiven **Gewerkschaftschefs** (ohne
  /// Feature-Einfluss) – Kompetenz × `unionChiefSinkReductionPercentPerCompetence`.
  static int unionChiefSinkReliefPercent(Iterable<StaffEntryData> entries) {
    var best = 0;
    for (final entry in entries) {
      if (entry.kind != RoleKind.management) continue;
      if (entry.role != ManagementRole.unionChief.name) continue;
      final competence = competenceOf(entry);
      if (competence > best) best = competence;
    }
    return best * EconomyBalance.unionChiefSinkReductionPercentPerCompetence;
  }
}
