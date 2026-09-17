import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Gemeinsamer Verwaltungs-Contract des Nicht-Kampf-Personals (Option C, `11a`).
///
/// Reine Funktionen über `StaffEntryData`-Listen: Kategorie-Filter, Anwesenheit
/// und Lohnsumme. Die **kategoriespezifische** Wirkung bleibt in den jeweiligen
/// Diensten (`SupportRoleService`; eine Management-Auswertung folgt, sobald die
/// Wirkung des Social Media Manager entschieden ist – `11a` E3).
class StaffRoleService {
  StaffRoleService._();

  /// Alle Einträge der Kategorie [kind].
  static List<StaffEntryData> ofKind(
    Iterable<StaffEntryData> entries,
    RoleKind kind,
  ) =>
      entries.where((entry) => entry.kind == kind).toList(growable: false);

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
      };

  /// Summe der Wochenlöhne des gesamten **Nicht-Kampf-Personals** (alle
  /// Kategorien außer `medic` – die Arztkosten bucht der Catch-up separat über
  /// `EconomyService.billWeeklyMedicCosts`).
  static int nonCombatWeeklyWages(Iterable<StaffEntryData> entries) =>
      weeklyWages(entries.where((entry) => entry.kind != RoleKind.medic));
}
