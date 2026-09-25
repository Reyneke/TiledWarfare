import 'dart:math' as math;

import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';

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
    final span = EconomyBalance.featureCompetenceMax -
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
    return start?.add(EconomyBalance.featureActiveDuration);
  }

  /// Ende der **Nachteilphase** von [entry] (oder `null`).
  static DateTime? aftermathEndOf(StaffEntryData entry) {
    final end = activeEndOf(entry);
    return end?.add(EconomyBalance.featureAftermathDuration);
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
  ) =>
      activeEntry(entries, feature, now) != null;

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
}
