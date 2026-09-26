import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';

/// Gemeinsamer Verwaltungs-Contract des Nicht-Kampf-Personals (Option C, `11a`).
///
/// Reine Funktionen über `StaffEntryData`-Listen: Kategorie-Filter, Anwesenheit,
/// Lohnsumme sowie die **passiven** Effekte der Verwaltungs-/Marketing-Rollen
/// (Einkommens-Zuschlag des Social Media Manager, Kosten-/Strafen-Abzüge der
/// Rollen aus E12). Die **kategoriespezifische** Wirkung bleibt in den
/// jeweiligen Diensten (`SupportRoleService`, `ManagementFeatureService`,
/// `RivalService`).
class StaffRoleService {
  StaffRoleService._();

  /// Alle Einträge der Kategorie [kind].
  static List<StaffEntryData> ofKind(
    Iterable<StaffEntryData> entries,
    RoleKind kind,
  ) => entries.where((entry) => entry.kind == kind).toList(growable: false);

  /// `true`, wenn mindestens ein Eintrag der Kategorie [kind] existiert.
  static bool hasKind(Iterable<StaffEntryData> entries, RoleKind kind) =>
      entries.any((entry) => entry.kind == kind);

  /// `true`, wenn ein Eintrag mit dem Rollen-Schlüssel [role] existiert.
  static bool hasRole(Iterable<StaffEntryData> entries, String role) =>
      entries.any((entry) => entry.role == role);

  /// Summe der Wochenlöhne aller Einträge.
  static int weeklyWages(Iterable<StaffEntryData> entries) =>
      entries.fold<int>(0, (sum, entry) => sum + entry.costPerWeek);

  /// Wochenlohn einer Verwaltungs-/Marketing-Rolle (Kategorie `management`).
  static int managementWagePerWeek(ManagementRole role) =>
      EconomyBalance.managementRoleWagePerWeek[role] ?? 0;

  /// Prozentualer Einkommens-Zuschlag der Verwaltungs-/Marketing-Rollen
  /// (binär: Anwesenheit je Rolle; additiv gestapelt – `11a` E3).
  static int managementIncomePercent(Iterable<StaffEntryData> entries) {
    final management = ofKind(entries, RoleKind.management);
    var percent = 0;
    for (final role in kAllManagementRoles) {
      if (hasRole(management, role.name)) {
        percent += _managementIncomePercentOf(role);
      }
    }
    return percent;
  }

  /// Effekt-Zuschlag einer Verwaltungs-/Marketing-Rolle (zentrale Quelle:
  /// `EconomyBalance`).
  static int _managementIncomePercentOf(ManagementRole role) => switch (role) {
    ManagementRole.socialMediaManager =>
      EconomyBalance.socialMediaManagerIncomePercent,
    // Die neuen Verwaltungsrollen (E12) wirken nicht auf das Einkommen,
    // sondern auf Kosten und Strafen (siehe unten).
    ManagementRole.chefSecretary => 0,
    ManagementRole.lawyer => 0,
    ManagementRole.accountant => 0,
    // Die V12-Rollen wirken auf die Eingangswerte/Kosten (siehe unten).
    ManagementRole.headWaiter => 0,
    ManagementRole.personnelManager => 0,
    ManagementRole.storekeeper => 0,
    ManagementRole.unionChief => 0,
    // Der Sicherheitschef wirkt auf die Entdeckung, nicht auf das Einkommen.
    ManagementRole.securityChief => 0,
  };

  /// `true`, wenn die Verwaltungsrolle [role] angestellt ist (binäre Wirkung).
  static bool hasManagementRole(
    Iterable<StaffEntryData> entries,
    ManagementRole role,
  ) => hasRole(ofKind(entries, RoleKind.management), role.name);

  /// Chefsekretärin: Abzug auf die laufenden **Mitarbeiterkosten** (Prozent).
  static int chefSecretaryStaffCostReductionPercent(
    Iterable<StaffEntryData> entries,
  ) => hasManagementRole(entries, ManagementRole.chefSecretary)
      ? EconomyBalance.chefSecretaryStaffCostReductionPercent
      : 0;

  /// Chefsekretärin: Abzug auf die **Anschaffungskosten von Erweiterungen**
  /// (Prozent) – wirkt beim Kauf (`ObjectProfile.buyUpgrade`).
  static int chefSecretaryUpgradeCostReductionPercent(
    Iterable<StaffEntryData> entries,
  ) => hasManagementRole(entries, ManagementRole.chefSecretary)
      ? EconomyBalance.chefSecretaryUpgradeCostReductionPercent
      : 0;

  /// Buchhalter: Abzug auf **alle laufenden Kosten** (Prozent).
  static int accountantOngoingCostReductionPercent(
    Iterable<StaffEntryData> entries,
  ) => hasManagementRole(entries, ManagementRole.accountant)
      ? EconomyBalance.accountantOngoingCostReductionPercent
      : 0;

  /// Strafen-Minderung insgesamt (Prozent, gedeckelt auf 100).
  ///
  /// Setzt sich **additiv** zusammen aus dem passiven Abzug des Rechtsanwalts
  /// (E12) und der Kompetenz-Stufe eines **aktiven** Winkelzugs (E15) – bei
  /// Kompetenz 4 erreicht der Winkelzug allein 100 % (Negation).
  static int penaltyReductionPercent(
    Iterable<StaffEntryData> entries, {
    DateTime? now,
  }) {
    var percent = hasManagementRole(entries, ManagementRole.lawyer)
        ? EconomyBalance.lawyerPenaltyReductionPercent
        : 0;
    final active = ManagementFeatureService.activeEntry(
      entries,
      ManagementFeature.legalTrick,
      now ?? DateTime.now(),
    );
    if (active != null) {
      percent += ManagementFeatureService.legalTrickReductionPercentFor(active);
    }
    return percent.clamp(0, 100);
  }

  /// Mindert eine Strafe [fine] um die Strafen-Minderung des Personals.
  ///
  /// Kaufmännisch gerundet; das Ergebnis ist nie negativ.
  static int reducedPenalty(
    Iterable<StaffEntryData> entries,
    int fine, {
    DateTime? now,
  }) {
    final percent = penaltyReductionPercent(entries, now: now);
    if (percent <= 0) return fine;
    return (fine * (100 - percent) / 100).round();
  }

  /// Wendet einen prozentualen Abzug auf [amount] an (kaufmännisch gerundet).
  static int reduceByPercent(int amount, int percent) {
    if (percent <= 0) return amount;
    if (percent >= 100) return 0;
    return (amount * (100 - percent) / 100).round();
  }

  // ── Passive Effekte der V12-Rollen ─────────────────────────────────────

  /// Oberkellner: absoluter Attraktivitäts-Zuschlag (`0.0` ohne Rolle).
  static double headWaiterAttractivenessBonus(
    Iterable<StaffEntryData> entries,
  ) => hasManagementRole(entries, ManagementRole.headWaiter)
      ? EconomyBalance.headWaiterAttractivenessBonus
      : 0.0;

  /// Personalchef: absoluter Zufriedenheits-Zuschlag (`0.0` ohne Rolle).
  static double personnelManagerSatisfactionBonus(
    Iterable<StaffEntryData> entries,
  ) => hasManagementRole(entries, ManagementRole.personnelManager)
      ? EconomyBalance.personnelManagerSatisfactionBonus
      : 0.0;

  /// Summe der relativen Kapazitäts-Zuschläge (Prozent) aus Oberkellner,
  /// Personalchef und Lagerist.
  static int capacityPercent(Iterable<StaffEntryData> entries) {
    var percent = 0;
    if (hasManagementRole(entries, ManagementRole.headWaiter)) {
      percent += EconomyBalance.headWaiterCapacityPercent;
    }
    if (hasManagementRole(entries, ManagementRole.personnelManager)) {
      percent += EconomyBalance.personnelManagerCapacityPercent;
    }
    if (hasManagementRole(entries, ManagementRole.storekeeper)) {
      percent += EconomyBalance.storekeeperCapacityPercent;
    }
    return percent;
  }

  /// Gewerkschaftschef: Erhöhung der Mitarbeiterkosten (Prozent).
  static int unionChiefWageIncreasePercent(Iterable<StaffEntryData> entries) =>
      hasManagementRole(entries, ManagementRole.unionChief)
      ? EconomyBalance.unionChiefWageIncreasePercent
      : 0;

  /// Gewerkschaftschef: Senkung des Tages-Sinks (Prozent), skaliert mit der
  /// Kompetenz-Stufe des Trägers (höchste Stufe bei mehreren Trägern).
  static int unionChiefSinkReductionPercent(Iterable<StaffEntryData> entries) =>
      ManagementFeatureService.unionChiefSinkReliefPercent(entries);

  /// Sicherheitschef: Entdeckungs-Zuschlag (Prozent) auf eingehende
  /// Sabotageversuche (V13) – höchste Kompetenz-Stufe des Trägers.
  static int securityChiefDetectionBonusPercent(
    Iterable<StaffEntryData> entries,
  ) => ManagementFeatureService.securityChiefDetectionBonusPercent(entries);

  /// Strafen-Minderung eines **Gegenschlags** (V13).
  ///
  /// Wie [penaltyReductionPercent], aber der **Winkelzug** des angestellten
  /// Rechtsanwalts wird automatisch mit ausgelöst („gemeinsame Sache“), falls er
  /// nicht ohnehin schon läuft – die Rechtsanwalt-Einträge werden dabei **nicht**
  /// verändert. Auf `100` gedeckelt.
  static int counterSabotagePenaltyReductionPercent(
    Iterable<StaffEntryData> entries, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    var percent = penaltyReductionPercent(entries, now: at);
    final legalTrickActive =
        ManagementFeatureService.activeEntry(
          entries,
          ManagementFeature.legalTrick,
          at,
        ) !=
        null;
    if (!legalTrickActive) {
      var best = 0;
      for (final entry in entries) {
        if (entry.kind != RoleKind.management) continue;
        if (entry.role != ManagementRole.lawyer.name) continue;
        final reduction = ManagementFeatureService.legalTrickReductionPercentFor(
          entry,
        );
        if (reduction > best) best = reduction;
      }
      percent += best;
    }
    return percent.clamp(0, 100);
  }

  /// Mindert die Strafe eines gescheiterten Gegenschlags (V13) um
  /// [counterSabotagePenaltyReductionPercent] (kaufmännisch gerundet).
  static int reducedCounterPenalty(
    Iterable<StaffEntryData> entries,
    int fine, {
    DateTime? now,
  }) {
    final percent = counterSabotagePenaltyReductionPercent(entries, now: now);
    if (percent <= 0) return fine;
    return (fine * (100 - percent) / 100).round();
  }

  /// Summe der Wochenlöhne des gesamten **Nicht-Kampf-Personals** (alle
  /// Kategorien außer `medic` – die Arztkosten bucht der Catch-up separat über
  /// `EconomyService.billWeeklyMedicCosts`).
  static int nonCombatWeeklyWages(Iterable<StaffEntryData> entries) =>
      weeklyWages(entries.where((entry) => entry.kind != RoleKind.medic));
}
